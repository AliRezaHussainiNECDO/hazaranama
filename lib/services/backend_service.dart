import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:image_picker/image_picker.dart' show XFile;
import 'hz_backend.dart';
import '../core/afghan_calendar.dart';
import '../core/backend_config.dart';
import '../models/models.dart';

/// تمام تماس‌های واقعی با بک‌اند هزاره‌نامه (Cloudflare Worker + D1 + R2) اینجا
/// جمع شده — دیتابیس، حساب کاربری و فایل‌ها. AppState فقط این متدها را صدا
/// می‌زند و نتیجه را در مدل‌های اپ می‌ریزد؛ هیچ‌جای دیگر کد مستقیماً با سرور صحبت نمی‌کند.
class BackendService {
  HzBackend get _db => HzBackend.instance;

  // ================= AUTH =================

  User? get authUser => _db.auth.currentUser;
  Session? get currentSession => _db.auth.currentSession;
  Stream<AuthState> get authChanges => _db.auth.onAuthStateChange;

  Future<AuthResponse> signUp({required String email, required String password, required String name}) {
    return _db.auth.signUp(email: email, password: password, data: {'name': name});
  }

  Future<AuthResponse> signIn({required String email, required String password}) {
    return _db.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _db.auth.signOut();

  // ---- ورود اجتماعی و «مرا به خاطر بسپار» ----
  set persistSession(bool v) => _db.auth.persistSession = v;
  Future<Map<String, bool>> oauthProviders() => _db.auth.oauthProviders();
  String oauthStartUrl(String provider, String redirect) => _db.auth.oauthStartUrl(provider, redirect);
  Future<AuthResponse> exchangeOAuthCode(String code) => _db.auth.exchangeOAuthCode(code);

  /// حذف کامل و برگشت‌ناپذیر حساب کاربری — از طریق Edge Function امن
  /// «delete-account» (که با نشست خودِ کاربر صدا زده می‌شود و فقط اجازه
  /// دارد حساب همان کاربر را حذف کند). تمام محتوای متعلق به کاربر
  /// (پست‌ها، کامنت‌ها، پیام‌ها، اعلان‌ها، توکن‌های دستگاه و غیره) به‌واسطه‌ی
  /// «on delete cascade»ی تعریف‌شده در اسکیمای دیتابیس، خودکار پاک می‌شود.
  Future<void> deleteAccount() async {
    final res = await _db.functions.invoke('delete-account');
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
  }

  Future<String> resetPasswordForEmail(String email) => _db.auth.resetPasswordForEmail(
        email,
        redirectTo: BackendConfig.passwordResetRedirect,
      );

  /// کاربر کد ۶ رقمی ارسال‌شده به ایمیلش را وارد می‌کند؛ همان درخواست بازیابی
  /// را نزد Supabase تأیید می‌کند و یک نشست موقتِ بازیابی می‌سازد — دقیقاً
  /// همان چیزی که با کلیک روی پیوند ایمیل هم به دست می‌آمد. چون این کد فقط با
  /// وارد کردن دستیِ کاربر مصرف می‌شود (برخلاف پیوند، که اسکنرهای امنیتیِ
  /// Gmail/Outlook پیش از باز کردنِ واقعیِ کاربر به‌طور خودکار به آن سر
  /// می‌زنند و توکنِ یک‌بارمصرف را از بین می‌برند)، قابل‌اعتمادتر است.
  Future<AuthResponse> verifyRecoveryOtp({required String email, required String token}) {
    return _db.auth.verifyOTP(type: OtpType.recovery, email: email, token: token);
  }

  // ================= PROFILES =================

  Future<UserProfile> fetchProfile(String userId) async {
    final row = await _db.from('profiles').select().eq('id', userId).single();
    return _profileFromRow(row);
  }

  Future<List<UserProfile>> fetchAllProfiles() async {
    final rows = await _db.from('profiles').select().order('created_at');
    return (rows as List).map((r) => _profileFromRow(r as Map<String, dynamic>)).toList();
  }

  /// نقش‌ی همه‌ی کاربران — کوئری سبک (فقط id و role) که برای هر کاربرِ واردشده
  /// (نه فقط مدیر) قابل خواندن است؛ چون سیاست RLS جدول profiles همه را
  /// می‌گذارد بخوانند. برای نمایش درست حلقه‌ی مقام مدیر روی عکس پروفایلش در
  /// فید/کامنت‌ها/مقاله/پیام‌ها که کاربر عادی می‌بیند لازم است.
  Future<Map<String, UserRole>> fetchAllUserRoles() async {
    final rows = await _db.from('profiles').select('id, role');
    final map = <String, UserRole>{};
    for (final r in (rows as List)) {
      final row = r as Map<String, dynamic>;
      map[row['id'] as String] = roleFromString((row['role'] as String?) ?? 'user');
    }
    return map;
  }

  Future<void> updateProfileFields(String userId, Map<String, dynamic> fields) {
    return _db.from('profiles').update(fields).eq('id', userId);
  }

  Future<void> updateProfileRoots(String userId, {
    required String country, required String originProvince, required String district,
    required String tribe, required String nativeLanguage, required String bio,
  }) {
    return updateProfileFields(userId, {
      'country': country, 'origin_province': originProvince, 'district': district,
      'tribe': tribe, 'native_language': nativeLanguage, 'bio': bio,
    });
  }

  Future<void> setUserStatus(String userId, bool active) {
    return updateProfileFields(userId, {'status': active ? 'active' : 'blocked'});
  }

  Future<void> updateUserRole(String userId, UserRole role) {
    return updateProfileFields(userId, {'role': roleToDbValue(role)});
  }

  /// تاریخچه‌ی کامل فعالیت یک کاربر (پست/کامنت/واکنش/مقاله/حواله/پیام) —
  /// از ویوی user_activity_log؛ فقط مدیر می‌تواند این را بخواند.
  Future<List<UserActivityEntry>> fetchUserActivity(String userId, {int limit = 300}) async {
    final rows = await _db.from('user_activity_log').select().eq('user_id', userId).order('occurred_at', ascending: false).limit(limit);
    return (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      return UserActivityEntry(
        userId: row['user_id'] as String,
        type: userActivityTypeFromString(row['activity_type'] as String),
        refId: row['ref_id'] as String,
        summary: (row['summary'] as String?) ?? '',
        occurredAt: DateTime.parse(row['occurred_at'] as String),
      );
    }).toList();
  }

  /// یک بار در هر نشست صدا زده می‌شود (هنگام باز شدن اپ) — شمارنده‌ی
  /// «بازدید امروز» را در Supabase یک واحد بالا می‌برد. بی‌نام است، هیچ
  /// user_id ذخیره نمی‌شود.
  Future<void> incrementDailyVisit() async {
    await _db.rpc('increment_daily_visit');
  }

