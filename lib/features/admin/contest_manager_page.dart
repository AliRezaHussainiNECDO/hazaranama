import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/afghan_calendar.dart';
import '../../core/app_colors.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../services/ai_service.dart';
import '../../state/app_state.dart';

/// پنل مدیریت «مسابقه‌ی مقالات» — دو بخش: مقالات ارسالی (بررسی اصالت با
/// هوش مصنوعی، رد صلاحیت، انتخاب به‌عنوان برگزیده) و برگزیدگان منتشرشده
/// (ویرایش/حذف/افزودن دستی).
class ContestManagerPage extends StatefulWidget {
  const ContestManagerPage({super.key});
  @override
  State<ContestManagerPage> createState() => _ContestManagerPageState();
}

class _ContestManagerPageState extends State<ContestManagerPage> {
  int _tab = 0; // 0 = ارسالی‌ها، 1 = برگزیدگان، 2 = تنظیمات دوره
  String _statusFilter = 'all';
  bool _loading = false;
  bool _autoRanking = false;
  final Set<String> _busyIds = {};
  final _ai = AiService();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final app = context.read<AppState>();
    await Future.wait([app.loadAllArticleSubmissions(), app.loadFeaturedArticles(), app.loadContestSettings()]);
    if (mounted) setState(() => _loading = false);
  }

  /// مهلت ارسال (روز ۲۸ دوره‌ی مشترک) که تمام شود، همه‌ی مقالات «فعالِ» همین
  /// دوره یک‌جا آماده‌ی بررسی می‌شوند — نه هرکدام جداگانه در تاریخ خودشان.
  List<ArticleSubmission> _readyForRanking(AppState app) {
    if (!app.contestSettings.rankingDue) return [];
    return app.allArticleSubmissions.where((s) => s.status == ArticleStatus.active).toList();
  }

  /// کل فرایند رتبه‌بندی به‌صورت خودکار توسط هوش مصنوعی: بررسی اصالت + نمره‌ی
  /// کیفیت هر مقاله‌ای که دوره‌اش تمام شده، رد صلاحیت مقالات کپی/مصنوعی، و
  /// انتشار خودکار سه مقاله‌ی برتر (از میان مقالات اصیل) به‌عنوان برگزیده —
  /// بدون انتخاب دستی مدیر.
  Future<void> _runAutoRank() async {
    final app = context.read<AppState>();
    final theme = app.colors;
    final ready = _readyForRanking(app);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.bgElevated,
        title: Text('رتبه‌بندی خودکار با هوش مصنوعی', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
        content: Text(
          ready.isEmpty
              ? 'در حال حاضر هیچ مقاله‌ای دوره‌ی ۳۰ روزه‌اش تمام نشده. اگر مایلید، می‌توانید فقط رتبه‌بندیِ مقالات از پیش بررسی‌شده‌ی «پایان‌یافته» را دوباره اجرا کنید.'
              : '${ready.length} مقاله دوره‌شان تمام شده. هوش مصنوعی همه را بررسی و نمره‌دهی می‌کند، مقالات کپی/مصنوعی را رد صلاحیت می‌کند، و از میان بقیه، سه مقاله‌ی برتر را خودش انتخاب و به‌عنوان برگزیده منتشر می‌کند — بدون دخالت دستی. ادامه می‌دهید؟',
          style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.8),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('اجرا', style: TextStyle(color: theme.blue, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _autoRanking = true);
    var reviewed = 0;
    try {
      for (final s in ready) {
        try {
          final result = await _ai.reviewArticle(title: s.title, body: s.body);
          await app.saveArticleAiReview(s.id, verdict: result.verdict, confidence: result.confidence, qualityScore: result.qualityScore, notes: result.notes);
          await app.updateSubmissionStatus(s.id, result.verdict == 'likely_ai_or_copied' ? 'disqualified' : 'closed');
          reviewed++;
        } catch (_) {
          // این یکی خطا خورد؛ بقیه‌ی مقالات را ادامه بده، این یکی «فعال» می‌ماند تا بعداً دوباره تلاش شود.
        }
      }

      final eligible = app.allArticleSubmissions
          .where((s) => s.status == ArticleStatus.closed && s.aiVerdict == AiArticleVerdict.original && s.placement == null)
          .toList()
        ..sort((a, b) => (b.aiQualityScore ?? 0).compareTo(a.aiQualityScore ?? 0));
      final winners = eligible.take(3).toList();

      final nowAfghan = gregorianToAfghan(DateTime.now());
      final monthLabel = '${nowAfghan.monthName} ${toFaDigits(nowAfghan.year)}';
      final prizes = [app.contestSettings.prizeFirst, app.contestSettings.prizeSecond, app.contestSettings.prizeThird];

      for (var i = 0; i < winners.length; i++) {
        final w = winners[i];
        await app.publishFeaturedArticle(
          submissionId: w.id,
          authorId: w.authorId,
          authorName: w.authorName.isEmpty ? 'کاربر' : w.authorName,
          authorAvatar: w.authorAvatar,
          title: w.title,
          body: w.body,
          placement: i + 1,
          monthLabel: monthLabel,
          prize: prizes[i],
        );
      }

      if (mounted) {
        showHzToast(
          context,
          winners.isEmpty
              ? 'بررسی $reviewed مقاله انجام شد؛ فعلاً هیچ مقاله‌ی اصیلی برای برگزیده‌شدن یافت نشد.'
              : '$reviewed مقاله بررسی شد و ${winners.length} برگزیده به‌صورت خودکار منتشر شد.',
        );
      }
    } finally {
      if (mounted) setState(() => _autoRanking = false);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(children: [
          Expanded(child: _TabChip(theme: theme, label: 'مقالات ارسالی', selected: _tab == 0, onTap: () => setState(() => _tab = 0))),
          const SizedBox(width: 6),
          Expanded(child: _TabChip(theme: theme, label: 'برگزیدگان', selected: _tab == 1, onTap: () => setState(() => _tab = 1))),
          const SizedBox(width: 6),
          Expanded(child: _TabChip(theme: theme, label: 'موضوع و جوایز', selected: _tab == 2, onTap: () => setState(() => _tab = 2))),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : switch (_tab) {
                0 => _SubmissionsTab(
                    theme: theme,
                    app: app,
                    ai: _ai,
                    statusFilter: _statusFilter,
                    busyIds: _busyIds,
                    readyCount: _readyForRanking(app).length,
                    autoRanking: _autoRanking,
                    onAutoRank: _runAutoRank,
                    onFilterChanged: (f) => setState(() => _statusFilter = f),
                    onBusyChanged: (id, busy) => setState(() => busy ? _busyIds.add(id) : _busyIds.remove(id)),
                    onRefresh: _refresh,
                  ),
                1 => _FeaturedTab(theme: theme, app: app, onRefresh: _refresh),
                _ => _SettingsTab(theme: theme, app: app, settings: app.contestSettings),
              },
      ),
    ]);
  }
}

class _TabChip extends StatelessWidget {
  final AppColors theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({required this.theme, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? theme.blue : theme.bgCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? theme.blue : theme.glassBorder),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : theme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// =============================================================================
// تب مقالات ارسالی
// =============================================================================

class _SubmissionsTab extends StatelessWidget {
  final AppColors theme;
  final AppState app;
  final AiService ai;
  final String statusFilter;
  final Set<String> busyIds;
  final int readyCount;
  final bool autoRanking;
  final VoidCallback onAutoRank;
  final void Function(String) onFilterChanged;
  final void Function(String id, bool busy) onBusyChanged;
  final Future<void> Function() onRefresh;

  const _SubmissionsTab({
    required this.theme,
    required this.app,
    required this.ai,
    required this.statusFilter,
    required this.busyIds,
    required this.readyCount,
    required this.autoRanking,
    required this.onAutoRank,
    required this.onFilterChanged,
    required this.onBusyChanged,
    required this.onRefresh,
  });

  static const _filters = {
    'all': 'همه',
    'active': 'در حال داوری',
    'closed': 'پایان‌یافته',
    'disqualified': 'رد صلاحیت‌شده',
    'published': 'منتشرشده',
  };

  @override
  Widget build(BuildContext context) {
    var items = app.allArticleSubmissions;
    if (statusFilter != 'all') {
      items = items.where((s) => s.status.name == statusFilter).toList();
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.aiViolet.withValues(alpha: 0.16), theme.blue.withValues(alpha: 0.1)], begin: Alignment.centerRight, end: Alignment.centerLeft),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.aiViolet.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.auto_awesome, size: 16, color: theme.aiViolet),
                const SizedBox(width: 6),
                Expanded(child: Text('رتبه‌بندی خودکار با هوش مصنوعی', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 6),
              Text(
                readyCount > 0
                    ? '$readyCount مقاله دوره‌شان تمام شده و آماده‌ی بررسی‌اند.'
                    : 'فعلاً مقاله‌ای که دوره‌اش تمام شده باشد نیست.',
                style: TextStyle(color: theme.textFaint, fontSize: 12, height: 1.7),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: autoRanking ? null : onAutoRank,
                  icon: autoRanking
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.emoji_events_outlined, size: 15),
                  label: Text(autoRanking ? 'در حال بررسی و رتبه‌بندی…' : 'بررسی، رتبه‌بندی و انتشار برگزیدگان', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(backgroundColor: theme.aiViolet, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final key = _filters.keys.elementAt(i);
                final selected = statusFilter == key;
                return InkWell(
                  onTap: () => onFilterChanged(key),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? theme.blue.withValues(alpha: 0.16) : theme.bgCard.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: selected ? theme.blue : theme.glassBorder),
                    ),
                    child: Text(_filters[key]!, style: TextStyle(color: selected ? theme.blue : theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('مقاله‌ای در این وضعیت یافت نشد', style: TextStyle(color: theme.textFaint, fontSize: 12))),
            )
          else
            for (final s in items) ...[
              _SubmissionCard(
                theme: theme,
                app: app,
                ai: ai,
                submission: s,
                busy: busyIds.contains(s.id),
                onBusyChanged: (busy) => onBusyChanged(s.id, busy),
                onChanged: onRefresh,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _SubmissionCard extends StatefulWidget {
  final AppColors theme;
  final AppState app;
  final AiService ai;
  final ArticleSubmission submission;
  final bool busy;
  final void Function(bool) onBusyChanged;
  final Future<void> Function() onChanged;

  const _SubmissionCard({
    required this.theme,
    required this.app,
    required this.ai,
    required this.submission,
    required this.busy,
    required this.onBusyChanged,
    required this.onChanged,
  });

  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  bool _expanded = false;

  Color _verdictColor(AiArticleVerdict v) {
    switch (v) {
      case AiArticleVerdict.original:
        return widget.theme.success;
      case AiArticleVerdict.suspicious:
        return widget.theme.yellow;
      case AiArticleVerdict.likelyAiOrCopied:
        return widget.theme.danger;
      case AiArticleVerdict.none:
        return widget.theme.textFaint;
    }
  }

  String _verdictLabel(AiArticleVerdict v) {
    switch (v) {
      case AiArticleVerdict.original:
        return 'به‌احتمال زیاد اصیل';
      case AiArticleVerdict.suspicious:
        return 'مشکوک — نیاز به بررسی دستی';
      case AiArticleVerdict.likelyAiOrCopied:
        return 'به‌احتمال زیاد هوش مصنوعی/کپی';
      case AiArticleVerdict.none:
        return 'هنوز بررسی نشده';
    }
  }

  String _statusLabel(ArticleStatus s) {
    switch (s) {
      case ArticleStatus.active:
        return 'در حال داوری';
      case ArticleStatus.closed:
        return 'دوره تمام شد';
      case ArticleStatus.disqualified:
        return 'رد صلاحیت‌شده';
      case ArticleStatus.published:
        return 'منتشرشده';
    }
  }

  Future<void> _runAiReview() async {
    widget.onBusyChanged(true);
    try {
      final result = await widget.ai.reviewArticle(title: widget.submission.title, body: widget.submission.body);
      await widget.app.saveArticleAiReview(widget.submission.id, verdict: result.verdict, confidence: result.confidence, qualityScore: result.qualityScore, notes: result.notes);
      if (mounted) showHzToast(context, 'بررسی هوش مصنوعی انجام شد.');
    } catch (_) {
      if (mounted) showHzToast(context, 'بررسی هوش مصنوعی ناموفق بود.');
    } finally {
      widget.onBusyChanged(false);
      await widget.onChanged();
    }
  }

  Future<void> _disqualify() async {
    widget.onBusyChanged(true);
    try {
      await widget.app.updateSubmissionStatus(widget.submission.id, 'disqualified');
      if (mounted) showHzToast(context, 'مقاله رد صلاحیت شد.');
    } finally {
      widget.onBusyChanged(false);
    }
  }

  Future<void> _reactivate() async {
    widget.onBusyChanged(true);
    try {
      await widget.app.updateSubmissionStatus(widget.submission.id, 'active');
      if (mounted) showHzToast(context, 'مقاله به وضعیت فعال بازگشت.');
    } finally {
      widget.onBusyChanged(false);
    }
  }

  Future<void> _confirmDelete() async {
    final theme = widget.theme;
    await showDialog(context: context, builder: (ctx) {
      return AlertDialog(
        backgroundColor: theme.bgElevated,
        title: Text('حذف «${widget.submission.title}»؟', style: TextStyle(color: theme.textPrimary, fontSize: 13.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('انصراف')),
          TextButton(
            onPressed: () async {
              await widget.app.deleteSubmission(widget.submission.id);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) showHzToast(context, 'مقاله حذف شد');
            },
            child: Text('حذف', style: TextStyle(color: theme.danger)),
          ),
        ],
      );
    });
  }

  void _openPlacementForm() {
    final theme = widget.theme;
    final s = widget.submission;
    final now = gregorianToAfghan(DateTime.now());
    final monthCtrl = TextEditingController(text: '${now.monthName} ${toFaDigits(now.year)}');
    final prizeCtrl = TextEditingController();
    int placement = 1;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('انتخاب به‌عنوان برگزیده', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const FlagStripe(width: 46),
                const SizedBox(height: 16),
                Text('رتبه', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                const SizedBox(height: 6),
                Row(children: [1, 2, 3].map((p) {
                  final sel = placement == p;
                  final emoji = p == 1 ? '🥇' : (p == 2 ? '🥈' : '🥉');
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: InkWell(
                        onTap: () => setSheetState(() => placement = p),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel ? theme.blue.withValues(alpha: 0.16) : theme.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: sel ? theme.blue : theme.border),
                          ),
                          child: Text('$emoji نفر $p', style: TextStyle(color: sel ? theme.blue : theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 14),
                Text('عنوان دوره (مثلاً ماه انتشار)', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                _formField(theme, monthCtrl, hint: 'مثلاً: سنبله ۱۴۰۳'),
                const SizedBox(height: 12),
                Text('جایزه (اختیاری)', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                _formField(theme, prizeCtrl, hint: 'مثلاً: ۵۰۰۰ افغانی + لوح تقدیر'),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        widget.onBusyChanged(true);
                        try {
                          await widget.app.publishFeaturedArticle(
                            submissionId: s.id,
                            authorId: s.authorId,
                            authorName: s.authorName,
                            authorAvatar: s.authorAvatar,
                            title: s.title,
                            body: s.body,
                            placement: placement,
                            monthLabel: monthCtrl.text.trim().isEmpty ? '${now.monthName} ${toFaDigits(now.year)}' : monthCtrl.text.trim(),
                            prize: prizeCtrl.text.trim().isEmpty ? null : prizeCtrl.text.trim(),
                          );
                          if (mounted) showHzToast(context, 'مقاله به‌عنوان برگزیده منتشر شد.');
                        } finally {
                          widget.onBusyChanged(false);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: theme.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('انتشار', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(foregroundColor: theme.textSecondary, side: BorderSide(color: theme.border), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('انصراف', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final s = widget.submission;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800))),
          if (s.placement != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: theme.yellow.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
              child: Text('نفر ${s.placement}', style: TextStyle(color: theme.yellow, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
        ]),
        const SizedBox(height: 3),
        Text('${s.authorName.isEmpty ? 'کاربر' : s.authorName} — ${afghanDateLabel(s.submittedAt)}', style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
        const SizedBox(height: 8),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: theme.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(_statusLabel(s.status), style: TextStyle(color: theme.blue, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _verdictColor(s.aiVerdict).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(_verdictLabel(s.aiVerdict), style: TextStyle(color: _verdictColor(s.aiVerdict), fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          if (s.aiQualityScore != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: theme.aiViolet.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
              child: Text('کیفیت: ${s.aiQualityScore!.round()}/۱۰۰', style: TextStyle(color: theme.aiViolet, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
          const Spacer(),
          if (s.status == ArticleStatus.active)
            Text(
              widget.app.contestSettings.submissionsOpen
                  ? '${widget.app.contestSettings.timeUntilDeadline.inDays} روز تا رتبه‌بندی'
                  : 'آماده‌ی رتبه‌بندی',
              style: TextStyle(color: theme.textFaint, fontSize: 11),
            ),
        ]),
        if (s.aiNotes != null && s.aiNotes!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('یادداشت هوش مصنوعی: ${s.aiNotes}', style: TextStyle(color: theme.textFaint, fontSize: 11.5, height: 1.6)),
        ],
        const SizedBox(height: 6),
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(_expanded ? 'بستن متن مقاله' : 'خواندن متن کامل مقاله', style: TextStyle(color: theme.blue, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: theme.bgCardAlt, borderRadius: BorderRadius.circular(10)),
            child: Text(s.body, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.9)),
          ),
        ],
        const SizedBox(height: 10),
        if (widget.busy)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
        else
          Wrap(spacing: 6, runSpacing: 6, children: [
            OutlinedButton.icon(
              onPressed: _runAiReview,
              icon: const Icon(Icons.smart_toy_outlined, size: 14),
              label: const Text('بررسی با هوش مصنوعی', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(foregroundColor: theme.aiViolet, side: BorderSide(color: theme.aiViolet.withValues(alpha: 0.4)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
            if (s.status != ArticleStatus.published && s.status != ArticleStatus.disqualified)
              OutlinedButton.icon(
                onPressed: _disqualify,
                icon: const Icon(Icons.block, size: 14),
                label: const Text('رد صلاحیت', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(foregroundColor: theme.danger, side: BorderSide(color: theme.danger.withValues(alpha: 0.4)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            if (s.status == ArticleStatus.disqualified)
              OutlinedButton.icon(
                onPressed: _reactivate,
                icon: const Icon(Icons.restore, size: 14),
                label: const Text('بازگردانی', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(foregroundColor: theme.success, side: BorderSide(color: theme.success.withValues(alpha: 0.4)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            if (s.status != ArticleStatus.published && s.status != ArticleStatus.disqualified)
              ElevatedButton.icon(
                onPressed: _openPlacementForm,
                icon: const Icon(Icons.emoji_events_outlined, size: 14),
                label: const Text('انتخاب به‌عنوان برگزیده', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: theme.blue, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            IconButton(icon: Icon(Icons.delete_outline, size: 17, color: theme.textFaint), onPressed: _confirmDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 30)),
          ]),
      ]),
    );
  }
}

// =============================================================================
// تب برگزیدگان منتشرشده
// =============================================================================

class _FeaturedTab extends StatelessWidget {
  final AppColors theme;
  final AppState app;
  final Future<void> Function() onRefresh;
  const _FeaturedTab({required this.theme, required this.app, required this.onRefresh});

  void _openManualForm(BuildContext context) {
    final nameCtrl = TextEditingController();
    final avatarCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final now = gregorianToAfghan(DateTime.now());
    final monthCtrl = TextEditingController(text: '${now.monthName} ${toFaDigits(now.year)}');
    final prizeCtrl = TextEditingController();
    int placement = 1;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('افزودن برگزیده به‌صورت دستی', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const FlagStripe(width: 46),
                const SizedBox(height: 16),
                Text('رتبه', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                const SizedBox(height: 6),
                Row(children: [1, 2, 3].map((p) {
                  final sel = placement == p;
                  final emoji = p == 1 ? '🥇' : (p == 2 ? '🥈' : '🥉');
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: InkWell(
                        onTap: () => setSheetState(() => placement = p),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel ? theme.blue.withValues(alpha: 0.16) : theme.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: sel ? theme.blue : theme.border),
                          ),
                          child: Text('$emoji نفر $p', style: TextStyle(color: sel ? theme.blue : theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 12),
                Text('نام نویسنده', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                _formField(theme, nameCtrl, hint: 'نام و تخلص'),
                const SizedBox(height: 12),
                Text('لینک آواتار (اختیاری)', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                _formField(theme, avatarCtrl, hint: 'https://…'),
                const SizedBox(height: 12),
                Text('عنوان مقاله', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                _formField(theme, titleCtrl, hint: 'عنوان'),
                const SizedBox(height: 12),
                Text('متن کامل مقاله', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                _formField(theme, bodyCtrl, hint: 'متن مقاله…', maxLines: 8),
                const SizedBox(height: 12),
                Text('عنوان دوره', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                _formField(theme, monthCtrl, hint: 'مثلاً: سنبله ۱۴۰۳'),
                const SizedBox(height: 12),
                Text('جایزه (اختیاری)', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                _formField(theme, prizeCtrl, hint: 'مثلاً: ۵۰۰۰ افغانی'),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty || titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().length < 20) {
                          showHzToast(context, 'نام، عنوان و متن مقاله را کامل وارد کنید.');
                          return;
                        }
                        await app.publishFeaturedArticle(
                          authorName: nameCtrl.text.trim(),
                          authorAvatar: avatarCtrl.text.trim().isEmpty ? null : avatarCtrl.text.trim(),
                          title: titleCtrl.text.trim(),
                          body: bodyCtrl.text.trim(),
                          placement: placement,
                          monthLabel: monthCtrl.text.trim().isEmpty ? '${now.monthName} ${toFaDigits(now.year)}' : monthCtrl.text.trim(),
                          prize: prizeCtrl.text.trim().isEmpty ? null : prizeCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) showHzToast(context, 'برگزیده افزوده شد');
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: theme.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('افزودن', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(foregroundColor: theme.textSecondary, side: BorderSide(color: theme.border), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('انصراف', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        });
      },
    );
  }

  void _openEditForm(BuildContext context, FeaturedArticle a) {
    final titleCtrl = TextEditingController(text: a.title);
    final bodyCtrl = TextEditingController(text: a.body);
    final monthCtrl = TextEditingController(text: a.monthLabel);
    final prizeCtrl = TextEditingController(text: a.prize ?? '');
    int placement = a.placement;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('ویرایش برگزیده', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const FlagStripe(width: 46),
                const SizedBox(height: 16),
                Text('رتبه', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                const SizedBox(height: 6),
                Row(children: [1, 2, 3].map((p) {
                  final sel = placement == p;
                  final emoji = p == 1 ? '🥇' : (p == 2 ? '🥈' : '🥉');
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: InkWell(
                        onTap: () => setSheetState(() => placement = p),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel ? theme.blue.withValues(alpha: 0.16) : theme.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: sel ? theme.blue : theme.border),
                          ),
                          child: Text('$emoji نفر $p', style: TextStyle(color: sel ? theme.blue : theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 12),
                Text('عنوان مقاله', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                _formField(theme, titleCtrl, hint: 'عنوان'),
                const SizedBox(height: 12),
                Text('متن کامل مقاله', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                _formField(theme, bodyCtrl, hint: 'متن مقاله…', maxLines: 8),
                const SizedBox(height: 12),
                Text('عنوان دوره', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                _formField(theme, monthCtrl, hint: 'مثلاً: سنبله ۱۴۰۳'),
                const SizedBox(height: 12),
                Text('جایزه (اختیاری)', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                _formField(theme, prizeCtrl, hint: 'مثلاً: ۵۰۰۰ افغانی'),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await app.updateFeaturedArticle(a.id,
                            title: titleCtrl.text.trim(), body: bodyCtrl.text.trim(),
                            monthLabel: monthCtrl.text.trim(), prize: prizeCtrl.text.trim().isEmpty ? null : prizeCtrl.text.trim(),
                            placement: placement);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) showHzToast(context, 'برگزیده ویرایش شد');
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: theme.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('ذخیره', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(foregroundColor: theme.textSecondary, side: BorderSide(color: theme.border), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('انصراف', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        });
      },
    );
  }

  void _confirmDelete(BuildContext context, FeaturedArticle a) {
    showDialog(context: context, builder: (ctx) {
      return AlertDialog(
        backgroundColor: theme.bgElevated,
        title: Text('حذف «${a.title}» از برگزیدگان؟', style: TextStyle(color: theme.textPrimary, fontSize: 13.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('انصراف')),
          TextButton(
            onPressed: () async {
              await app.deleteFeaturedArticle(a.id);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) showHzToast(context, 'برگزیده حذف شد');
            },
            child: Text('حذف', style: TextStyle(color: theme.danger)),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = app.featuredArticles;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _openManualForm(context),
              icon: const Icon(Icons.add, size: 15),
              label: const Text('افزودن دستی', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: theme.blue, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('هنوز برگزیده‌ای منتشر نشده', style: TextStyle(color: theme.textFaint, fontSize: 12))),
            )
          else
            for (final a in items) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.glassBorder)),
                child: Row(children: [
                  DonorRing(
                    theme: theme, size: 46, childSize: 40, tier: app.donorTierForUserId(a.authorId ?? ''),
                    child: HzBadge(theme: theme, size: 40, filled: true, avatarPath: a.authorAvatar,
                        child: Text(a.authorName.isNotEmpty ? a.authorName[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(a.placement == 1 ? '🥇' : (a.placement == 2 ? '🥈' : '🥉'), style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700))),
                      ]),
                      Text('${a.authorName} — ${a.monthLabel}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
                    ]),
                  ),
                  IconButton(icon: Icon(Icons.edit_outlined, size: 17, color: theme.blue), onPressed: () => _openEditForm(context, a)),
                  IconButton(icon: Icon(Icons.delete_outline, size: 17, color: theme.danger), onPressed: () => _confirmDelete(context, a)),
                ]),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

// =============================================================================
// تب تنظیمات دوره — موضوع مشترک مقاله + جوایز سه مقام برتر
// =============================================================================

class _SettingsTab extends StatefulWidget {
  final AppColors theme;
  final AppState app;
  final ContestSettings settings;
  const _SettingsTab({required this.theme, required this.app, required this.settings});

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late final TextEditingController _topicCtrl;
  late final TextEditingController _prizeFirstCtrl;
  late final TextEditingController _prizeSecondCtrl;
  late final TextEditingController _prizeThirdCtrl;
  bool _saving = false;
  bool _startingRound = false;

  @override
  void initState() {
    super.initState();
    _topicCtrl = TextEditingController(text: widget.settings.topic);
    _prizeFirstCtrl = TextEditingController(text: widget.settings.prizeFirst ?? '');
    _prizeSecondCtrl = TextEditingController(text: widget.settings.prizeSecond ?? '');
    _prizeThirdCtrl = TextEditingController(text: widget.settings.prizeThird ?? '');
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    _prizeFirstCtrl.dispose();
    _prizeSecondCtrl.dispose();
    _prizeThirdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_topicCtrl.text.trim().isEmpty) {
      showHzToast(context, 'موضوع مقاله را وارد کنید.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.app.updateContestSettings(
        topic: _topicCtrl.text.trim(),
        prizeFirst: _prizeFirstCtrl.text.trim().isEmpty ? null : _prizeFirstCtrl.text.trim(),
        prizeSecond: _prizeSecondCtrl.text.trim().isEmpty ? null : _prizeSecondCtrl.text.trim(),
        prizeThird: _prizeThirdCtrl.text.trim().isEmpty ? null : _prizeThirdCtrl.text.trim(),
      );
      if (mounted) showHzToast(context, 'تنظیمات دوره ذخیره شد.');
    } catch (_) {
      if (mounted) showHzToast(context, 'ذخیره ناموفق بود؛ دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _startNewRound() async {
    final theme = widget.theme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.bgElevated,
        title: Text('شروع دوره‌ی تازه؟', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
        content: Text(
          'از همین لحظه یک پنجره‌ی ۲۸ روزه‌ی ارسال مقاله باز می‌شود؛ روز ۲۸ باید مقالات رتبه‌بندی شوند. '
          'اگر مقاله‌ی «فعالِ» رتبه‌بندی‌نشده از دوره‌ی قبل مانده، بهتر است پیش از این کار رتبه‌بندی‌اش کنید.',
          style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.8),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('شروع دوره‌ی تازه', style: TextStyle(color: theme.blue, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _startingRound = true);
    try {
      await widget.app.startNewContestRound();
      if (mounted) showHzToast(context, 'دوره‌ی تازه از همین لحظه آغاز شد.');
    } catch (_) {
      if (mounted) showHzToast(context, 'شروع دوره ناموفق بود؛ دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _startingRound = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final settings = widget.app.contestSettings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [theme.blue.withValues(alpha: 0.16), theme.yellow.withValues(alpha: 0.08)], begin: Alignment.centerRight, end: Alignment.centerLeft),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.blue.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.event_available, size: 16, color: theme.blue),
              const SizedBox(width: 6),
              Expanded(child: Text('وضعیت دوره‌ی فعلی', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 8),
            Text(
              !settings.hasActiveRound
                  ? 'هنوز هیچ دوره‌ای آغاز نشده — با دکمه‌ی زیر اولین دوره را شروع کنید.'
                  : settings.submissionsOpen
                      ? 'دوره از ${afghanDateLabel(settings.roundStartedAt!)} آغاز شده؛ ${settings.timeUntilDeadline.inDays} روز تا پایان مهلت ارسال (${afghanDateLabel(settings.submissionDeadline!)}) باقی است.'
                      : 'مهلت ارسال این دوره در ${afghanDateLabel(settings.submissionDeadline!)} تمام شده — از تب «مقالات ارسالی» رتبه‌بندی را اجرا کنید.',
              style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.8),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _startingRound ? null : _startNewRound,
                icon: _startingRound
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.blue))
                    : const Icon(Icons.play_circle_outline, size: 16),
                label: Text(settings.hasActiveRound ? 'شروع دوره‌ی تازه از همین لحظه' : 'شروع اولین دوره از همین لحظه', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(foregroundColor: theme.blue, side: BorderSide(color: theme.blue.withValues(alpha: 0.4)), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.edit_document, size: 16, color: theme.blue),
              const SizedBox(width: 6),
              Text('موضوع مشترک این دوره', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            Text('همه‌ی کاربران مقاله‌شان را روی همین عنوان می‌نویسند — دیگر عنوان دلخواه وارد نمی‌کنند.', style: TextStyle(color: theme.textFaint, fontSize: 11.5, height: 1.7)),
            const SizedBox(height: 10),
            _formField(theme, _topicCtrl, hint: 'مثلاً: نقش زنان هزاره در حفظ فرهنگ و زبان', maxLines: 3),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.card_giftcard, size: 16, color: theme.yellow),
              const SizedBox(width: 6),
              Text('جوایز سه مقام برتر', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            Text('پیش از ارسال، در صفحه‌ی مسابقه به کاربران نشان داده می‌شود.', style: TextStyle(color: theme.textFaint, fontSize: 11.5, height: 1.7)),
            const SizedBox(height: 12),
            Text('🥇 جایزه‌ی نفر اول', style: TextStyle(color: theme.textFaint, fontSize: 12)),
            _formField(theme, _prizeFirstCtrl, hint: 'مثلاً: ۱۰٬۰۰۰ افغانی + لوح تقدیر'),
            const SizedBox(height: 12),
            Text('🥈 جایزه‌ی نفر دوم', style: TextStyle(color: theme.textFaint, fontSize: 12)),
            _formField(theme, _prizeSecondCtrl, hint: 'مثلاً: ۶٬۰۰۰ افغانی'),
            const SizedBox(height: 12),
            Text('🥉 جایزه‌ی نفر سوم', style: TextStyle(color: theme.textFaint, fontSize: 12)),
            _formField(theme, _prizeThirdCtrl, hint: 'مثلاً: ۳٬۰۰۰ افغانی'),
          ]),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined, size: 16),
          label: Text(_saving ? 'در حال ذخیره…' : 'ذخیره‌ی تنظیمات', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: theme.blue, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ],
    );
  }
}

Widget _formField(AppColors theme, TextEditingController ctrl, {String hint = '', int maxLines = 1}) {
  return Padding(
    padding: const EdgeInsets.only(top: 5),
    child: TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(color: theme.textPrimary, fontSize: 12.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textFaint, fontSize: 12.5),
        filled: true, fillColor: theme.bgCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.border)),
      ),
    ),
  );
}
