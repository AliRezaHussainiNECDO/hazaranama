import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/afghan_calendar.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

/// پرونده‌ی کامل یک کاربر — هدر با حلقه‌ی مقام کمک‌کننده، اطلاعات کامل
/// پروفایل، تغییر نقش/وضعیت، و جدول زمانیِ زنده‌ی همه‌ی فعالیت‌های او در
/// سراسر اپ (پست، کامنت، واکنش، مقاله، حواله، پیام) — هر بار که این صفحه
/// باز یا رفرش شود، تازه‌ترین اطلاعات را از سرور می‌خواند.
class UserDetailPage extends StatefulWidget {
  final String userId;
  const UserDetailPage({super.key, required this.userId});
  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  List<UserActivityEntry> _activity = [];
  bool _loadingActivity = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadingActivity = true);
    try {
      final app = context.read<AppState>();
      final activityFuture = app.fetchUserActivity(widget.userId);
      await app.loadUsers();
      _activity = await activityFuture;
    } catch (_) {
      // شبکه در دسترس نیست؛ آخرین اطلاعات فعلی نمایش داده می‌شود
    } finally {
      if (mounted) setState(() => _loadingActivity = false);
    }
  }

  Future<void> _toggleStatus(AppState app, UserProfile user) async {
    setState(() => _busy = true);
    try {
      await app.toggleUserStatus(user.id);
      if (mounted) showHzToast(context, user.status == UserStatus.active ? 'حساب مسدود شد' : 'حساب دوباره فعال شد');
    } catch (_) {
      if (mounted) showHzToast(context, 'انجام نشد؛ دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeRole(AppState app, UserProfile user, UserRole role) async {
    if (role == UserRole.admin) {
      final theme = app.colors;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: theme.bgElevated,
          title: Text('«${user.name}» مدیر شود؟', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
          content: Text('مدیر به همه‌ی بخش‌های مدیریتی اپ دسترسی کامل خواهد داشت.', style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.7)),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('انصراف')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('تأیید', style: TextStyle(color: theme.yellow, fontWeight: FontWeight.w700))),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await app.updateUserRole(user.id, role);
      if (mounted) showHzToast(context, 'نقش کاربر به‌روز شد');
    } catch (_) {
      if (mounted) showHzToast(context, 'تغییر نقش ناموفق بود؛ دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// ساخت کد ۸ رقمیِ بازیابی رمز برای این کاربر (اعتبار ۲۴ ساعت) — چون سرویس
  /// ایمیل خودکار نداریم، مدیر این کد را خودش برای کاربر می‌فرستد.
  Future<void> _makeRecoveryCode(AppState app, UserProfile user) async {
    setState(() => _busy = true);
    String? code;
    try {
      code = await app.createRecoveryCode(user.id);
    } catch (_) {
      if (mounted) showHzToast(context, 'ساخت کد ناموفق بود؛ دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (code == null || !mounted) return;
    final theme = app.colors;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.bgElevated,
        title: Text('کد بازیابی رمز «${user.name}»', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SelectableText(code!, textDirection: TextDirection.ltr, style: TextStyle(color: theme.yellow, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 6)),
          const SizedBox(height: 12),
          Text('این کد را برای ${user.email} بفرستید. کاربر در صفحه‌ی «فراموشی رمز» ایمیلش را وارد می‌کند و بعد این کد را؛ سپس رمز تازه می‌گذارد. اعتبار: ۲۴ ساعت، فقط یک‌بار.',
              style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.8)),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code!));
              Navigator.of(ctx).pop();
              showHzToast(context, 'کد کپی شد');
            },
            child: Text('کپی کد', style: TextStyle(color: theme.yellow, fontWeight: FontWeight.w700)),
          ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('بستن')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final user = app.users.where((u) => u.id == widget.userId).cast<UserProfile?>().firstWhere((_) => true, orElse: () => null);

    if (user == null) {
      return Directionality(textDirection: TextDirection.rtl, child: Scaffold(backgroundColor: theme.bg, body: const SizedBox()));
    }

    final donorTotal = app.donorTotalForUser(user.id);
    final tier = donorTierForUser(user, donorTotal);
    final isSelf = user.id == app.currentUser?.id;

    final counts = <UserActivityType, int>{};
    for (final a in _activity) {
      counts[a.type] = (counts[a.type] ?? 0) + 1;
    }
    final postsCount = counts[UserActivityType.post] ?? 0;
    final commentsCount = (counts[UserActivityType.postComment] ?? 0) + (counts[UserActivityType.videoComment] ?? 0) + (counts[UserActivityType.articleComment] ?? 0);
    final reactionsCount = (counts[UserActivityType.postReaction] ?? 0) + (counts[UserActivityType.videoReaction] ?? 0) + (counts[UserActivityType.articleReaction] ?? 0) + (counts[UserActivityType.commentLike] ?? 0);
    final articlesCount = counts[UserActivityType.articleSubmission] ?? 0;
    final donationsCount = counts[UserActivityType.donationTransfer] ?? 0;
    final messagesCount = counts[UserActivityType.contactMessage] ?? 0;

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
                title: Text('پرونده‌ی کاربر', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.6)),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                children: [
                  Center(
                    child: Column(children: [
                      DonorRing(
                        theme: theme, tier: tier, size: 100, childSize: 76,
                        child: HzBadge(theme: theme, size: 76, filled: true, avatarPath: user.avatarPath,
                            child: Text(user.name.isNotEmpty ? user.name[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28))),
                      ),
                      const SizedBox(height: 10),
                      Text(user.name, style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(user.email, style: TextStyle(color: theme.textFaint, fontSize: 12)),
                      const SizedBox(height: 8),
                      Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
                        _pill(user.role == UserRole.admin ? theme.yellow : user.role == UserRole.editor ? theme.blue : theme.textFaint, roleLabel(user.role)),
                        _pill(user.status == UserStatus.active ? theme.success : theme.danger, user.status == UserStatus.active ? 'فعال' : 'مسدود'),
                        if (tier != null) DonorTierChip(tier: tier),
                      ]),
                    ]),
                  ).animate().fadeIn(duration: 350.ms).scale(begin: const Offset(0.92, 0.92)),
                  const SizedBox(height: 20),
                  _DonorSummaryCard(theme: theme, totalUsd: donorTotal, isAdmin: user.role == UserRole.admin),
                  const SizedBox(height: 16),
                  Text('آمار فعالیت', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.35,
                    children: [
                      _miniStat(theme, Icons.dynamic_feed_rounded, postsCount, 'پست'),
                      _miniStat(theme, Icons.mode_comment_rounded, commentsCount, 'نظر'),
                      _miniStat(theme, Icons.favorite_rounded, reactionsCount, 'واکنش'),
                      _miniStat(theme, Icons.article_rounded, articlesCount, 'مقاله'),
                      _miniStat(theme, Icons.volunteer_activism_rounded, donationsCount, 'کمک'),
                      _miniStat(theme, Icons.support_agent_rounded, messagesCount, 'پیام'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('اطلاعات پروفایل', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  _infoRow(theme, Icons.public, 'کشور محل سکونت', user.country),
                  _infoRow(theme, Icons.map_outlined, 'ولایت/منطقه‌ی اصلی نیاکان', user.originProvince),
                  _infoRow(theme, Icons.account_balance_outlined, 'ولسوالی', user.district),
                  _infoRow(theme, Icons.groups_outlined, 'طایفه', user.tribe),
                  _infoRow(theme, Icons.translate, 'زبان مادری', user.nativeLanguage),
                  _infoRow(theme, Icons.access_time, 'تاریخ عضویت', user.joined),
                  if (user.bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('یادداشت / درباره‌ی ریشه‌ها', style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.glassBorder)),
                      child: Text(user.bio, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.8)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('مدیریت حساب', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (isSelf)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: theme.bgCardAlt, borderRadius: BorderRadius.circular(12)),
                      child: Text('این حساب خودِ شماست — نقش و وضعیت آن از این‌جا قابل تغییر نیست.', style: TextStyle(color: theme.textFaint, fontSize: 12, height: 1.8)),
                    )
                  else ...[
                    _label(theme, 'نقش کاربر'),
                    HzSelectField(
                      value: roleLabel(user.role),
                      icon: Icons.admin_panel_settings_outlined,
                      hint: 'نقش',
                      options: UserRole.values.map(roleLabel).toList(),
                      theme: theme,
                      onChanged: (v) {
                        if (_busy) return;
                        final match = UserRole.values.firstWhere((r) => roleLabel(r) == v, orElse: () => user.role);
                        if (match != user.role) _changeRole(app, user, match);
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : () => _toggleStatus(app, user),
                        icon: Icon(user.status == UserStatus.active ? Icons.block : Icons.check, size: 16),
                        label: Text(user.status == UserStatus.active ? 'مسدودسازی این حساب' : 'فعال‌سازی دوباره‌ی این حساب', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: user.status == UserStatus.active ? theme.danger : theme.success,
                          foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _makeRecoveryCode(app, user),
                        icon: Icon(Icons.key_rounded, size: 16, color: theme.yellow),
                        label: Text('ساخت کد بازیابی رمز عبور', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: theme.yellow)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.yellow.withValues(alpha: 0.6)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(children: [
                    Icon(Icons.history_rounded, size: 15, color: theme.aiViolet),
                    const SizedBox(width: 7),
                    Text('تاریخچه‌ی فعالیت', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 22),
                    child: Text('همه‌ی کارهایی که این کاربر در اپ انجام داده — تازه‌ترین در بالا.', style: TextStyle(color: theme.textFaint, fontSize: 12, height: 1.7)),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingActivity)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
                  else if (_activity.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('هنوز فعالیتی ثبت نشده است.', style: TextStyle(color: theme.textFaint, fontSize: 12.5))))
                  else
                    for (final (i, a) in _activity.indexed) ...[
                      _ActivityTile(theme: theme, entry: a).staggered(i, step: const Duration(milliseconds: 22)),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pill(Color color, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _label(AppColors theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
      );

  Widget _miniStat(AppColors theme, IconData icon, int value, String label) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.glassBorder)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: theme.blue),
        const SizedBox(height: 5),
        Text('$value', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
      ]),
    );
  }

  Widget _infoRow(AppColors theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.glassBorder)),
        child: Row(children: [
          Icon(icon, size: 15, color: theme.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: theme.textFaint, fontSize: 11)),
              Text(value, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// کارت خلاصه‌ی مقام کمک‌کننده — بدون دکمه‌ی «کمک کن» (این پرونده‌ی کاربرِ
/// دیگری است، نه پروفایل خودِ مدیر).
class _DonorSummaryCard extends StatelessWidget {
  final AppColors theme;
  final double totalUsd;
  final bool isAdmin;
  const _DonorSummaryCard({required this.theme, required this.totalUsd, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    // مدیر همیشه بالاترین مقام را دارد؛ بقیه‌ی کاربران دقیقاً همان منطق قبلی.
    final tier = isAdmin ? kDonorTiers.last : donorTierForUsd(totalUsd);
    final next = isAdmin ? null : nextDonorTier(totalUsd);
    final progress = isAdmin ? 1.0 : progressToNextDonorTier(totalUsd);
    return HzGlassCard(
      theme: theme,
      radius: 18,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.volunteer_activism_rounded, size: 16, color: theme.success),
          const SizedBox(width: 7),
          Expanded(child: Text(tier != null ? 'مقام: ${tier.title}' : 'هنوز کمکی تأیید نشده', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800))),
          Text('~${totalUsd.toStringAsFixed(0)}\$', style: TextStyle(color: theme.success, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        if (next != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: theme.bgCardAlt, color: theme.success),
          ),
          const SizedBox(height: 5),
          Text('${(next.minUsd - totalUsd).clamp(0, next.minUsd).toStringAsFixed(0)} دلار دیگر تا مقام «${next.title}»', style: TextStyle(color: theme.textFaint, fontSize: 11)),
        ],
      ]),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final AppColors theme;
  final UserActivityEntry entry;
  const _ActivityTile({required this.theme, required this.entry});

  (IconData, Color) get _iconAndColor => switch (entry.type) {
        UserActivityType.post => (Icons.dynamic_feed_rounded, theme.blue),
        UserActivityType.postComment => (Icons.mode_comment_rounded, theme.blue),
        UserActivityType.videoComment => (Icons.smart_display_rounded, theme.aiViolet),
        UserActivityType.articleSubmission => (Icons.article_rounded, theme.success),
        UserActivityType.articleComment => (Icons.rate_review_rounded, theme.success),
        UserActivityType.donationTransfer => (Icons.volunteer_activism_rounded, theme.yellow),
        UserActivityType.contactMessage => (Icons.support_agent_rounded, theme.danger),
        UserActivityType.postReaction => (Icons.favorite_rounded, theme.blue),
        UserActivityType.videoReaction => (Icons.favorite_rounded, theme.aiViolet),
        UserActivityType.articleReaction => (Icons.favorite_rounded, theme.success),
        UserActivityType.commentLike => (Icons.thumb_up_rounded, theme.textFaint),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconAndColor;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.glassBorder)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StatIconBox(icon: icon, color: color, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(userActivityTypeLabel(entry.type), style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
              Text(afghanDateLabel(entry.occurredAt), style: TextStyle(color: theme.textFaint, fontSize: 11)),
            ]),
            if (entry.summary.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(entry.summary, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.7), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
      ]),
    );
  }
}