  String _dateOnly(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// شمار واقعی بازدیدهای امروز — برای کارت «بازدید امروز» در صفحه‌ی نخست
  /// پنل مدیریت. اگر امروز هنوز هیچ نشستی ثبت نشده باشد صفر برمی‌گرداند.
  Future<int> fetchTodayVisitCount() async {
    final dayStr = _dateOnly(DateTime.now().toUtc());
    final row = await _db.from('daily_visits').select('count').eq('day', dayStr).maybeSingle();
    return (row?['count'] as int?) ?? 0;
  }

  /// شمار بازدید ۷ روز گذشته (امروز هم شامل) — برای نمودار ریز کارت «بازدید
  /// امروز». روزهایی که هیچ نشستی نداشته‌اند صفر در نظر گرفته می‌شوند.
  Future<List<double>> fetchVisitTrend({int days = 7}) async {
    final today = DateTime.now().toUtc();
    final from = today.subtract(Duration(days: days - 1));
    final rows = await _db.from('daily_visits').select().gte('day', _dateOnly(from)).order('day');
    final byDay = <String, int>{
      for (final r in (rows as List)) (r as Map<String, dynamic>)['day'] as String: r['count'] as int,
    };
    return List.generate(days, (i) {
      final d = from.add(Duration(days: i));
      return (byDay[_dateOnly(d)] ?? 0).toDouble();
    });
  }

  /// آخرین فعالیت‌های همه‌ی کاربران در سراسر اپ — برای فید «آخرین فعالیت‌ها»ی
  /// صفحه‌ی نخست پنل مدیریت. از همان ویوی user_activity_log می‌خواند، بدون
  /// فیلتر روی یک کاربر خاص (فقط مدیر می‌تواند این را بخواند).
  Future<List<UserActivityEntry>> fetchRecentActivity({int limit = 8}) async {
    final rows = await _db.from('user_activity_log').select().order('occurred_at', ascending: false).limit(limit);
    return (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      return UserActivityEntry(
        userId: row['user_id'] as String,
        type: userActivityTypeFromString(row['activity_type'] as String),
        refId: row['ref_id'] as String,
        summary: (row['summary'] as String?) ?? '',
        occurredAt: DateTime.parse(row['occurred_at'] as String),
      );
    }).toList();
  }

  // ================= اعلان‌های درون‌اپی =================

  AppNotification _notificationFromRow(Map<String, dynamic> r) {
    return AppNotification(
      id: r['id'] as String,
      userId: r['user_id'] as String,
      type: r['type'] as String,
      title: r['title'] as String,
      body: (r['body'] as String?) ?? '',
      refId: r['ref_id'] as String?,
      refType: r['ref_type'] as String?,
      isRead: r['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(r['created_at'] as String),
    );
  }

  Future<List<AppNotification>> fetchNotifications(String userId, {int limit = 50}) async {
    final rows = await _db.from('notifications').select().eq('user_id', userId).order('created_at', ascending: false).limit(limit);
    return (rows as List).map((r) => _notificationFromRow(r as Map<String, dynamic>)).toList();
  }

  Future<void> markNotificationRead(String id) {
    return _db.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllNotificationsRead(String userId) {
    return _db.from('notifications').update({'is_read': true}).eq('user_id', userId).eq('is_read', false);
  }

  /// یک کانال Realtime باز می‌کند و هر اعلانِ تازه‌ی همین کاربر را همان لحظه‌ای
  /// که در دیتابیس ساخته می‌شود (توسط trigger) به onInsert می‌دهد. باید هنگام
  /// خروج از حساب یا بستن اپ با removeChannel بسته شود.
  NotificationSubscription subscribeToNotifications(String userId, void Function(AppNotification) onInsert, {String? sinceIso, Iterable<String> knownIds = const []}) {
    return NotificationSubscription._(this, userId, onInsert, sinceIso: sinceIso, knownIds: knownIds);
  }

  Future<void> removeChannel(NotificationSubscription channel) async => channel.cancel();

  Future<List<AppNotification>> _fetchNotificationsSince(String userId, String sinceIso) async {
    final rows = await _db
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .gt('created_at', sinceIso)
        .order('created_at')
        .limit(50);
    return (rows as List).map((r) => _notificationFromRow(r as Map<String, dynamic>)).toList();
  }

  /// ثبت/به‌روزرسانی توکن FCM دستگاه جاری برای این کاربر — پایه‌ی پوش
  /// نوتیفیکیشن واقعی. اگر همین توکن قبلاً به کاربر دیگری وصل بوده (مثلاً
  /// دستگاه مشترک)، صاحبش عوض می‌شود.
  Future<void> registerDeviceToken(String userId, String token) async {
    final platform = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other'));
    await _db.from('device_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': platform,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'token');
  }

  Future<void> unregisterDeviceToken(String token) async {
    await _db.from('device_tokens').delete().eq('token', token);
  }

  // ---------------- آپلود فایل انتخاب‌شده — سازگار با موبایل و وب ----------------
  // در وب، dart:io.File وجود ندارد و مسیرِ XFile یک blob: URL است؛ پس آنجا
  // بایت‌ها را مستقیم می‌فرستیم. در موبایل همان آپلود مبتنی بر فایل حفظ
  // می‌شود تا ویدیوهای بزرگ یکجا در حافظه بارگذاری نشوند.
  String _extOf(XFile file) {
    final name = file.name.isNotEmpty ? file.name : file.path;
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return 'jpg';
    return name.substring(dot + 1).toLowerCase();
  }

  Future<void> _uploadPicked(String bucket, String path, XFile file, {required String fallbackType}) async {
    final contentType = file.mimeType ?? fallbackType;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await _db.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );
    } else {
      await _db.storage.from(bucket).upload(
            path,
            File(file.path),
            fileOptions: FileOptions(upsert: true, contentType: file.mimeType ?? (fallbackType == 'video/mp4' ? fallbackType : null)),
          );
    }
  }

  Future<String> uploadAvatar(String userId, XFile file) async {
    final ext = _extOf(file);
    final path = '$userId/avatar.$ext';
    await _uploadPicked(BackendConfig.avatarsBucket, path, file, fallbackType: 'image/jpeg');
    final url = _db.storage.from(BackendConfig.avatarsBucket).getPublicUrl(path);
    // یک پارامتر تصادفی برای شکستن کش تصویر مرورگر/فلاتر بعد از هر آپلود تازه
    final bustedUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
    await updateProfileFields(userId, {'avatar_url': bustedUrl});
    return bustedUrl;
  }

  UserProfile _profileFromRow(Map<String, dynamic> r) {
    return UserProfile(
      id: r['id'] as String,
      name: (r['name'] as String?) ?? 'کاربر',
      email: (r['email'] as String?) ?? '',
      role: roleFromString((r['role'] as String?) ?? 'user'),
      status: ((r['status'] as String?) ?? 'active') == 'active' ? UserStatus.active : UserStatus.blocked,
      avatarPath: r['avatar_url'] as String?,
      country: (r['country'] as String?) ?? 'نامشخص',
      originProvince: (r['origin_province'] as String?) ?? 'نامشخص',
      district: (r['district'] as String?) ?? 'نامشخص',
      tribe: (r['tribe'] as String?) ?? '—',
      nativeLanguage: (r['native_language'] as String?) ?? 'نامشخص',
      bio: (r['bio'] as String?) ?? '',
      joined: _dateLabel(r['created_at'] as String?),
    );
  }

  String _dateLabel(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return afghanDateLabel(dt.toLocal());
  }

