import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../core/section_style.dart';
import '../../data/sections.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../donations/donation_screen.dart' show donationCategoryIcon;
import '../profile/account_settings_screen.dart';

class OverviewPage extends StatefulWidget {
  final void Function(String page)? onOpenPage;
  const OverviewPage({super.key, this.onOpenPage});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  bool _loadingExtras = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final app = context.read<AppState>();
    await Future.wait([
      app.loadRecentActivity(),
      app.loadAdminInbox(),
      app.loadTodayVisitCount(),
      app.loadUsers().catchError((_) {}),
    ]);
    if (mounted) setState(() => _loadingExtras = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;

    final totalItems = kSections.where((s) => s.id != 'oral' && s.id != 'articleWinners').fold<int>(0, (n, s) => n + app.sectionItemCount(s.id));
    final totalComments = app.posts.fold<int>(0, (s, p) => s + p.commentsCount);
    final activeUsers = app.users.where((u) => u.status.name == 'active').length;

    final stats = [
      _Stat('کاربران فعال', activeUsers, Icons.groups_rounded, theme.blue, null),
      _Stat('بازدید امروز', app.todayVisitCount, Icons.visibility_rounded, theme.yellow, app.visitTrend.isEmpty ? null : app.visitTrend),
      _Stat('پست‌های حافظه جمعی', app.posts.length, Icons.forum_rounded, theme.aiViolet, null),
      _Stat('نظرها روی پست‌ها', totalComments, Icons.mode_comment_rounded, theme.aiTeal, null),
    ];
    final sectionStats = kSections.where((s) => s.id != 'oral' && s.id != 'dailyStory' && s.id != 'articleWinners').map((s) {
      return (id: s.id, title: s.title, count: app.sectionItemCount(s.id));
    }).toList();
    final maxCount = sectionStats.map((s) => s.count).fold(1, (a, b) => a > b ? a : b);

    final latestDonations = app.allDonationTransfers.take(8).toList();
    final latestArticles = app.allArticleSubmissions.take(8).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _AdminProfileCard(theme: theme, app: app, activeUsers: activeUsers),
        const SizedBox(height: 18),
        _PendingTasks(theme: theme, app: app, onOpenPage: widget.onOpenPage),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.1,
          children: stats
              .map((s) => HzStatTile(
                    theme: theme,
                    icon: s.icon,
                    color: s.color,
                    value: '${s.value}',
                    label: s.label,
                    trailing: s.trend == null ? null : Sparkline(data: s.trend!, color: s.color, width: 44, height: 20),
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.glassBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              StatIconBox(icon: Icons.dashboard, color: theme.blue, size: 26),
              const SizedBox(width: 8),
              Text('محتوای بخش‌ها ($totalItems مطلب)', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            for (final s in sectionStats) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(s.title, style: TextStyle(color: theme.textSecondary, fontSize: 12.5)),
                    Text('${s.count}', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: s.count / maxCount, minHeight: 6, backgroundColor: theme.bgCardAlt, valueColor: AlwaysStoppedAnimation(sectionStyle(s.id).a)),
                  ),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        _SectionHeader(icon: Icons.volunteer_activism, color: theme.success, title: 'آخرین کمک‌های مالی', theme: theme),
        const SizedBox(height: 10),
        _DonationsStrip(theme: theme, donations: latestDonations, loading: _loadingExtras),
        const SizedBox(height: 18),
        _SectionHeader(icon: Icons.article, color: theme.blue, title: 'آخرین مقالات ارسالی', theme: theme),
        const SizedBox(height: 10),
        _ArticlesStrip(theme: theme, articles: latestArticles, loading: _loadingExtras),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.glassBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              StatIconBox(icon: Icons.notifications, color: theme.yellow, size: 26),
              const SizedBox(width: 8),
              Text('آخرین فعالیت‌ها', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            if (_loadingExtras)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: theme.blue))),
              )
            else if (app.recentActivity.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('هنوز فعالیتی در اپ ثبت نشده است.', style: TextStyle(color: theme.textFaint, fontSize: 12.5)),
              )
            else
              for (var i = 0; i < app.recentActivity.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(shape: BoxShape.circle, color: i.isEven ? theme.blue : theme.yellow)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontFamily: 'Vazirmatn', color: theme.textSecondary, fontSize: 12.5, height: 1.7),
                          children: [
                            TextSpan(text: app.userNameById(app.recentActivity[i].userId), style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w700)),
                            TextSpan(text: ' — ${userActivityTypeLabel(app.recentActivity[i].type)}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(_timeAgo(app.recentActivity[i].occurredAt), style: TextStyle(color: theme.textFaint, fontSize: 11)),
                  ]),
                ).animate(delay: (60 * i).ms).fadeIn(duration: 260.ms).slideX(begin: 0.03, end: 0),
          ]),
        ),
      ],
    );
  }
}

class _Stat {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final List<double>? trend; // فقط وقتی داده‌ی واقعی روزانه داریم
  _Stat(this.label, this.value, this.icon, this.color, this.trend);
}

