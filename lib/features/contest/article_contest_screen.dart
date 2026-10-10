import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/afghan_calendar.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

/// صفحه‌ی مسابقه‌ی مقالات — قوانین و جایزه، دکمه‌ی شرکت (فرم نوشتن مقاله با
/// مشخصات کاربر)، و فهرست مقالات ارسالی خودِ کاربر با وضعیت/رتبه‌ی هرکدام.
/// هر مقاله یک دوره‌ی داوری ۳۰ روزه دارد؛ اصالت متن با کمک هوش مصنوعی
/// (به‌صورت کمکی، نه قطعی) بررسی و تصمیم نهایی توسط مدیر گرفته می‌شود.
class ArticleContestScreen extends StatefulWidget {
  const ArticleContestScreen({super.key});
  @override
  State<ArticleContestScreen> createState() => _ArticleContestScreenState();
}

class _ArticleContestScreenState extends State<ArticleContestScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final app = context.read<AppState>();
      await Future.wait([app.loadMyArticles(), app.loadContestSettings()]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final myArticles = app.myArticles;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: AppBar(
                backgroundColor: theme.bgElevated.withValues(alpha: 0.5),
                elevation: 0,
                leading: IconButton(icon: Icon(Icons.arrow_forward, color: theme.textPrimary, size: 20), onPressed: () => Navigator.of(context).pop()),
                title: Text('مسابقه‌ی مقالات', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.6)),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                      children: [
                        _RulesCard(theme: theme, settings: app.contestSettings).animate().fadeIn(duration: 350.ms).slideY(begin: -0.03, end: 0),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArticleSubmitScreen())),
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: const Text('شرکت در مسابقه — نوشتن مقاله', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.blue, foregroundColor: Colors.white, elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Row(children: [
                          Icon(Icons.article_outlined, size: 15, color: theme.blue),
                          const SizedBox(width: 7),
                          Text('مقالات من', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 12),
                        if (myArticles.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: Text('هنوز مقاله‌ای ارسال نکرده‌اید', style: TextStyle(color: theme.textFaint, fontSize: 12))),
                          )
                        else
                          for (final (i, a) in myArticles.indexed) ...[
                            _MyArticleCard(theme: theme, article: a, settings: app.contestSettings).staggered(i),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  final AppColors theme;
  final ContestSettings settings;
  const _RulesCard({required this.theme, required this.settings});

  @override
  Widget build(BuildContext context) {
    return HzGlassCard(
      theme: theme,
      radius: 22,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatIconBox(icon: Icons.emoji_events, color: theme.yellow, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مسابقه‌ی مقالات هزاره‌نامه', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('برای سه مقام برتر هر دوره جایزه در نظر گرفته شده', style: TextStyle(color: theme.textFaint, fontSize: 12)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        const FlagStripe(width: 46),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: theme.blue.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.blue.withValues(alpha: 0.25))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.edit_document, size: 14, color: theme.blue),
              const SizedBox(width: 6),
              Text('موضوع این دوره', style: TextStyle(color: theme.blue, fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            Text(settings.topic, style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700, height: 1.7)),
            const SizedBox(height: 4),
            Text('همه‌ی شرکت‌کنندگان مقاله‌شان را روی همین موضوع می‌نویسند.', style: TextStyle(color: theme.textFaint, fontSize: 11.5, height: 1.7)),
          ]),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (settings.submissionsOpen ? theme.success : theme.yellow).withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (settings.submissionsOpen ? theme.success : theme.yellow).withValues(alpha: 0.28)),
          ),
          child: Row(children: [
            Icon(Icons.hourglass_bottom, size: 14, color: settings.submissionsOpen ? theme.success : theme.yellow),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                !settings.hasActiveRound
                    ? 'دوره‌ی این ماه هنوز از سوی مدیریت آغاز نشده.'
                    : settings.submissionsOpen
                        ? '${settings.timeUntilDeadline.inDays} روز تا پایان مهلت ارسال باقی است.'
                        : 'مهلت ارسال این دوره تمام شده؛ در انتظار رتبه‌بندی هستیم.',
                style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.7),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Text('جوایز این دوره', style: TextStyle(color: theme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _prizeRow('🥇', 'نفر اول', settings.prizeFirst, theme.yellow),
        _prizeRow('🥈', 'نفر دوم', settings.prizeSecond, theme.textSecondary),
        _prizeRow('🥉', 'نفر سوم', settings.prizeThird, theme.blue),
        const SizedBox(height: 6),
        const FlagStripe(width: 46),
        const SizedBox(height: 14),
        _rule(theme, Icons.timer_outlined, 'هر دوره ۳۰ روز است: ۲۸ روز برای ارسال مقاله، و ۲ روز آخر برای اینکه دیگران برگزیدگان را بخوانند و نظر بدهند.'),
        _rule(theme, Icons.auto_awesome, 'دقیقاً در پایان روز ۲۸، هوش مصنوعی جیمینی همه‌ی مقالات را از نظر اصالت و کیفیت بررسی می‌کند تا نوشته‌ی خودِ شما باشد، نه کپی از هوش مصنوعی یا منابع دیگر.'),
        _rule(theme, Icons.workspace_premium_outlined, 'سه مقاله‌ی برتر را هوش مصنوعی خودش بر اساس نمره‌ی کیفیت انتخاب می‌کند و در بخش «برگزیدگان مسابقه‌ی مقالات» منتشر می‌کند.'),
        _rule(theme, Icons.info_outline, 'می‌توانید بیش از یک مقاله ارسال کنید؛ وضعیت و رتبه‌ی هرکدام را همین‌جا می‌بینید.'),
      ]),
    );
  }

  Widget _prizeRow(String emoji, String label, String? prize, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              (prize == null || prize.trim().isEmpty) ? 'به‌زودی اعلام می‌شود' : prize,
              style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.7),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      );

  Widget _rule(AppColors theme, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: theme.blue),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.9))),
        ]),
      );
}

