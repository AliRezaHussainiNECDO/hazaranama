import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/afghan_calendar.dart' show toFaDigits;
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../models/rank.dart';
import '../../state/app_state.dart';

/// اثر ویژه‌ی هر مقام — همان چیزی که با رسیدن به آن مقام باز می‌شود
String rankPerkLabel(DonorTier t) => switch (t.index) {
      1 => 'حلقه‌ی نقره‌ای ساده دور عکس پروفایل',
      2 => 'حلقه‌ی آبی روشن با چرخش ملایم',
      3 => 'حلقه‌ی سبز درخشان + تیک سبز کنار نام',
      4 => 'قاب بنفش با درخشش نئونی',
      5 => 'قاب طلایی + ستاره‌ی کوچک بالای عکس',
      6 => 'قاب آتشین با شعله‌های متحرک',
      7 => 'ذرات درخشان شناور + استیکرهای اختصاصی',
      8 => 'تاج نقره‌ای + قاب پلاتینیومی و تیک بنفش',
      9 => 'تاج طلایی نگین‌دار + شعله‌های درخشان',
      _ => 'تاج شاهی، رنگین‌کمان کامل و کامنت‌های همیشه در صدر',
    };

LinearGradient _tierGradient(DonorTier t, {double alpha = 1}) => LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [for (final c in t.colors) c.withValues(alpha: alpha)],
    );

/// عدد فارسی با جداکننده‌ی هزارگان
String faNum(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('٬');
    b.write(s[i]);
  }
  return toFaDigits('${n < 0 ? '-' : ''}$b');
}

// =====================================================================
// کارت فشرده‌ی مقام — صفحه‌ی خانه و پروفایل
// =====================================================================
class RankCard extends StatelessWidget {
  final AppColors theme;
  const RankCard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.currentUser;
    if (user == null) return const SizedBox.shrink();
    final xp = app.myXp;
    final isAdmin = user.role == UserRole.admin;
    final tier = app.myRankTier;
    final next = isAdmin ? null : nextRankTier(xp);
    final progress = isAdmin ? 1.0 : progressToNextRank(xp);
    final pos = app.myRank?.position ?? 0;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(RankScreen.route()),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [tier.colors.first.withValues(alpha: 0.28), theme.bgCard.withValues(alpha: 0.85), tier.colors.last.withValues(alpha: 0.16)],
          ),
          border: Border.all(color: tier.colors.first.withValues(alpha: 0.45)),
          boxShadow: [BoxShadow(color: tier.colors.first.withValues(alpha: 0.18), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          DonorRing(
            theme: theme,
            tier: tier,
            size: 62,
            childSize: 52,
            child: HzBadge(
              theme: theme,
              size: 52,
              filled: true,
              avatarPath: app.avatarPath,
              child: Text(user.name.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: ShaderMask(
                    shaderCallback: (r) => _tierGradient(tier).createShader(r),
                    child: Text(tier.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 6),
                _MiniChip(theme: theme, text: 'مقام ${toFaDigits(tier.index)}', color: tier.colors.first),
                const Spacer(),
                if (pos > 0) Text('#${toFaDigits(pos)}', style: TextStyle(color: theme.textFaint, fontSize: 12, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 4),
              Text('${faNum(xp)} امتیاز فعالیت', style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _GlowBar(theme: theme, value: progress, from: tier.colors.first, to: (next ?? tier).colors.first, height: 7),
              const SizedBox(height: 5),
              Text(
                isAdmin ? 'مدیر هزاره‌نامه — بالاترین مقام' : next == null ? 'به بالاترین مقام رسیده‌اید 👑' : '${faNum(next.minXp - xp)} امتیاز تا «${next.title}»',
                style: TextStyle(color: theme.textFaint, fontSize: 11),
              ),
            ]),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_left_rounded, color: theme.textFaint),
        ]),
      ),
    );
  }
}

// =====================================================================
// صفحه‌ی کامل «مقام من»
// =====================================================================
class RankScreen extends StatefulWidget {
  const RankScreen({super.key});