/// کارت پروفایل مدیر — بالای صفحه‌ی نخست پنل مدیریت. عکس واقعی مدیر با
/// همان حلقه‌ی مقام کمک‌کننده‌ی سراسر اپ (همیشه بالاترین مقام برای مدیر)،
/// نام، نشان نقش، ایمیل، تاریخ عضویت و زادگاه — دقیقاً با همان زبان بصری
/// (کارت شیشه‌ای، تراشه‌های گرد رنگی) که بقیه‌ی بخش‌های اپ استفاده می‌کنند.
class _AdminProfileCard extends StatelessWidget {
  final AppColors theme;
  final AppState app;
  final int activeUsers;
  const _AdminProfileCard({required this.theme, required this.app, required this.activeUsers});

  @override
  Widget build(BuildContext context) {
    final user = app.currentUser;
    final tier = donorTierForUser(user, app.myDonationTotalUsd);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [theme.bgElevated.withValues(alpha: 0.7), theme.bgCard.withValues(alpha: 0.5)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.glassBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountSettingsScreen())),
            child: DonorRing(
              theme: theme, tier: tier, size: 76, childSize: 58,
              child: HzBadge(theme: theme, size: 58, filled: true, avatarPath: app.avatarPath,
                  child: Text(app.displayName.isNotEmpty ? app.displayName[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('سلام، ${app.displayName} 👋', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.textPrimary, fontSize: 15.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('خلاصه‌ای از وضعیت هزاره‌نامه امروز', style: TextStyle(color: theme.textFaint, fontSize: 12.5)),
              const SizedBox(height: 8),
              const FlagStripe(width: 46),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _InfoChip(theme: theme, icon: Icons.shield_rounded, label: roleLabel(user?.role ?? UserRole.admin), color: theme.yellow),
          if (tier != null) DonorTierChip(tier: tier),
          if ((user?.email ?? '').isNotEmpty) _InfoChip(theme: theme, icon: Icons.mail_outline_rounded, label: user!.email, color: theme.blue),
          if ((user?.joined ?? '').isNotEmpty) _InfoChip(theme: theme, icon: Icons.event_outlined, label: 'عضویت ${user!.joined}', color: theme.textSecondary),
          if ((user?.country ?? 'نامشخص') != 'نامشخص') _InfoChip(theme: theme, icon: Icons.public_rounded, label: user!.country, color: theme.success),
          _InfoChip(theme: theme, icon: Icons.groups_rounded, label: '$activeUsers کاربر فعال زیر نظر', color: theme.blue),
        ]),
      ]),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.06, end: 0);
  }
}

/// تراشه‌ی کوچک آیکون‌دار — برای معلومات مختصر داخل کارت‌های پروفایل.
class _InfoChip extends StatelessWidget {
  final AppColors theme;
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.theme, required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.28))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final AppColors theme;
  const _SectionHeader({required this.icon, required this.color, required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      StatIconBox(icon: icon, color: color, size: 26),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
    ]);
  }
}

/// نوار افقیِ کارت‌های کوچکِ آخرین حواله‌های کمک مالی — هر بار که کسی کمک
/// اعلام می‌کند، همین‌جا در صفحه‌ی نخست مدیر بی‌درنگ دیده می‌شود.
class _DonationsStrip extends StatelessWidget {
  final AppColors theme;
  final List<DonationTransfer> donations;
  final bool loading;
  const _DonationsStrip({required this.theme, required this.donations, required this.loading});

  Color _statusColor(DonationTransferStatus s) => switch (s) {
        DonationTransferStatus.confirmed => theme.success,
        DonationTransferStatus.rejected => theme.danger,
        DonationTransferStatus.pending => theme.yellow,
      };

  String _statusLabel(DonationTransferStatus s) => switch (s) {
        DonationTransferStatus.confirmed => 'تأییدشده',
        DonationTransferStatus.rejected => 'رد شده',
        DonationTransferStatus.pending => 'در انتظار',
      };

  @override
  Widget build(BuildContext context) {
    if (loading) return _StripSkeleton(theme: theme);
    if (donations.isEmpty) return _StripEmpty(theme: theme, icon: Icons.volunteer_activism_outlined, text: 'هنوز هیچ کمکی اعلام نشده است.');

    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: donations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final t = donations[i];
          final color = _statusColor(t.status);
          return Container(
            width: 168,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                StatIconBox(icon: donationCategoryIcon(t.category), color: color, size: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                  child: Text(_statusLabel(t.status), style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800)),
                ),
              ]),
              const Spacer(),
              Text('${t.amount.toStringAsFixed(0)} ${t.currency}', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(t.senderName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(_timeAgo(t.submittedAt), style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
            ]),
          ).animate(delay: (70 * i).ms).fadeIn(duration: 280.ms).slideY(begin: 0.08, end: 0);
        },
      ),
    );
  }
}