class _MyArticleCard extends StatelessWidget {
  final AppColors theme;
  final ArticleSubmission article;
  final ContestSettings settings;
  const _MyArticleCard({required this.theme, required this.article, required this.settings});

  @override
  Widget build(BuildContext context) {
    final isWinner = article.placement != null;
    final placementColor = article.placement == 1
        ? theme.yellow
        : article.placement == 2
            ? theme.textSecondary
            : theme.blue;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.bgCard.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isWinner ? placementColor.withValues(alpha: 0.6) : theme.glassBorder, width: isWinner ? 1.4 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.5)),
          ),
          if (isWinner) ...[
            const SizedBox(width: 8),
            Icon(Icons.emoji_events, size: 18, color: placementColor),
          ],
        ]),
        const SizedBox(height: 6),
        Text('ارسال: ${afghanDateLabel(article.submittedAt)}', style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
        const SizedBox(height: 10),
        _statusBadge(),
      ]),
    );
  }

  Widget _statusBadge() {
    if (article.placement == 1) return _badge('🥇 رتبه‌ی شما: نفر اول شد!', theme.yellow);
    if (article.placement == 2) return _badge('🥈 رتبه‌ی شما: نفر دوم شد!', theme.textSecondary);
    if (article.placement == 3) return _badge('🥉 رتبه‌ی شما: نفر سوم شد!', theme.blue);

    switch (article.status) {
      case ArticleStatus.disqualified:
        return _badge('این مقاله معیارهای اصالت مسابقه را برآورده نکرد', theme.danger);
      case ArticleStatus.published:
        return _badge('منتشرشده در بخش برگزیدگان', theme.success);
      case ArticleStatus.closed:
        return _badge('دوره‌ی داوری تمام شد — در انتظار انتخاب مدیر', theme.blue);
      case ArticleStatus.active:
        if (!settings.hasActiveRound) return _badge('در انتظار آغاز دوره از سوی مدیریت', theme.textFaint);
        if (settings.submissionsOpen) return _badge('${_toFaNum(settings.timeUntilDeadline.inDays)} روز تا پایان مهلت ارسال و رتبه‌بندی', theme.yellow);
        return _badge('مهلت ارسال تمام شده — در انتظار رتبه‌بندی با هوش مصنوعی', theme.blue);
    }
  }

  Widget _badge(String text, Color color) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );

  String _toFaNum(int n) {
    const map = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    return n.toString().split('').map((d) => map[int.parse(d)]).join();
  }
}

// =============================================================================
// فرم نوشتن و ارسال مقاله
// =============================================================================

class ArticleSubmitScreen extends StatefulWidget {
  const ArticleSubmitScreen({super.key});
  @override
  State<ArticleSubmitScreen> createState() => _ArticleSubmitScreenState();
}