  Future<void> updatePassword(String newPassword) async {
    await _db.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// فقط مدیر: یک کد ۸ رقمیِ بازیابی رمز (اعتبار ۲۴ ساعت) برای کاربر می‌سازد؛
  /// مدیر این کد را (مثلاً با ایمیل) برای کاربر می‌فرستد و کاربر در صفحه‌ی
  /// «فراموشی رمز» واردش می‌کند — جایگزین ایمیل خودکار.
  Future<String> createRecoveryCode(String userId) async {
    final data = await _db.post('/admin/recovery-code', {'user_id': userId});
    return (data as Map)['code'] as String;
  }

  // ================= اعلان همگانی و وضعیت پوش (مدیر) =================

  Future<Map<String, dynamic>> fetchPushStatus() async {
    final data = await _db.post('/admin/push-status', {});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<int> sendBroadcast({required String title, required String body, required bool adminsOnly}) async {
    final data = await _db.post('/admin/broadcast', {'title': title, 'body': body, 'audience': adminsOnly ? 'admins' : 'all'});
    return ((data as Map)['recipients'] as num?)?.toInt() ?? 0;
  }

  // ================= تماس با ما =================

  Future<void> sendMessage(String userId, String message) {
    return _db.from('contact_messages').insert({'user_id': userId, 'message': message});
  }

  Future<List<ContactMessage>> fetchMessagesForUser(String userId) async {
    final rows = await _db
        .from('contact_messages')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => _messageFromRow(r as Map<String, dynamic>, null)).toList();
  }

  Future<List<ContactMessage>> fetchAllMessages() async {
    final rows = await _db
        .from('contact_messages')
        .select('*, user:profiles(name, email, country, origin_province, avatar_url)')
        .order('created_at', ascending: false);
    return (rows as List).map((r) => _messageFromRow(r as Map<String, dynamic>, r['user'] as Map<String, dynamic>?)).toList();
  }

  Future<void> replyToMessage(String messageId, String reply) {
    return _db.from('contact_messages').update({
      'admin_reply': reply,
      'status': 'replied',
      'replied_at': DateTime.now().toIso8601String(),
    }).eq('id', messageId);
  }

  Future<void> markMessageRead(String messageId) {
    return _db.from('contact_messages').update({'status': 'read'}).eq('id', messageId);
  }

  ContactMessage _messageFromRow(Map<String, dynamic> r, Map<String, dynamic>? user) {
    return ContactMessage(
      id: r['id'] as String,
      userId: r['user_id'] as String,
      userName: (user?['name'] as String?) ?? '',
      userEmail: (user?['email'] as String?) ?? '',
      userCountry: (user?['country'] as String?) ?? '',
      userOriginProvince: (user?['origin_province'] as String?) ?? '',
      userAvatar: user?['avatar_url'] as String?,
      message: r['message'] as String,
      status: messageStatusFromString((r['status'] as String?) ?? 'new'),
      adminReply: r['admin_reply'] as String?,
      createdAtLabel: _relativeTime(r['created_at'] as String),
    );
  }

  // ================= نظارت: گزارش محتوا و مسدودسازی کاربر =================

  Future<void> reportContent({
    required String reporterId,
    required String targetType,
    required String targetId,
    String? targetOwnerId,
    String? targetPreview,
    required String reason,
    String? note,
  }) {
    return _db.from('content_reports').insert({
      'reporter_id': reporterId,
      'target_type': targetType,
      'target_id': targetId,
      'target_owner_id': targetOwnerId,
      'target_preview': targetPreview,
      'reason': reason,
      'note': note,
    });
  }

  Future<List<ContentReport>> fetchContentReports() async {
    final rows = await _db
        .from('content_reports')
        .select('*, reporter:profiles(name)')
        .order('created_at', ascending: false);
    return (rows as List).map((r) => _reportFromRow(r as Map<String, dynamic>)).toList();
  }

  Future<void> updateReportStatus(String id, String status) {
    return _db.from('content_reports').update({'status': status}).eq('id', id);
  }

  ContentReport _reportFromRow(Map<String, dynamic> r) {
    final reporter = r['reporter'] as Map<String, dynamic>?;
    return ContentReport(
      id: r['id'] as String,
      reporterId: r['reporter_id'] as String,
      reporterName: (reporter?['name'] as String?) ?? 'کاربر',
      targetType: r['target_type'] as String,
      targetId: r['target_id'] as String,
      targetOwnerId: r['target_owner_id'] as String?,
      targetPreview: r['target_preview'] as String?,
      reason: r['reason'] as String,
      note: r['note'] as String?,
      status: r['status'] as String,
      createdAtLabel: _relativeTime(r['created_at'] as String),
    );
  }

  Future<List<BlockedUser>> fetchBlockedUsers(String blockerId) async {
    final rows = await _db
        .from('blocked_users')
        .select()
        .eq('blocker_id', blockerId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => _blockedUserFromRow(r as Map<String, dynamic>)).toList();
  }

  /// upsert روی (blocker_id, blocked_id) — اگر قبلاً مسدود شده، خطا نمی‌دهد.
  Future<void> blockUser({required String blockerId, required String blockedId, String? blockedName, String? blockedAvatarUrl}) {
    return _db.from('blocked_users').upsert({
      'blocker_id': blockerId,
      'blocked_id': blockedId,
      'blocked_name': blockedName,
      'blocked_avatar_url': blockedAvatarUrl,
    }, onConflict: 'blocker_id,blocked_id');
  }

  Future<void> unblockUser({required String blockerId, required String blockedId}) {
    return _db.from('blocked_users').delete().match({'blocker_id': blockerId, 'blocked_id': blockedId});
  }

  BlockedUser _blockedUserFromRow(Map<String, dynamic> r) {
    return BlockedUser(
      id: r['id'] as String,
      blockedId: r['blocked_id'] as String,
      blockedName: (r['blocked_name'] as String?) ?? 'کاربر',
      blockedAvatarUrl: r['blocked_avatar_url'] as String?,
      createdAtLabel: _relativeTime(r['created_at'] as String),
    );
  }

  // ================= CONTENT (بخش‌های هزاره‌نامه) =================

  Future<Map<String, List<ContentItem>>> fetchAllContent() async {
    final rows = await _db.from('content_items').select().order('sort_order');
    final map = <String, List<ContentItem>>{};
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      final sectionId = row['section_id'] as String;
      map.putIfAbsent(sectionId, () => []).add(_itemFromRow(row));
    }
    return map;
  }

  ContentItem _itemFromRow(Map<String, dynamic> row) {
    final fields = Map<String, dynamic>.from(row['fields'] as Map);
    return ContentItem(
      id: row['id'] as String,
      fields: fields,
      mapX: (fields['x'] as num?)?.toDouble(),
      mapY: (fields['y'] as num?)?.toDouble(),
      imageUrl: row['image_url'] as String?,
      videoUrl: row['video_url'] as String?,
    );
  }

  Future<ContentItem> addContentItem(String sectionId, Map<String, dynamic> fields, {String? imageUrl, String? videoUrl}) async {
    final payload = <String, dynamic>{'section_id': sectionId, 'fields': fields};
    if (imageUrl != null) payload['image_url'] = imageUrl;
    if (videoUrl != null) payload['video_url'] = videoUrl;
    final row = await _db.from('content_items').insert(payload).select().single();
    return _itemFromRow(row);
  }