/// نوار افقیِ کارت‌های کوچکِ آخرین مقالات ارسالی به مسابقه — بی‌درنگ همان
/// لحظه‌ای که کاربر مقاله‌اش را ارسال می‌کند، اینجا دیده می‌شود.
class _ArticlesStrip extends StatelessWidget {
  final AppColors theme;
  final List<ArticleSubmission> articles;
  final bool loading;
  const _ArticlesStrip({required this.theme, required this.articles, required this.loading});

  Color _statusColor(ArticleStatus s) => switch (s) {
        ArticleStatus.active => theme.blue,
        ArticleStatus.closed => theme.yellow,
        ArticleStatus.disqualified => theme.danger,
        ArticleStatus.published => theme.success,
      };

  String _statusLabel(ArticleStatus s) => switch (s) {
        ArticleStatus.active => 'در حال داوری',
        ArticleStatus.closed => 'دوره تمام شد',
        ArticleStatus.disqualified => 'رد صلاحیت‌شده',
        ArticleStatus.published => 'منتشرشده',
      };

  @override
  Widget build(BuildContext context) {
    if (loading) return _StripSkeleton(theme: theme);
    if (articles.isEmpty) return _StripEmpty(theme: theme, icon: Icons.article_outlined, text: 'هنوز هیچ مقاله‌ای ارسال نشده است.');

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: articles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final a = articles[i];
          final color = _statusColor(a.status);
          final hasAvatar = (a.authorAvatar ?? '').isNotEmpty;
          return Container(
            width: 190,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                HzBadge(theme: theme, size: 22, filled: true, avatarPath: hasAvatar ? a.authorAvatar : null,
                    child: Text(a.authorName.isNotEmpty ? a.authorName[0] : '؟', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800))),
                const SizedBox(width: 6),
                Expanded(child: Text(a.authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 8),
              Expanded(
                child: Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700, height: 1.35)),
              ),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                  child: Text(_statusLabel(a.status), style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800)),
                ),
                Text(_timeAgo(a.submittedAt), style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
              ]),
            ]),
          ).animate(delay: (70 * i).ms).fadeIn(duration: 280.ms).slideY(begin: 0.08, end: 0);
        },
      ),
    );
  }
}

class _StripSkeleton extends StatelessWidget {
  final AppColors theme;
  const _StripSkeleton({required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => Container(
          width: 168,
          decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 700.ms),
      ),
    );
  }
}

class _StripEmpty extends StatelessWidget {
  final AppColors theme;
  final IconData icon;
  final String text;
  const _StripEmpty({required this.theme, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: theme.textFaint),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: theme.textFaint, fontSize: 12.5)),
      ]),
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'همین الان';
  if (diff.inHours < 1) return '${diff.inMinutes} دقیقه پیش';
  if (diff.inDays < 1) return '${diff.inHours} ساعت پیش';
  if (diff.inDays < 30) return '${diff.inDays} روز پیش';
  return '${(diff.inDays / 30).floor()} ماه پیش';
}

/// «کارهای در انتظار» — هر کارت مستقیم به همان صفحه‌ی بررسی می‌رود.
class _PendingTasks extends StatelessWidget {
  final AppColors theme;
  final AppState app;
  final void Function(String page)? onOpenPage;
  const _PendingTasks({required this.theme, required this.app, this.onOpenPage});

  @override
  Widget build(BuildContext context) {
    final tasks = [
      (page: 'messages', label: 'پیام بی‌پاسخ', n: app.pendingMessagesCount, icon: Icons.mark_email_unread_rounded, color: theme.aiTeal),
      (page: 'donations', label: 'کمک مالی برای تأیید', n: app.pendingDonationsCount, icon: Icons.volunteer_activism_rounded, color: theme.success),
      (page: 'community', label: 'گزارش برای بررسی', n: app.pendingReportsCount, icon: Icons.flag_rounded, color: theme.danger),
      (page: 'contest', label: 'مقاله در دوره‌ی جاری', n: app.activeSubmissionsCount, icon: Icons.edit_note_rounded, color: theme.aiViolet),
    ];
    final total = tasks.fold<int>(0, (a, t) => a + t.n);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('کارهای در انتظار', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        if (total == 0)
          Row(children: [
            Icon(Icons.check_circle_rounded, size: 16, color: theme.success),
            const SizedBox(width: 4),
            Text('همه‌چیز رسیدگی شده', style: TextStyle(color: theme.success, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
      ]),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.1,
        children: [
          for (final t in tasks)
            Material(
              color: t.n > 0 ? Color.alphaBlend(t.color.withValues(alpha: 0.12), theme.bgCard.withValues(alpha: 0.85)) : theme.bgCard.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onOpenPage == null ? null : () => onOpenPage!(t.page),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: t.n > 0 ? t.color.withValues(alpha: 0.45) : theme.glassBorder),
                  ),
                  child: Row(children: [
                    Icon(t.icon, color: t.n > 0 ? t.color : theme.textFaint, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${t.n}', style: TextStyle(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, height: 1.1)),
                        Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 11.5)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
        ],
      ),
    ]);
  }
}
