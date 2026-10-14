import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/afghan_calendar.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/donor_tiers.dart';
import '../../core/section_style.dart';
import '../../core/widgets.dart';
import '../../data/sections.dart';
import '../../state/app_state.dart';
import '../ai/ai_recommend_widget.dart';
import 'story_carousel.dart';
import 'donation_home_card.dart';
import 'section_card.dart';
import '../rank/rank_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenExplore;
  final void Function(String sectionId) onOpenSection;
  final VoidCallback? onOpenProfile;
  const HomeScreen({super.key, required this.onOpenExplore, required this.onOpenSection, this.onOpenProfile});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final sections = kSections.where((s) => s.id != 'dailyStory').toList();
    final quickAccess = sections.toList();
    final hero = sections.first;
    final rest = sections.skip(1).toList();
    int countOf(String id) => app.sectionItemCount(id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
      children: [
        _Greeting(theme: theme, app: app, onTap: onOpenProfile).animate().fadeIn(duration: 380.ms).slideY(begin: -0.06, end: 0),
        const SizedBox(height: 14),
        RankCard(theme: theme).animate(delay: 80.ms).fadeIn(duration: 380.ms).slideY(begin: 0.06, end: 0),
        const SizedBox(height: 16),
        StoryCarousel(theme: theme),
        const SizedBox(height: 22),
        _SectionTitle(theme: theme, title: 'دسترسی سریع'),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: quickAccess.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final s = quickAccess[i];
              final st = sectionStyle(s.id);
              return SizedBox(
                width: 68,
                child: Pressable(
                  onTap: () => onOpenSection(s.id),
                  child: Column(children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: st.gradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: st.a.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
                      ),
                      child: Icon(st.icon, color: Colors.white, size: 25),
                    ),
                    const SizedBox(height: 7),
                    Text(sectionShortTitle(s),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.textSecondary, fontSize: 11, height: 1.3, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ).staggered(i);
            },
          ),
        ),
        const SizedBox(height: 18),
        AiRecommendSection(onOpenSection: onOpenSection),
        DonationHomeCard(theme: theme),
        const SizedBox(height: 26),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('بخش‌های هزاره‌نامه', style: TextStyle(color: theme.textPrimary, fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('${toFaDigits(sections.length)} دروازه به سوی یک هویت', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
            ]),
          ),
          TextButton.icon(
            onPressed: onOpenExplore,
            icon: Icon(Icons.arrow_back_rounded, size: 16, color: theme.blue),
            label: Text('دیدن همه', style: TextStyle(color: theme.blue, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 170,
          child: SectionCard(theme: theme, section: hero, wide: true, count: countOf(hero.id), onTap: () => onOpenSection(hero.id)),
        ).staggered(0),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: rest.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.0),
          itemBuilder: (context, i) => SectionCard(theme: theme, section: rest[i], count: countOf(rest[i].id), onTap: () => onOpenSection(rest[i].id)).staggered(i + 1),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final AppColors theme;
  final String title;
  const _SectionTitle({required this.theme, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 4, height: 16, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [theme.blue, theme.aiViolet]), borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
    ]);
  }
}

/// سلام فشرده‌ی بالای خانه — آواتار با حلقه‌ی حامی، نام، و تاریخ خورشیدی امروز.
class _Greeting extends StatelessWidget {
  final AppColors theme;
  final AppState app;
  final VoidCallback? onTap;
  const _Greeting({required this.theme, required this.app, this.onTap});

  String get _salutation {
    final h = DateTime.now().hour;
    if (h < 5) return 'شب بخیر';
    if (h < 12) return 'صبح بخیر';
    if (h < 17) return 'روز بخیر';
    if (h < 21) return 'عصر بخیر';
    return 'شب بخیر';
  }

  @override
  Widget build(BuildContext context) {
    final name = app.displayName.trim();
    final first = name.isEmpty ? 'همسفر' : name.split(' ').first;
    final tier = app.myRankTier;

    return Pressable(
      onTap: onTap,
      child: Row(children: [
        DonorRing(
          theme: theme,
          tier: tier,
          size: 56,
          childSize: 46,
          child: HzBadge(
            theme: theme,
            size: 46,
            filled: true,
            avatarPath: app.avatarPath,
            child: Text(name.isNotEmpty ? name[0] : 'ه', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$_salutation، $first', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.calendar_today_rounded, size: 12, color: theme.textFaint),
              const SizedBox(width: 5),
              Text(afghanDateLabel(DateTime.now()), style: TextStyle(color: theme.textSecondary, fontSize: 12)),
            ]),
          ]),
        ),
      ]),
    );
  }
}