  static Route<void> route() => PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) => const RankScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: SlideTransition(position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
        ),
      );

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  int _tab = 0; // ۰: راه‌های امتیاز، ۱: مسیر مقام‌ها، ۲: برترین‌ها

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().refreshRanks());
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final user = app.currentUser;
    final xp = app.myXp;
    final tier = app.myRankTier;
    final isAdmin = user?.role == UserRole.admin;
    final next = isAdmin ? null : nextRankTier(xp);
    final progress = isAdmin ? 1.0 : progressToNextRank(xp);
    final me = app.myRank;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bg,
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme)),
          // هاله‌ی رنگی مقام پشت سربرگ
          Positioned(
            top: -120,
            left: -60,
            right: -60,
            child: Container(
              height: 420,
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [tier.colors.first.withValues(alpha: 0.35), Colors.transparent], radius: 0.75),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: app.refreshRanks,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
                children: [
                  Row(children: [
                    IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: Icon(Icons.arrow_forward_rounded, color: theme.textPrimary)),
                    const SizedBox(width: 2),
                    Text('مقام من', style: TextStyle(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'مقام‌ها چطور کار می‌کنند؟',
                      onPressed: () => _showHelp(context, theme),
                      icon: Icon(Icons.help_outline_rounded, color: theme.textFaint),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  _Hero(theme: theme, tier: tier, xp: xp, next: next, progress: progress, isAdmin: isAdmin, user: user, avatar: app.avatarPath, position: me?.position ?? 0, total: app.rankLeaderboard.length),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _StatTile(theme: theme, icon: Icons.local_fire_department_rounded, color: const Color(0xFFFF8A3D), value: toFaDigits(me?.stat('visit') ?? 0), label: 'روز فعال')),
                    const SizedBox(width: 9),
                    Expanded(child: _StatTile(theme: theme, icon: Icons.auto_stories_rounded, color: const Color(0xFF5B93FF), value: toFaDigits((me?.stat('read') ?? 0) + (me?.stat('book') ?? 0) + (me?.stat('news') ?? 0)), label: 'خوانده‌شده')),
                    const SizedBox(width: 9),
                    Expanded(child: _StatTile(theme: theme, icon: Icons.forum_rounded, color: const Color(0xFFA06BFF), value: toFaDigits((me?.stat('post') ?? 0) + (me?.stat('comment') ?? 0)), label: 'پست و کامنت')),
                  ]).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 18),
                  _Tabs(theme: theme, index: _tab, accent: tier.colors.first, onChanged: (i) => setState(() => _tab = i)),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: switch (_tab) {
                      0 => _WaysGrid(key: const ValueKey(0), theme: theme, me: me),
                      1 => _Journey(key: const ValueKey(1), theme: theme, xp: isAdmin ? kDonorTiers.last.minXp : xp),
                      _ => _Leaders(key: const ValueKey(2), theme: theme),
                    },
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _showHelp(BuildContext context, AppColors theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          decoration: BoxDecoration(color: theme.bgElevated, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.glassBorder)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مقام‌ها چطور کار می‌کنند؟', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text(
              'هر کاری که در هزاره‌نامه می‌کنید امتیاز دارد: آمدن روزانه، خواندن روایت‌ها و مقاله‌ها، تماشای ویدیو، دانلود کتاب، خواندن خبر، نوشتن پست و کامنت، واکنش به کار دیگران و شرکت در مسابقه‌ی مقاله.\n\n'
              'با جمع‌شدن امتیاز، از «تازه‌وارد» تا «خاقان» ده مقام را طی می‌کنید و قاب دور عکس پروفایلتان زیباتر می‌شود. مقام‌ها هرگز افت نمی‌کنند.\n\n'
              'هر روایت، ویدیو، کتاب یا خبر فقط یک بار امتیاز می‌دهد. مقام با پول خریدنی نیست — فقط با فعالیت.',
              style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.9),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final AppColors theme;
  final DonorTier tier;
  final DonorTier? next;
  final int xp;
  final double progress;
  final bool isAdmin;
  final UserProfile? user;
  final String? avatar;
  final int position;
  final int total;
  const _Hero({required this.theme, required this.tier, required this.xp, required this.next, required this.progress, required this.isAdmin, required this.user, required this.avatar, required this.position, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: theme.bgCard.withValues(alpha: 0.72),
        border: Border.all(color: tier.colors.first.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [BoxShadow(color: tier.colors.first.withValues(alpha: 0.25), blurRadius: 40, offset: const Offset(0, 14))],
      ),
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          // پرتوهای چرخان پشت حلقه
          _Rays(color: tier.colors.first),
          DonorRing(
            theme: theme,
            tier: tier,
            size: 132,
            childSize: 112,
            child: HzBadge(
              theme: theme,
              size: 112,
              filled: true,
              avatarPath: avatar,
              child: Text((user?.name ?? 'ه').characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 40)),
            ),
          ),
        ]).animate().scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), duration: 600.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (r) => _tierGradient(tier).createShader(r),
          child: Text(tier.title, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.3)),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2400.ms, color: Colors.white.withValues(alpha: 0.5)),
        const SizedBox(height: 6),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
          _MiniChip(theme: theme, text: 'مقام ${toFaDigits(tier.index)} از ${toFaDigits(kDonorTiers.length)}', color: tier.colors.first),
          if (position > 0) _MiniChip(theme: theme, text: 'جایگاه ${toFaDigits(position)}${total > 0 ? ' از ${toFaDigits(total)}' : ''}', color: theme.blue),
        ]),
        const SizedBox(height: 16),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: xp),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(faNum(v), style: TextStyle(color: theme.textPrimary, fontSize: 34, fontWeight: FontWeight.w900, height: 1)),
            const SizedBox(width: 6),
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('امتیاز', style: TextStyle(color: theme.textFaint, fontSize: 13, fontWeight: FontWeight.w700))),
          ]),
        ),
        const SizedBox(height: 14),
        _GlowBar(theme: theme, value: progress, from: tier.colors.first, to: (next ?? tier).colors.first, height: 11),
        const SizedBox(height: 8),
        Row(children: [
          Text(tier.title, style: TextStyle(color: tier.colors.first, fontSize: 11.5, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text(
            isAdmin ? 'بالاترین مقام' : next == null ? 'قله را فتح کردید 👑' : '${faNum(next!.minXp - xp)} امتیاز مانده',
            style: TextStyle(color: theme.textFaint, fontSize: 11.5),
          ),
          const Spacer(),
          if (next != null) Text(next!.title, style: TextStyle(color: next!.colors.first, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ]),
        if (next != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: next!.colors.first.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: next!.colors.first.withValues(alpha: 0.3))),
            child: Row(children: [
              Icon(Icons.lock_open_rounded, size: 16, color: next!.colors.first),
              const SizedBox(width: 8),
              Expanded(child: Text('در مقام بعد: ${rankPerkLabel(next!)}', style: TextStyle(color: theme.textSecondary, fontSize: 11.5, height: 1.6))),
            ]),
          ),
        ],
      ]),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.05, end: 0);
  }
}