  Future<void> updateContentItem(String itemId, Map<String, dynamic> fields, {String? imageUrl, String? videoUrl}) {
    final payload = <String, dynamic>{'fields': fields};
    if (imageUrl != null) payload['image_url'] = imageUrl;
    if (videoUrl != null) payload['video_url'] = videoUrl;
    return _db.from('content_items').update(payload).eq('id', itemId);
  }

  Future<void> deleteContentItem(String itemId) {
    return _db.from('content_items').delete().eq('id', itemId);
  }

  /// آپلود عکس یک آیتم محتوا به باکت content-media؛ فقط مدیر می‌تواند بنویسد
  /// (طبق سیاست‌های RLS در hazaranama-supabase-media-migration.sql).
  Future<String> uploadContentImage(XFile file) async {
    final ext = _extOf(file);
    final path = '${DateTime.now().millisecondsSinceEpoch}_${file.name.hashCode}.$ext';
    await _uploadPicked('content-media', path, file, fallbackType: 'image/jpeg');
    final url = _db.storage.from('content-media').getPublicUrl(path);
    return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  // ================= حافظه‌ی جمعی (پست/نظر/ریپلای/لایک/واکنش/رسانه) =================

  static const _postSelect =
      'id, text, image_urls, video_url, video_thumbnail_url, created_at, author_id, comments_count, '
      'author:profiles(name, avatar_url), reactions(emoji, user_id)';

  Future<List<Post>> fetchPosts(String? currentUserId, {int limit = 15}) async {
    final rows = await _db.from('posts').select(_postSelect).order('created_at', ascending: false).limit(limit);
    return (rows as List).map((r) => _postFromRow(r as Map<String, dynamic>, currentUserId)).toList();
  }

  /// یک پست مشخص (مثلاً پستی که اعلانش لمس شده و هنوز در فید بارگذاری نشده).
  Future<Post?> fetchPostById(String id, String? currentUserId) async {
    final row = await _db.from('posts').select(_postSelect).eq('id', id).maybeSingle();
    return row == null ? null : _postFromRow(row as Map<String, dynamic>, currentUserId);
  }

  /// صفحه‌بندی «بارگذاری بیشتر» — پست‌های قدیمی‌تر از [before].
  Future<List<Post>> fetchMorePosts(String? currentUserId, DateTime before, {int limit = 15}) async {
    final rows = await _db
        .from('posts')
        .select(_postSelect)
        .lt('created_at', before.toIso8601String())
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => _postFromRow(r as Map<String, dynamic>, currentUserId)).toList();
  }

