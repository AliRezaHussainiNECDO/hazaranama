import 'package:supabase_flutter/supabase_flutter.dart';

/// خطای مخصوص فراخوانی‌های هوش مصنوعی — پیام آن همیشه فارسی و قابل‌نمایش
/// مستقیم به کاربر است (چه خطای شبکه باشد، چه خطای برگشتی از ai-gateway).
class AiServiceException implements Exception {
  final String message;
  AiServiceException(this.message);
  @override
  String toString() => message;
}

/// یک پیام در تاریخچه‌ی گفتگو با دستیار هوشمند.
class AiChatMessage {
  final bool fromUser;
  final String text;
  const AiChatMessage({required this.fromUser, required this.text});
}

/// یک پیشنهاد بخش برای کاربر (خروجی recommend)
class AiSectionPick {
  final String sectionId;
  final String reason;
  const AiSectionPick({required this.sectionId, required this.reason});
}

/// نتیجه‌ی جستجوی هوشمند
class AiSearchResult {
  final String answer;
  final List<String> sectionIds;
  const AiSearchResult({required this.answer, required this.sectionIds});
}

/// نتیجه‌ی کمکیِ بررسی اصالت یک مقاله در مسابقه‌ی مقالات — verdict یکی از
/// 'original' | 'suspicious' | 'likely_ai_or_copied' است؛ هرگز حکم قطعی نیست.
class AiArticleReview {
  final String verdict;
  final double confidence;
  final double qualityScore; // ۰ تا ۱۰۰ — قوت/کیفیت محتوا و نگارش، جدا از اصالت
  final String notes;
  const AiArticleReview({required this.verdict, required this.confidence, required this.qualityScore, required this.notes});
}

/// پیش‌نویسِ آماده‌شده توسط هوش مصنوعی برای یک گزارش شفافیت کمک‌های مالی.
class AiDonationReportDraft {
  final String title;
  final String summary;
  final String body;
  const AiDonationReportDraft({required this.title, required this.summary, required this.body});
}

/// تمام تماس‌های هوش مصنوعی از اینجا رد می‌شوند — همیشه از طریق Edge Function
/// امن «ai-gateway»، نه مستقیم با هیچ سرویس هوش مصنوعی. AppState/UI هرگز کلید
/// API را نمی‌بینند.
class AiService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _db.functions.invoke('ai-gateway', body: body);
      final data = res.data;
      if (data is Map<String, dynamic>) {
        if (data['error'] != null) throw AiServiceException(data['error'].toString());
        return data;
      }
      if (data is Map) return Map<String, dynamic>.from(data);
      throw AiServiceException('پاسخ نامعتبر از سرویس هوش مصنوعی دریافت شد.');
    } on AiServiceException {
      rethrow;
    } on FunctionException catch (e) {
      final detail = e.details;
      if (detail is Map && detail['error'] != null) {
        throw AiServiceException(detail['error'].toString());
      }
      throw AiServiceException('سرویس هوش مصنوعی در دسترس نیست؛ دوباره تلاش کنید.');
    } catch (_) {
      throw AiServiceException('اتصال به سرویس هوش مصنوعی برقرار نشد؛ اینترنت را بررسی کنید.');
    }
  }

  /// دستیار گفتگوی هوشمند — یک پیام تازه به همراه تاریخچه‌ی کوتاه می‌فرستد.
  Future<String> chat({required String message, List<AiChatMessage> history = const []}) async {
    final data = await _invoke({
      'task': 'chat',
      'message': message,
      'history': history.map((m) => {'role': m.fromUser ? 'user' : 'model', 'text': m.text}).toList(),
    });
    return (data['reply'] as String?)?.trim() ?? '';
  }

  /// جستجوی هوشمند معنایی — یک پاسخ کوتاه + بخش‌های مرتبط پیشنهادی برمی‌گرداند.
  Future<AiSearchResult> search({
    required String query,
    required List<Map<String, String>> sections,
  }) async {
    final data = await _invoke({'task': 'search', 'query': query, 'sections': sections});
    final ids = (data['sectionIds'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    return AiSearchResult(answer: (data['answer'] as String?)?.trim() ?? '', sectionIds: ids);
  }

  /// پیشنهاد و شخصی‌سازی محتوا بر اساس پروفایل کاربر.
  Future<List<AiSectionPick>> recommend({
    required Map<String, String> profile,
    required List<Map<String, String>> sections,
  }) async {
    final data = await _invoke({'task': 'recommend', 'profile': profile, 'sections': sections});
    final picks = (data['picks'] as List?) ?? const [];
    return picks
        .whereType<Map>()
        .map((p) => AiSectionPick(sectionId: '${p['sectionId']}', reason: '${p['reason']}'))
        .toList();
  }

  /// ابزارهای هوش مصنوعی مدیر: پیش‌نویس (draft)، خلاصه‌سازی (summarize) یا ترجمه (translate).
  Future<String> adminAssist({
    required String action,
    required String sectionTitle,
    String topic = '',
    String sourceText = '',
    String targetLang = 'فارسی',
  }) async {
    final data = await _invoke({
      'task': 'admin',
      'action': action,
      'sectionTitle': sectionTitle,
      'topic': topic,
      'sourceText': sourceText,
      'targetLang': targetLang,
    });
    return (data['text'] as String?)?.trim() ?? '';
  }

  /// بررسی کمکیِ اصالت یک مقاله برای مسابقه‌ی مقالات — فقط برای کمک به
  /// تصمیم مدیر؛ تشخیص هوش مصنوعی هرگز قطعی نیست.
  Future<AiArticleReview> reviewArticle({required String title, required String body}) async {
    final data = await _invoke({'task': 'review_article', 'title': title, 'body': body});
    return AiArticleReview(
      verdict: (data['verdict'] as String?) ?? 'suspicious',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.5,
      qualityScore: (data['quality_score'] as num?)?.toDouble() ?? 50,
      notes: (data['notes'] as String?)?.trim() ?? '',
    );
  }

  /// از روی نکات خامِ مدیر، یک گزارش شفافیتِ گرم و صادقانه برای بخش کمک‌های
  /// مالی می‌نویسد (عنوان + خلاصه‌ی کوتاه + متن کامل گزارش).
  Future<AiDonationReportDraft> draftDonationReport({
    required String categoryLabel,
    required String rawNotes,
    String title = '',
    double? amountSpent,
    String currency = 'USD',
    String location = '',
    int? beneficiariesCount,
  }) async {
    final data = await _invoke({
      'task': 'draft_donation_report',
      'categoryLabel': categoryLabel,
      'rawNotes': rawNotes,
      'title': title,
      if (amountSpent != null) 'amountSpent': amountSpent,
      'currency': currency,
      'location': location,
      if (beneficiariesCount != null) 'beneficiariesCount': beneficiariesCount,
    });
    return AiDonationReportDraft(
      title: (data['title'] as String?)?.trim() ?? title,
      summary: (data['summary'] as String?)?.trim() ?? '',
      body: (data['body'] as String?)?.trim() ?? '',
    );
  }
}