class _Rays extends StatefulWidget {
  final Color color;
  const _Rays({required this.color});
  @override
  State<_Rays> createState() => _RaysState();
}

class _RaysState extends State<_Rays> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Transform.rotate(
        angle: _c.value * 2 * math.pi,
        child: CustomPaint(size: const Size(200, 200), painter: _RaysPainter(widget.color)),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  final Color color;
  _RaysPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    const n = 14;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n;
      final p = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - 0.07), c.dy + r * math.sin(a - 0.07))
        ..lineTo(c.dx + r * math.cos(a + 0.07), c.dy + r * math.sin(a + 0.07))
        ..close();
      canvas.drawPath(
        p,
        Paint()
          ..shader = RadialGradient(colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => old.color != color;
}

class _GlowBar extends StatelessWidget {
  final AppColors theme;
  final double value;
  final Color from;
  final Color to;
  final double height;
  const _GlowBar({required this.theme, required this.value, required this.from, required this.to, required this.height});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => Container(
        height: height,
        decoration: BoxDecoration(color: theme.bgCardAlt.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(999)),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              width: math.max(height, c.maxWidth * v),
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(colors: [from, to]),
                boxShadow: [BoxShadow(color: to.withValues(alpha: 0.55), blurRadius: 10)],
              ),
            ).animate(onPlay: (ctl) => ctl.repeat()).shimmer(duration: 2200.ms, color: Colors.white.withValues(alpha: 0.45)),
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final AppColors theme;
  final String text;
  final Color color;
  const _MiniChip({required this.theme, required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
      );
}

class _StatTile extends StatelessWidget {
  final AppColors theme;
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatTile({required this.theme, required this.icon, required this.color, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.glassBorder)),
        child: Column(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.16)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 7),
          Text(value, style: TextStyle(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
        ]),
      );
}