class _ArticleSubmitScreenState extends State<ArticleSubmitScreen> {
  final _bodyCtrl = TextEditingController();
  bool _agreed = false;
  bool _submitting = false;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    if (!app.contestSettings.submissionsOpen) {
      showHzToast(context, app.contestSettings.hasActiveRound ? 'مهلت ارسال این دوره تمام شده است.' : 'دوره‌ی مسابقه هنوز از سوی مدیریت آغاز نشده است.');
      return;
    }
    if (_bodyCtrl.text.trim().length < 50) {
      showHzToast(context, 'متن مقاله را کامل‌تر بنویسید (حداقل ۵۰ نویسه).');
      return;
    }
    if (!_agreed) {
      showHzToast(context, 'برای ارسال، باید تأیید کنید که این نوشته کاملاً کار خودتان است.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await app.submitArticle(title: app.contestSettings.topic, body: _bodyCtrl.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
        showHzToast(context, 'مقاله‌ی شما ثبت شد؛ در پایان مهلت این دوره با هوش مصنوعی بررسی و رتبه‌بندی می‌شود.');
      }
    } catch (_) {
      if (mounted) showHzToast(context, 'ارسال مقاله ناموفق بود؛ دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final user = app.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: AppBar(
                backgroundColor: theme.bgElevated.withValues(alpha: 0.5),
                elevation: 0,
                leading: IconButton(icon: Icon(Icons.arrow_forward, color: theme.textPrimary, size: 20), onPressed: () => Navigator.of(context).pop()),
                title: Text('نوشتن مقاله', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.6)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              children: [
                HzGlassCard(
                  theme: theme,
                  radius: 20,
                  child: Row(children: [
                    DonorRing(
                      theme: theme, size: 48, childSize: 42,
                      tier: donorTierForUser(user, app.myDonationTotalUsd),
                      child: HzBadge(theme: theme, size: 42, filled: true, avatarPath: user?.avatarPath,
                          child: Text((user?.name.isNotEmpty ?? false) ? user!.name[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user?.name ?? '—', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        Text(user?.email ?? '', style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
                      ]),
                    ),
                  ]),
                ),
                if (!app.contestSettings.submissionsOpen) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(color: theme.danger.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.danger.withValues(alpha: 0.28))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.lock_clock_outlined, size: 16, color: theme.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          app.contestSettings.hasActiveRound
                              ? 'مهلت ارسال این دوره تمام شده — فرم غیرفعال است تا دوره‌ی بعدی آغاز شود.'
                              : 'دوره‌ی مسابقه هنوز از سوی مدیریت آغاز نشده — فعلاً امکان ارسال نیست.',
                          style: TextStyle(color: theme.danger, fontSize: 12.5, height: 1.8, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 16),
                _label(theme, 'عنوان مقاله (مشترک برای همه‌ی شرکت‌کنندگان این دوره)'),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: theme.blue.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.blue.withValues(alpha: 0.25))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.push_pin_outlined, size: 15, color: theme.blue),
                    const SizedBox(width: 8),
                    Expanded(child: Text(app.contestSettings.topic, style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700, height: 1.7))),
                  ]),
                ),
                const SizedBox(height: 16),
                _label(theme, 'متن مقاله'),
                _field(theme, _bodyCtrl, hint: 'مقاله‌ی خودتان را همین‌جا بنویسید…', maxLines: 16),
                const SizedBox(height: 6),
                Text('حداقل ۵۰ نویسه؛ فقط نوشته‌ی خودتان — نه کپی از اینترنت یا هوش مصنوعی.', style: TextStyle(color: theme.textFaint, fontSize: 11.5, height: 1.8)),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => setState(() => _agreed = !_agreed),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.glassBorder)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(_agreed ? Icons.check_box : Icons.check_box_outline_blank, size: 19, color: _agreed ? theme.blue : theme.textFaint),
                      const SizedBox(width: 9),
                      Expanded(child: Text('تأیید می‌کنم این نوشته کاملاً کار خودم است و از هوش مصنوعی یا منابع دیگر کپی نشده است.', style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.8))),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: (_submitting || !app.contestSettings.submissionsOpen) ? null : () => _submit(app),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.blue, foregroundColor: Colors.white, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('ارسال مقاله', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(AppColors theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
      );

  Widget _field(AppColors theme, TextEditingController ctrl, {String hint = '', int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(color: theme.textPrimary, fontSize: 12.5, height: 1.8),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textFaint, fontSize: 12.5),
        filled: true, fillColor: theme.bgCard.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.glassBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.blue)),
      ),
    );
  }
}