  Post _postFromRow(Map<String, dynamic> r, String? currentUserId) {
    final author = r['author'] as Map<String, dynamic>?;
    final authorName = (author?['name'] as String?) ?? 'کاربر';
    final reactions = <String, int>{};
    final myReactions = <String, bool>{};
    for (final react in (r['reactions'] as List? ?? [])) {
      final row = react as Map<String, dynamic>;
      final emoji = row['emoji'] as String;
      reactions[emoji] = (reactions[emoji] ?? 0) + 1;
      if (row['user_id'] == currentUserId) myReactions[emoji] = true;
    }
    return Post(
      id: r['id'] as String,
      authorId: r['author_id'] as String,
      authorName: authorName,
      authorAvatar: author?['avatar_url'] as String?,
      text: r['text'] as String,
      imageUrls: ((r['image_urls'] as List?) ?? []).map((e) => e as String).toList(),
      videoUrl: r['video_url'] as String?,
      videoThumbnailUrl: r['video_thumbnail_url'] as String?,
      createdAt: DateTime.parse(r['created_at'] as String),
      createdAtLabel: _relativeTime(r['created_at'] as String),
      reactions: reactions,
      myReactions: myReactions,
      commentsCount: (r['comments_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Post> publishPost(
    String authorId, {
    required String text,
    List<String> imageUrls = const [],
    String? videoUrl,
    String? videoThumbnailUrl,
  }) async {
    final row = await _db
        .from('posts')
        .insert({
          'author_id': authorId,
          'text': text,
          'image_urls': imageUrls,
          'video_url': videoUrl,
          'video_thumbnail_url': videoThumbnailUrl,
        })
        .select(_postSelect)
        .single();
    return _postFromRow(row, authorId);
  }

  Future<void> deletePost(String postId) {
    return _db.from('posts').delete().eq('id', postId);
  }

  // ---------------- کامنت و ریپلای زیر پست ----------------

  Future<List<PostComment>> fetchPostComments(String postId, String? currentUserId) async {
    final rows = await _db
        .from('comments')
        .select('*, author:profiles(name, avatar_url), comment_likes(user_id)')
        .eq('post_id', postId)
        .order('created_at');
    final all = (rows as List).map((r) => _postCommentFromRow(r as Map<String, dynamic>, currentUserId)).toList();
    final byId = {for (final c in all) c.id: c};
    final roots = <PostComment>[];
    for (final c in all) {
      if (c.parentId != null && byId.containsKey(c.parentId)) {
        byId[c.parentId]!.replies.add(c);
      } else {
        roots.add(c);
      }
    }
    return roots;
  }

  PostComment _postCommentFromRow(Map<String, dynamic> r, String? currentUserId) {
    final author = r['author'] as Map<String, dynamic>?;
    final likes = (r['comment_likes'] as List?) ?? [];
    return PostComment(
      id: r['id'] as String,
      postId: r['post_id'] as String,
      parentId: r['parent_comment_id'] as String?,
      authorId: r['author_id'] as String,
      authorName: (author?['name'] as String?) ?? 'کاربر',
      authorAvatar: author?['avatar_url'] as String?,
      text: r['text'] as String,
      createdAtLabel: _relativeTime(r['created_at'] as String),
      likeCount: likes.length,
      likedByMe: likes.any((l) => (l as Map<String, dynamic>)['user_id'] == currentUserId),
    );
  }

  Future<void> addPostComment(String postId, String authorId, String text, {String? parentId}) {
    final payload = <String, dynamic>{'post_id': postId, 'author_id': authorId, 'text': text};
    if (parentId != null) payload['parent_comment_id'] = parentId;
    return _db.from('comments').insert(payload);
  }

  Future<void> deletePostComment(String id) {
    return _db.from('comments').delete().eq('id', id);
  }

  Future<void> togglePostCommentLike(String commentId, String userId, bool currentlyLiked) {
    if (currentlyLiked) {
      return _db.from('comment_likes').delete().match({'comment_id': commentId, 'user_id': userId});
    }
    return _db.from('comment_likes').insert({'comment_id': commentId, 'user_id': userId});
  }

  // ---------------- واکنش ایموجی روی پست (❤️ نقش «لایک» را هم بازی می‌کند) ----------------

  Future<void> addReaction(String postId, String userId, String emoji) {
    return _db.from('reactions').insert({'post_id': postId, 'user_id': userId, 'emoji': emoji});
  }

  Future<void> removeReaction(String postId, String userId, String emoji) {
    return _db.from('reactions').delete().match({'post_id': postId, 'user_id': userId, 'emoji': emoji});
  }

  // ---------------- آپلود عکس/ویدیوی پست — باکت post-media، هر کاربر فقط در پوشه‌ی خودش می‌نویسد ----------------

  Future<String> uploadPostImage(String userId, XFile file) async {
    final ext = _extOf(file);
    final path = '$userId/images/${DateTime.now().millisecondsSinceEpoch}_${file.name.hashCode}.$ext';
    await _uploadPicked('post-media', path, file, fallbackType: 'image/jpeg');
    final url = _db.storage.from('post-media').getPublicUrl(path);
    return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> uploadPostVideo(String userId, XFile file) async {
    final ext = _extOf(file);
    final path = '$userId/videos/${DateTime.now().millisecondsSinceEpoch}_${file.name.hashCode}.$ext';
    await _uploadPicked('post-media', path, file, fallbackType: 'video/mp4');
    return _db.storage.from('post-media').getPublicUrl(path);
  }

  String _relativeTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return 'اکنون';
    if (diff.inHours < 1) return '${diff.inMinutes} دقیقه پیش';
    if (diff.inDays < 1) return '${diff.inHours} ساعت پیش';
    if (diff.inDays < 30) return '${diff.inDays} روز پیش';
    return _dateLabel(iso);
  }

  // ================= موسیقی و شعر: گالری هنرمندان و ویدیو =================

  Future<List<Artist>> fetchArtists() async {
    final rows = await _db.from('artists').select().order('sort_order');
    final videoRows = await _db.from('artist_videos').select('artist_id');
    final counts = <String, int>{};
    for (final v in videoRows as List) {
      final id = (v as Map<String, dynamic>)['artist_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      return _artistFromRow(row, counts[row['id'] as String] ?? 0);
    }).toList();
  }

  Artist _artistFromRow(Map<String, dynamic> r, int videoCount) {
    return Artist(
      id: r['id'] as String,
      name: r['name'] as String,
      bio: (r['bio'] as String?) ?? '',
      avatarUrl: r['avatar_url'] as String?,
      coverUrl: r['cover_url'] as String?,
      videoCount: videoCount,
    );
  }

  Future<Artist> addArtist(String name, {String bio = '', String? avatarUrl, String? coverUrl}) async {
    final payload = <String, dynamic>{'name': name, 'bio': bio};
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl;
    if (coverUrl != null) payload['cover_url'] = coverUrl;
    final row = await _db.from('artists').insert(payload).select().single();
    return _artistFromRow(row, 0);
  }

  Future<void> updateArtist(String id, {String? name, String? bio, String? avatarUrl, String? coverUrl}) {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (bio != null) payload['bio'] = bio;
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl;
    if (coverUrl != null) payload['cover_url'] = coverUrl;
    if (payload.isEmpty) return Future.value();
    return _db.from('artists').update(payload).eq('id', id);
  }

  Future<void> deleteArtist(String id) {
    return _db.from('artists').delete().eq('id', id);
  }

  Future<List<ArtistVideo>> fetchArtistVideos(String artistId) async {
    final rows = await _db.from('artist_videos').select().eq('artist_id', artistId).order('sort_order');
    return (rows as List).map((r) => _videoFromRow(r as Map<String, dynamic>)).toList();
  }

  ArtistVideo _videoFromRow(Map<String, dynamic> r) {
    return ArtistVideo(
      id: r['id'] as String,
      artistId: r['artist_id'] as String,
      title: r['title'] as String,
      description: (r['description'] as String?) ?? '',
      videoUrl: r['video_url'] as String,
      thumbnailUrl: r['thumbnail_url'] as String?,
      viewsCount: (r['views_count'] as num?)?.toInt() ?? 0,
      createdAtLabel: _dateLabel(r['created_at'] as String?),
    );
  }

  Future<ArtistVideo> addVideo(String artistId, {required String title, String description = '', required String videoUrl, String? thumbnailUrl}) async {
    final payload = <String, dynamic>{
      'artist_id': artistId, 'title': title, 'description': description, 'video_url': videoUrl,
    };
    if (thumbnailUrl != null) payload['thumbnail_url'] = thumbnailUrl;
    final row = await _db.from('artist_videos').insert(payload).select().single();
    return _videoFromRow(row);
  }

  Future<void> updateVideo(String id, {String? title, String? description, String? thumbnailUrl}) {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (thumbnailUrl != null) payload['thumbnail_url'] = thumbnailUrl;
    if (payload.isEmpty) return Future.value();
    return _db.from('artist_videos').update(payload).eq('id', id);
  }

  Future<void> deleteVideo(String id) {
    return _db.from('artist_videos').delete().eq('id', id);
  }

  Future<void> incrementVideoViews(String videoId) {
    return _db.rpc('increment_video_views', params: {'p_video_id': videoId});
  }

  /// آپلود عکس (آواتار هنرمند، کاور، یا تامبنیل ویدیو) به باکت artist-media.
  Future<String> uploadArtistImage(XFile file) async {
    final ext = _extOf(file);
    final path = 'images/${DateTime.now().millisecondsSinceEpoch}_${file.name.hashCode}.$ext';
    await _uploadPicked('artist-media', path, file, fallbackType: 'image/jpeg');
    final url = _db.storage.from('artist-media').getPublicUrl(path);
    return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// آپلود فایل ویدیو (mp4/mov/…) به باکت artist-media.
  Future<String> uploadArtistVideoFile(XFile file) async {
    final ext = _extOf(file);
    final path = 'videos/${DateTime.now().millisecondsSinceEpoch}_${file.name.hashCode}.$ext';
    await _uploadPicked('artist-media', path, file, fallbackType: 'video/mp4');
    return _db.storage.from('artist-media').getPublicUrl(path);
  }

  // ---------------- کامنت و ریپلای زیر ویدیو ----------------

  Future<List<VideoComment>> fetchVideoComments(String videoId) async {
    final rows = await _db
        .from('video_comments')
        .select('*, author:profiles(name, avatar_url)')
        .eq('video_id', videoId)
        .order('created_at');
    final all = (rows as List).map((r) => _commentFromRow(r as Map<String, dynamic>)).toList();
    final byId = {for (final c in all) c.id: c};
    final roots = <VideoComment>[];
    for (final c in all) {
      if (c.parentId != null && byId.containsKey(c.parentId)) {
        byId[c.parentId]!.replies.add(c);
      } else {
        roots.add(c);
      }
    }
    return roots;
  }

  VideoComment _commentFromRow(Map<String, dynamic> r) {
    final author = r['author'] as Map<String, dynamic>?;
    return VideoComment(
      id: r['id'] as String,
      videoId: r['video_id'] as String,
      parentId: r['parent_comment_id'] as String?,
      authorId: r['author_id'] as String,
      authorName: (author?['name'] as String?) ?? 'کاربر',
      authorAvatar: author?['avatar_url'] as String?,
      text: r['text'] as String,
      createdAtLabel: _relativeTime(r['created_at'] as String),
    );
  }

  Future<void> addVideoComment(String videoId, String authorId, String text, {String? parentId}) {
    final payload = <String, dynamic>{'video_id': videoId, 'author_id': authorId, 'text': text};
    if (parentId != null) payload['parent_comment_id'] = parentId;
    return _db.from('video_comments').insert(payload);
  }

  Future<void> deleteVideoComment(String id) {
    return _db.from('video_comments').delete().eq('id', id);
  }

  // ---------------- واکنش ایموجی روی ویدیو ----------------

  Future<Map<String, dynamic>> fetchVideoReactions(String videoId, String? currentUserId) async {
    final rows = await _db.from('video_reactions').select().eq('video_id', videoId);
    final counts = <String, int>{};
    final mine = <String, bool>{};
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      final emoji = row['emoji'] as String;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
      if (row['user_id'] == currentUserId) mine[emoji] = true;
    }
    return {'counts': counts, 'mine': mine};
  }

  Future<void> addVideoReaction(String videoId, String userId, String emoji) {
    return _db.from('video_reactions').insert({'video_id': videoId, 'user_id': userId, 'emoji': emoji});
  }

  Future<void> removeVideoReaction(String videoId, String userId, String emoji) {
    return _db.from('video_reactions').delete().match({'video_id': videoId, 'user_id': userId, 'emoji': emoji});
  }

  // ================= مسابقه‌ی مقالات =================

  /// موضوع مشترک این دوره + جوایز سه مقام برتر + تاریخ آغاز دوره (یک رکورد تکی؛ مدیر ویرایش می‌کند).
  Future<ContestSettings> fetchContestSettings() async {
    final row = await _db.from('contest_settings').select().eq('id', 1).maybeSingle();
    if (row == null) {
      return ContestSettings(topic: 'موضوع این دوره هنوز از سوی مدیریت تعیین نشده است');
    }
    return ContestSettings(
      topic: row['topic'] as String,
      prizeFirst: row['prize_first'] as String?,
      prizeSecond: row['prize_second'] as String?,
      prizeThird: row['prize_third'] as String?,
      roundStartedAt: row['round_started_at'] == null ? null : DateTime.parse(row['round_started_at'] as String),
    );
  }

  Future<void> updateContestSettings({required String topic, String? prizeFirst, String? prizeSecond, String? prizeThird}) {
    return _db.from('contest_settings').upsert({
      'id': 1,
      'topic': topic,
      'prize_first': prizeFirst,
      'prize_second': prizeSecond,
      'prize_third': prizeThird,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// شروع دوره‌ی تازه‌ی مسابقه — تاریخ آغاز را به همین لحظه تنظیم می‌کند؛ از
  /// همین لحظه ۲۸ روز پنجره‌ی ارسال باز می‌شود (و روز ۲۸ باید رتبه‌بندی شود).
  Future<void> startNewContestRound() {
    return _db.from('contest_settings').upsert({
      'id': 1,
      'round_started_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<ArticleSubmission> submitArticle(String authorId, {required String title, required String body}) async {
    final row = await _db
        .from('article_submissions')
        .insert({'author_id': authorId, 'title': title, 'body': body})
        .select('*, author:profiles(name, avatar_url)')
        .single();
    return _submissionFromRow(row, null);
  }

  Future<List<ArticleSubmission>> fetchMySubmissions(String authorId) async {
    final rows = await _db
        .from('article_submissions')
        .select('*, author:profiles(name, avatar_url)')
        .eq('author_id', authorId)
        .order('submitted_at', ascending: false);
    final placements = await _fetchPlacementsBySubmissionId();
    return (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      return _submissionFromRow(row, placements[row['id'] as String]);
    }).toList();
  }

  /// همه‌ی مقالات ارسالی همه‌ی کاربران — فقط برای پنل مدیریت.
  Future<List<ArticleSubmission>> fetchAllSubmissions() async {
    final rows = await _db
        .from('article_submissions')
        .select('*, author:profiles(name, avatar_url)')
        .order('submitted_at', ascending: false);
    final placements = await _fetchPlacementsBySubmissionId();
    return (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      return _submissionFromRow(row, placements[row['id'] as String]);
    }).toList();
  }

  Future<Map<String, int>> _fetchPlacementsBySubmissionId() async {
    final rows = await _db.from('featured_articles').select('submission_id, placement');
    final map = <String, int>{};
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      final sid = row['submission_id'] as String?;
      if (sid != null) map[sid] = (row['placement'] as num).toInt();
    }
    return map;
  }

  ArticleSubmission _submissionFromRow(Map<String, dynamic> r, int? placement) {
    final author = r['author'] as Map<String, dynamic>?;
    return ArticleSubmission(
      id: r['id'] as String,
      authorId: r['author_id'] as String,
      authorName: (author?['name'] as String?) ?? 'کاربر',
      authorAvatar: author?['avatar_url'] as String?,
      title: r['title'] as String,
      body: r['body'] as String,
      status: articleStatusFromString(r['status'] as String),
      aiVerdict: aiVerdictFromString(r['ai_verdict'] as String?),
      aiConfidence: (r['ai_confidence'] as num?)?.toDouble(),
      aiQualityScore: (r['ai_quality_score'] as num?)?.toDouble(),
      aiNotes: r['ai_notes'] as String?,
      submittedAt: DateTime.parse(r['submitted_at'] as String),
      placement: placement,
    );
  }

  /// ذخیره‌ی نتیجه‌ی بررسی هوش مصنوعی (اصالت + نمره‌ی کیفیت).
  Future<void> saveArticleAiReview(String id, {required String verdict, required double confidence, required double qualityScore, required String notes}) {
    return _db.from('article_submissions').update({
      'ai_verdict': verdict,
      'ai_confidence': confidence,
      'ai_quality_score': qualityScore,
      'ai_notes': notes,
    }).eq('id', id);
  }

  Future<void> updateSubmissionStatus(String id, String status) {
    return _db.from('article_submissions').update({'status': status}).eq('id', id);
  }

  Future<void> deleteSubmission(String id) {
    return _db.from('article_submissions').delete().eq('id', id);
  }

  /// یک مقاله را به‌عنوان یکی از سه برگزیده‌ی این دوره منتشر می‌کند؛ اگر از
  /// یک مقاله‌ی ارسالی ساخته شده باشد، وضعیت همان مقاله را هم published می‌کند.
  Future<FeaturedArticle> publishFeaturedArticle({
    String? submissionId,
    String? authorId,
    required String authorName,
    String? authorAvatar,
    required String title,
    required String body,
    required int placement,
    required String monthLabel,
    String? prize,
  }) async {
    final payload = <String, dynamic>{
      'author_name': authorName,
      'title': title,
      'body': body,
      'placement': placement,
      'month_label': monthLabel,
    };
    if (submissionId != null) payload['submission_id'] = submissionId;
    if (authorId != null) payload['author_id'] = authorId;
    if (authorAvatar != null) payload['author_avatar'] = authorAvatar;
    if (prize != null) payload['prize'] = prize;
    final row = await _db.from('featured_articles').insert(payload).select().single();
    if (submissionId != null) {
      await updateSubmissionStatus(submissionId, 'published');
    }
    return _featuredFromRow(row);
  }

  Future<List<FeaturedArticle>> fetchFeaturedArticles() async {
    final rows = await _db.from('featured_articles').select().order('published_at', ascending: false);
    return (rows as List).map((r) => _featuredFromRow(r as Map<String, dynamic>)).toList();
  }

  FeaturedArticle _featuredFromRow(Map<String, dynamic> r) {
    return FeaturedArticle(
      id: r['id'] as String,
      submissionId: r['submission_id'] as String?,
      authorId: r['author_id'] as String?,
      authorName: r['author_name'] as String,
      authorAvatar: r['author_avatar'] as String?,
      title: r['title'] as String,
      body: r['body'] as String,
      placement: (r['placement'] as num).toInt(),
      monthLabel: r['month_label'] as String,
      prize: r['prize'] as String?,
      publishedAtLabel: _dateLabel(r['published_at'] as String?),
    );
  }

  Future<void> updateFeaturedArticle(String id, {String? title, String? body, String? monthLabel, String? prize, int? placement}) {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (body != null) payload['body'] = body;
    if (monthLabel != null) payload['month_label'] = monthLabel;
    if (prize != null) payload['prize'] = prize;
    if (placement != null) payload['placement'] = placement;
    if (payload.isEmpty) return Future.value();
    return _db.from('featured_articles').update(payload).eq('id', id);
  }

  Future<void> deleteFeaturedArticle(String id) {
    return _db.from('featured_articles').delete().eq('id', id);
  }

  // ---------------- کامنت و ریپلای زیر مقاله‌ی برگزیده ----------------

  Future<List<ArticleComment>> fetchArticleComments(String articleId) async {
    final rows = await _db
        .from('article_comments')
        .select('*, author:profiles(name, avatar_url)')
        .eq('featured_article_id', articleId)
        .order('created_at');
    final all = (rows as List).map((r) => _articleCommentFromRow(r as Map<String, dynamic>)).toList();
    final byId = {for (final c in all) c.id: c};
    final roots = <ArticleComment>[];
    for (final c in all) {
      if (c.parentId != null && byId.containsKey(c.parentId)) {
        byId[c.parentId]!.replies.add(c);
      } else {
        roots.add(c);
      }
    }
    return roots;
  }

  ArticleComment _articleCommentFromRow(Map<String, dynamic> r) {
    final author = r['author'] as Map<String, dynamic>?;
    return ArticleComment(
      id: r['id'] as String,
      articleId: r['featured_article_id'] as String,
      parentId: r['parent_comment_id'] as String?,
      authorId: r['author_id'] as String,
      authorName: (author?['name'] as String?) ?? 'کاربر',
      authorAvatar: author?['avatar_url'] as String?,
      text: r['text'] as String,
      createdAtLabel: _relativeTime(r['created_at'] as String),
    );
  }

  Future<void> addArticleComment(String articleId, String authorId, String text, {String? parentId}) {
    final payload = <String, dynamic>{'featured_article_id': articleId, 'author_id': authorId, 'text': text};
    if (parentId != null) payload['parent_comment_id'] = parentId;
    return _db.from('article_comments').insert(payload);
  }

  Future<void> deleteArticleComment(String id) {
    return _db.from('article_comments').delete().eq('id', id);
  }

  // ---------------- واکنش ایموجی روی مقاله‌ی برگزیده ----------------

  Future<Map<String, dynamic>> fetchArticleReactions(String articleId, String? currentUserId) async {
    final rows = await _db.from('article_reactions').select().eq('featured_article_id', articleId);
    final counts = <String, int>{};
    final mine = <String, bool>{};
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      final emoji = row['emoji'] as String;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
      if (row['user_id'] == currentUserId) mine[emoji] = true;
    }
    return {'counts': counts, 'mine': mine};
  }

  Future<void> addArticleReaction(String articleId, String userId, String emoji) {
    return _db.from('article_reactions').insert({'featured_article_id': articleId, 'user_id': userId, 'emoji': emoji});
  }

  Future<void> removeArticleReaction(String articleId, String userId, String emoji) {
    return _db.from('article_reactions').delete().match({'featured_article_id': articleId, 'user_id': userId, 'emoji': emoji});
  }

  // ================= کمک‌های مالی =================

  Future<DonationTransfer> submitDonationTransfer(
    String userId, {
    required String senderName,
    required String senderCountry,
    String? senderContact,
    required double amount,
    required String currency,
    String? transferReference,
    String? note,
    required DonationCategory category,
    DonationMethod method = DonationMethod.bankTransfer,
  }) async {
    final row = await _db
        .from('donation_transfers')
        .insert({
          'user_id': userId,
          'sender_name': senderName,
          'sender_country': senderCountry,
          'sender_contact': senderContact,
          'amount': amount,
          'currency': currency,
          'transfer_reference': transferReference,
          'note': note,
          'category': donationCategoryToDbValue(category),
          'method': donationMethodToDbValue(method),
        })
        .select()
        .single();
    return _donationTransferFromRow(row);
  }

  Future<List<DonationTransfer>> fetchMyDonationTransfers(String userId) async {
    final rows = await _db
        .from('donation_transfers')
        .select()
        .eq('user_id', userId)
        .order('submitted_at', ascending: false);
    return (rows as List).map((r) => _donationTransferFromRow(r as Map<String, dynamic>)).toList();
  }

  /// همه‌ی حواله‌های ارسالی همه‌ی کاربران — فقط برای پنل مدیریت.
  Future<List<DonationTransfer>> fetchAllDonationTransfers() async {
    final rows = await _db.from('donation_transfers').select().order('submitted_at', ascending: false);
    return (rows as List).map((r) => _donationTransferFromRow(r as Map<String, dynamic>)).toList();
  }

  DonationTransfer _donationTransferFromRow(Map<String, dynamic> r) {
    return DonationTransfer(
      id: r['id'] as String,
      userId: r['user_id'] as String,
      senderName: r['sender_name'] as String,
      senderCountry: r['sender_country'] as String,
      senderContact: r['sender_contact'] as String?,
      amount: (r['amount'] as num).toDouble(),
      currency: r['currency'] as String,
      transferReference: r['transfer_reference'] as String?,
      note: r['note'] as String?,
      category: donationCategoryFromString(r['category'] as String?),
      status: donationTransferStatusFromString(r['status'] as String),
      method: donationMethodFromString(r['method'] as String?),
      submittedAt: DateTime.parse(r['submitted_at'] as String),
      confirmedAmount: (r['confirmed_amount'] as num?)?.toDouble(),
    );
  }

  /// فهرست عمومیِ کمک‌کنندگان — از ویوی donor_leaderboard (جمعِ دلاریِ
  /// تقریبیِ کمک‌های تأییدشده‌ی هر کاربر)، برای صفحه‌ی «فهرست کمک‌کنندگان».
  Future<List<DonorRankEntry>> fetchDonorLeaderboard({int limit = 100}) async {
    final rows = await _db.from('donor_leaderboard').select().order('total_usd', ascending: false).limit(limit);
    return (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      return DonorRankEntry(
        userId: row['user_id'] as String,
        name: row['name'] as String? ?? 'کاربر هزاره‌نامه',
        avatarPath: row['avatar_path'] as String?,
        totalUsd: (row['total_usd'] as num).toDouble(),
        donationCount: (row['donation_count'] as num).toInt(),
        lastDonationAt: row['last_donation_at'] != null ? DateTime.parse(row['last_donation_at'] as String) : null,
      );
    }).toList();
  }

  /// تأیید یا رد یک حواله؛ هنگام تأیید می‌توان مبلغ واقعاً دریافت‌شده را هم ثبت کرد.
  Future<void> updateDonationTransferStatus(String id, String status, {double? confirmedAmount}) {
    final payload = <String, dynamic>{'status': status};
    if (status == 'confirmed') {
      payload['confirmed_at'] = DateTime.now().toIso8601String();
      if (confirmedAmount != null) payload['confirmed_amount'] = confirmedAmount;
    }
    return _db.from('donation_transfers').update(payload).eq('id', id);
  }

  Future<List<DonationReport>> fetchDonationReports() async {
    final rows = await _db.from('donation_reports').select().order('published_at', ascending: false);
    return (rows as List).map((r) => _donationReportFromRow(r as Map<String, dynamic>)).toList();
  }

  DonationReport _donationReportFromRow(Map<String, dynamic> r) {
    final images = (r['image_urls'] as List?)?.map((e) => e as String).toList() ?? <String>[];
    final publishedAt = DateTime.parse(r['published_at'] as String);
    return DonationReport(
      id: r['id'] as String,
      title: r['title'] as String,
      category: donationCategoryFromString(r['category'] as String?),
      summary: r['summary'] as String,
      body: r['body'] as String,
      amountSpent: (r['amount_spent'] as num?)?.toDouble(),
      currency: r['currency'] as String,
      imageUrls: images,
      videoUrl: r['video_url'] as String?,
      location: r['location'] as String?,
      beneficiariesCount: (r['beneficiaries_count'] as num?)?.toInt(),
      publishedAtLabel: _dateLabel(r['published_at'] as String?),
      publishedAt: publishedAt,
    );
  }

  Future<DonationReport> publishDonationReport({
    required String title,
    required DonationCategory category,
    required String summary,
    required String body,
    double? amountSpent,
    required String currency,
    List<String> imageUrls = const [],
    String? videoUrl,
    String? location,
    int? beneficiariesCount,
    String? createdBy,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'category': donationCategoryToDbValue(category),
      'summary': summary,
      'body': body,
      'amount_spent': amountSpent,
      'currency': currency,
      'image_urls': imageUrls,
      'video_url': videoUrl,
      'location': location,
      'beneficiaries_count': beneficiariesCount,
      'created_by': createdBy,
    };
    final row = await _db.from('donation_reports').insert(payload).select().single();
    return _donationReportFromRow(row);
  }

  Future<void> updateDonationReport(
    String id, {
    String? title,
    DonationCategory? category,
    String? summary,
    String? body,
    double? amountSpent,
    String? currency,
    List<String>? imageUrls,
    String? videoUrl,
    String? location,
    int? beneficiariesCount,
  }) {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (category != null) payload['category'] = donationCategoryToDbValue(category);
    if (summary != null) payload['summary'] = summary;
    if (body != null) payload['body'] = body;
    if (amountSpent != null) payload['amount_spent'] = amountSpent;
    if (currency != null) payload['currency'] = currency;
    if (imageUrls != null) payload['image_urls'] = imageUrls;
    if (videoUrl != null) payload['video_url'] = videoUrl;
    if (location != null) payload['location'] = location;
    if (beneficiariesCount != null) payload['beneficiaries_count'] = beneficiariesCount;
    if (payload.isEmpty) return Future.value();
    return _db.from('donation_reports').update(payload).eq('id', id);
  }

  Future<void> deleteDonationReport(String id) {
    return _db.from('donation_reports').delete().eq('id', id);
  }

  /// آپلود عکس/ویدیوی مستندِ یک گزارش شفافیت به باکت donation-media.
  Future<String> uploadDonationImage(XFile file) async {
    final ext = _extOf(file);
    final path = 'images/${DateTime.now().millisecondsSinceEpoch}_${file.name.hashCode}.$ext';
    await _uploadPicked('donation-media', path, file, fallbackType: 'image/jpeg');
    return _db.storage.from('donation-media').getPublicUrl(path);
  }

  Future<String> uploadDonationVideoFile(XFile file) async {
    final ext = _extOf(file);
    final path = 'videos/${DateTime.now().millisecondsSinceEpoch}_${file.name.hashCode}.$ext';
    await _uploadPicked('donation-media', path, file, fallbackType: 'video/mp4');
    return _db.storage.from('donation-media').getPublicUrl(path);
  }

  Future<DonationSettings> fetchDonationSettings() async {
    final row = await _db.from('donation_settings').select().eq('id', 1).maybeSingle();
    if (row == null) return DonationSettings();
    return DonationSettings(
      totalRaised: (row['total_raised'] as num?)?.toDouble() ?? 0,
      currency: row['currency'] as String? ?? 'USD',
      familiesHelped: (row['families_helped'] as num?)?.toInt() ?? 0,
      projectsCompleted: (row['projects_completed'] as num?)?.toInt() ?? 0,
      updatedAt: row['updated_at'] == null ? null : DateTime.parse(row['updated_at'] as String),
    );
  }

  Future<void> updateDonationSettings({
    required double totalRaised,
    required String currency,
    required int familiesHelped,
    required int projectsCompleted,
  }) {
    return _db.from('donation_settings').upsert({
      'id': 1,
      'total_raised': totalRaised,
      'currency': currency,
      'families_helped': familiesHelped,
      'projects_completed': projectsCompleted,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}

/// جایگزین کانال Realtime سوپابیس: هر ۲۰ ثانیه (فقط وقتی اپ باز است) اعلان‌های
/// تازه‌ی همین کاربر را از سرور می‌پرسد و به onInsert می‌دهد.
class NotificationSubscription {
  NotificationSubscription._(this._service, this._userId, this._onInsert, {String? sinceIso, Iterable<String> knownIds = const []}) {
    // نقطه‌ی شروع از زمانِ سرورِ تازه‌ترین اعلانِ موجود — نه ساعت گوشی (که ممکن
    // است جلو باشد و باعث شود اعلان‌های تازه هرگز دیده نشوند).
    _since = sinceIso ?? '1970-01-01T00:00:00.000Z';
    _seen.addAll(knownIds);
    _resume();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _resume();
        pollNow();
      },
      onHide: _pause,
    );
  }

  static const _interval = Duration(seconds: 25);

  final BackendService _service;
  final String _userId;
  final void Function(AppNotification) _onInsert;
  final Set<String> _seen = {};
  late String _since;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _busy = false;
  bool _cancelled = false;

  void _resume() {
    if (_cancelled) return;
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => pollNow());
  }

  // وقتی اپ در پس‌زمینه است، درخواست بی‌فایده نفرست (باتری و سهمیه‌ی سرور)
  void _pause() {
    _timer?.cancel();
    _timer = null;
  }

  /// همین حالا اعلان‌های تازه را بگیر — مثلاً وقتی یک پوش رسید یا اپ دوباره باز شد.
  Future<void> pollNow() async {
    if (_busy || _cancelled) return;
    _busy = true;
    try {
      final fresh = await _service._fetchNotificationsSince(_userId, _since);
      for (final n in fresh) {
        final iso = n.createdAt.toUtc().toIso8601String();
        if (iso.compareTo(_since) > 0) _since = iso;
        if (_seen.add(n.id)) _onInsert(n);
      }
    } catch (_) {
      // قطعی موقت شبکه — دور بعد دوباره تلاش می‌شود
    } finally {
      _busy = false;
    }
  }

  void cancel() {
    _cancelled = true;
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}