class _Tabs extends StatelessWidget {
  final AppColors theme;
  final int index;
  final Color accent;
  final ValueChanged<int> onChanged;
  const _Tabs({required this.theme, required this.index, required this.accent, required this.onChanged});
  static const _labels = ['راه‌های امتیاز', 'مسیر مقام‌ها', 'برترین‌ها'];
  static const _icons = [Icons.bolt_rounded, Icons.route_rounded, Icons.leaderboard_rounded];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
      child: Row(children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: i == index ? LinearGradient(colors: [accent.withValues(alpha: 0.9), theme.blue]) : null,
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_icons[i], size: 15, color: i == index ? Colors.white : theme.textFaint),
                  const SizedBox(width: 4),
                  Flexible(child: Text(_labels[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: i == index ? Colors.white : theme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w800))),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

class _WaysGrid extends StatelessWidget {
  final AppColors theme;
  final RankEntry? me;
  const _WaysGrid({super.key, required this.theme, required this.me});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('هر فعالیت در هزاره‌نامه امتیاز دارد', style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.7)),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.32,
        children: [
          for (final (i, w) in kXpWays.indexed)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [w.color.withValues(alpha: 0.18), theme.bgCard.withValues(alpha: 0.7)]),
                border: Border.all(color: w.color.withValues(alpha: 0.28)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: w.color.withValues(alpha: 0.2)),
                    child: Icon(w.icon, size: 17, color: w.color),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: w.color, borderRadius: BorderRadius.circular(999)),
                    child: Text('+${toFaDigits(w.points)}', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
                  ),
                ]),
                const Spacer(),
                Text(w.title, style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(w.hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 10.5, height: 1.5)),
                if (me != null) ...[
                  const SizedBox(height: 3),
                  Text('شما: ${toFaDigits(me!.stat(w.key))} بار', style: TextStyle(color: w.color, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ],
              ]),
            ).animate().fadeIn(delay: (40 * i).ms, duration: 300.ms).scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
        ],
      ),
    ]);
  }
}

class _Journey extends StatelessWidget {
  final AppColors theme;
  final int xp;
  const _Journey({super.key, required this.theme, required this.xp});

  @override
  Widget build(BuildContext context) {
    final current = rankTierForXp(xp).index;
    return Column(children: [
      for (final (i, t) in kDonorTiers.reversed.indexed)
        _JourneyRow(theme: theme, tier: t, reached: t.index <= current, isCurrent: t.index == current, isLast: i == kDonorTiers.length - 1, xp: xp)
            .animate()
            .fadeIn(delay: (45 * i).ms, duration: 300.ms)
            .slideX(begin: 0.04, end: 0),
    ]);
  }
}

class _JourneyRow extends StatelessWidget {
  final AppColors theme;
  final DonorTier tier;
  final bool reached;
  final bool isCurrent;
  final bool isLast;
  final int xp;
  const _JourneyRow({required this.theme, required this.tier, required this.reached, required this.isCurrent, required this.isLast, required this.xp});

  @override
  Widget build(BuildContext context) {
    final c = tier.colors.first;
    Widget badge = DonorRing(
      theme: theme,
      tier: reached ? tier : null,
      size: 52,
      childSize: 42,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: reached ? _tierGradient(tier, alpha: 0.85) : null, color: reached ? null : theme.bgCardAlt),
        alignment: Alignment.center,
        child: reached
            ? Text(toFaDigits(tier.index), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))
            : Icon(Icons.lock_rounded, size: 16, color: theme.textFaint),
      ),
    );
    if (isCurrent) {
      badge = badge.animate(onPlay: (ctl) => ctl.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 1100.ms);
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 58,
          child: Column(children: [
            badge,
            if (!isLast)
              Expanded(
                child: Container(
                  width: 3,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: reached ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c, c.withValues(alpha: 0.3)]) : null,
                    color: reached ? null : theme.glassBorder,
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            decoration: BoxDecoration(
              color: isCurrent ? c.withValues(alpha: 0.12) : theme.bgCard.withValues(alpha: reached ? 0.7 : 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isCurrent ? c.withValues(alpha: 0.6) : theme.glassBorder, width: isCurrent ? 1.4 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(tier.title, style: TextStyle(color: reached ? c : theme.textSecondary, fontSize: 14, fontWeight: FontWeight.w900)),
                if (tier.crownStyle != DonorCrownStyle.none) ...[const SizedBox(width: 5), Icon(Icons.emoji_events_rounded, size: 14, color: c)],
                const Spacer(),
                if (isCurrent)
                  _MiniChip(theme: theme, text: 'شما این‌جایید', color: c)
                else if (reached)
                  Icon(Icons.check_circle_rounded, size: 17, color: theme.success)
                else
                  Text('${faNum(tier.minXp - xp)} امتیاز مانده', style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
              ]),
              const SizedBox(height: 4),
              Text(tier.minXp == 0 ? 'از همان روز نخست' : 'از ${faNum(tier.minXp)} امتیاز', style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
              const SizedBox(height: 4),
              Text(rankPerkLabel(tier), style: TextStyle(color: reached ? theme.textSecondary : theme.textFaint, fontSize: 11.5, height: 1.6)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Leaders extends StatelessWidget {
  final AppColors theme;
  const _Leaders({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final list = app.rankLeaderboard.where((e) => e.role != 'admin').toList();
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Center(child: Text('جدول برترین‌ها در حال بارگذاری است…', style: TextStyle(color: theme.textFaint, fontSize: 12))),
      );
    }
    final top = list.take(3).toList();
    final rest = list.skip(3).take(17).toList();
    final meId = app.currentUser?.id;
    final meIndex = list.indexWhere((e) => e.userId == meId);
    return Column(children: [
      if (top.isNotEmpty)
        SizedBox(
          height: 210,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (top.length > 1) Expanded(child: _Podium(theme: theme, e: top[1], place: 2, height: 96)),
            Expanded(child: _Podium(theme: theme, e: top[0], place: 1, height: 128)),
            if (top.length > 2) Expanded(child: _Podium(theme: theme, e: top[2], place: 3, height: 76)),
          ]),
        ),
      const SizedBox(height: 12),
      for (final (i, e) in rest.indexed) _LeaderRow(theme: theme, e: e, place: i + 4, isMe: e.userId == meId).animate().fadeIn(delay: (30 * i).ms, duration: 250.ms),
      if (meIndex >= 20) ...[
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Icon(Icons.more_horiz_rounded, color: theme.textFaint)),
        _LeaderRow(theme: theme, e: list[meIndex], place: meIndex + 1, isMe: true),
      ],
    ]);
  }
}

class _Podium extends StatelessWidget {
  final AppColors theme;
  final RankEntry e;
  final int place;
  final double height;
  const _Podium({required this.theme, required this.e, required this.place, required this.height});

  @override
  Widget build(BuildContext context) {
    final tier = rankTierForXp(e.xp);
    final medal = [const Color(0xFFFFC94D), const Color(0xFFD7DEE8), const Color(0xFFE59A5B)][place - 1];
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      if (place == 1) const Text('👑', style: TextStyle(fontSize: 20)),
      DonorRing(
        theme: theme,
        tier: tier,
        size: place == 1 ? 66 : 54,
        childSize: place == 1 ? 56 : 46,
        child: HzBadge(theme: theme, size: place == 1 ? 56 : 46, filled: true, avatarPath: e.avatarPath, child: Text(e.name.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
      ),
      const SizedBox(height: 5),
      Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w800)),
      Text(faNum(e.xp), style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
      const SizedBox(height: 5),
      Container(
        height: height - 40,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [medal.withValues(alpha: 0.75), medal.withValues(alpha: 0.12)]),
        ),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 6),
        child: Text(toFaDigits(place), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
      ),
    ]).animate().fadeIn(delay: (120 * place).ms, duration: 400.ms).slideY(begin: 0.2, end: 0);
  }
}

class _LeaderRow extends StatelessWidget {
  final AppColors theme;
  final RankEntry e;
  final int place;
  final bool isMe;
  const _LeaderRow({required this.theme, required this.e, required this.place, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final tier = rankTierForXp(e.xp);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: isMe ? theme.blue.withValues(alpha: 0.14) : theme.bgCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isMe ? theme.blue.withValues(alpha: 0.5) : theme.glassBorder),
      ),
      child: Row(children: [
        SizedBox(width: 26, child: Text(toFaDigits(place), style: TextStyle(color: theme.textFaint, fontSize: 13, fontWeight: FontWeight.w900))),
        DonorRing(
          theme: theme,
          tier: tier,
          size: 40,
          childSize: 33,
          child: HzBadge(theme: theme, size: 33, filled: true, avatarPath: e.avatarPath, child: Text(e.name.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isMe ? '${e.name} (شما)' : e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
            Text(tier.title, style: TextStyle(color: tier.colors.first, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        Text(faNum(e.xp), style: TextStyle(color: theme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

// =====================================================================
// جشن رسیدن به مقام تازه
// =====================================================================
Future<void> showLevelUpCelebration(BuildContext context, DonorTier tier) {
  final theme = context.read<AppState>().colors;
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'level-up',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (ctx, _, __) => Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            const Positioned.fill(child: IgnorePointer(child: _Confetti())),
            Container(
              width: 320,
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
              decoration: BoxDecoration(
                color: theme.bgElevated,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: tier.colors.first.withValues(alpha: 0.7), width: 1.4),
                boxShadow: [BoxShadow(color: tier.colors.first.withValues(alpha: 0.45), blurRadius: 50)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('مقام تازه!', style: TextStyle(color: theme.textFaint, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                Stack(alignment: Alignment.center, children: [
                  _Rays(color: tier.colors.first),
                  DonorRing(
                    theme: theme,
                    tier: tier,
                    size: 110,
                    childSize: 90,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: _tierGradient(tier)),
                      alignment: Alignment.center,
                      child: Text(toFaDigits(tier.index), style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ]).animate().scale(begin: const Offset(0.3, 0.3), end: const Offset(1, 1), duration: 700.ms, curve: Curves.elasticOut),
                const SizedBox(height: 12),
                Text('تبریک! 🎉', style: TextStyle(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                ShaderMask(
                  shaderCallback: (r) => _tierGradient(tier).createShader(r),
                  child: Text('به مقام «${tier.title}» رسیدید', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 1800.ms, color: Colors.white54),
                const SizedBox(height: 10),
                Text('تازه باز شد: ${rankPerkLabel(tier)}', textAlign: TextAlign.center, style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.8)),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(foregroundColor: theme.textSecondary, side: BorderSide(color: theme.glassBorder), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Text('عالی!', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(RankScreen.route());
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: tier.colors.first, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Text('دیدن مقام', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    ),
    transitionBuilder: (_, a, __, child) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: FadeTransition(opacity: a, child: child)),
  );
}

class _Confetti extends StatefulWidget {
  const _Confetti();
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  final _rnd = math.Random(7);
  late final List<(double, double, double, Color, double)> _bits = List.generate(46, (i) {
    const colors = [Color(0xFFFFC94D), Color(0xFFFF6FA8), Color(0xFF6BC8FF), Color(0xFF6BFFB3), Color(0xFFA06BFF), Colors.white];
    return (_rnd.nextDouble() * 2 - 1, _rnd.nextDouble() * 0.6 + 0.4, _rnd.nextDouble() * 6.28, colors[i % colors.length], _rnd.nextDouble() * 5 + 4);
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(size: const Size(360, 560), painter: _ConfettiPainter(_c.value, _bits)),
      );
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  final List<(double, double, double, Color, double)> bits;
  _ConfettiPainter(this.t, this.bits);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final e = Curves.easeOut.transform(t);
    for (final (dx, speed, rot, color, s) in bits) {
      final x = c.dx + dx * size.width * 0.55 * e;
      final y = c.dy - size.height * 0.45 * speed * math.sin(e * math.pi * 0.9) + size.height * 0.35 * t * t;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot + t * 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: s, height: s * 0.5), const Radius.circular(1.5)),
        Paint()..color = color.withValues(alpha: (1 - t).clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

/// این ویجت را دور بدنه‌ی اصلی اپ می‌گذاریم تا هر وقت کاربر به مقام تازه‌ای
/// رسید، جشن خودکار نمایش داده شود.
class LevelUpListener extends StatefulWidget {
  final Widget child;
  const LevelUpListener({super.key, required this.child});
  @override
  State<LevelUpListener> createState() => _LevelUpListenerState();
}

class _LevelUpListenerState extends State<LevelUpListener> {
  bool _showing = false;

  @override
  Widget build(BuildContext context) {
    final tier = context.select<AppState, DonorTier?>((a) => a.pendingLevelUp);
    if (tier != null && !_showing) {
      _showing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        context.read<AppState>().clearLevelUp();
        await showLevelUpCelebration(context, tier);
        _showing = false;
      });
    }
    return widget.child;
  }
}
