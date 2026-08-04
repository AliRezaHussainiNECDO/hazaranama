import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets.dart';
import '../../core/app_logo.dart';
import '../../data/sections.dart';
import '../../state/app_state.dart';
import '../ai/ai_recommend_widget.dart';
import 'profile_header.dart';
import 'story_carousel.dart';
import 'donation_home_card.dart';
import 'section_card.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenExplore;
  final void Function(String sectionId) onOpenSection;
  const HomeScreen({super.key, required this.onOpenExplore, required this.onOpenSection});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final quickAccess = kSections.where((s) => s.id != 'dailyStory').take(6).toList();
    final gridSections = kSections.where((s) => s.id != 'dailyStory').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        const ProfileHeader().animate().fadeIn(duration: 380.ms).slideY(begin: -0.04, end: 0),
        Text('سلام، همسفر', style: TextStyle(color: theme.textFaint, fontSize: 12.5)).animate(delay: 80.ms).fadeIn(duration: 350.ms),
        const SizedBox(height: 10),
        StoryCarousel(theme: theme),
        const SizedBox(height: 12),
        DonationHomeCard(theme: theme),
        const SizedBox(height: 22),
        Text('دسترسی سریع', style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: quickAccess.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final s = quickAccess[i];
              return SizedBox(
                width: 60,
                child: InkWell(
                  onTap: () => onOpenSection(s.id),
                  child: Column(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(color: theme.blue.withValues(alpha: 0.09), shape: BoxShape.circle, border: Border.all(color: theme.blue.withValues(alpha: 0.27))),
                      child: Icon(iconForSection(s.id), color: theme.blue, size: 19),
                    ),
                    const SizedBox(height: 7),
                    Text(s.title.split(' ').take(2).join(' '), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 10, height: 1.3)),
                  ]),
                ),
              ).staggered(i);
            },
          ),
        ),
        const SizedBox(height: 22),
        AiRecommendSection(onOpenSection: onOpenSection),
        Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('بخش‌های هزاره‌نامه', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('یازده دروازه به سوی یک هویت', style: TextStyle(color: theme.textFaint, fontSize: 11)),
          ]),
          TextButton(onPressed: onOpenExplore, child: Text('دیدن همه', style: TextStyle(color: theme.blue, fontSize: 11.5, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 6),
        const FlagStripe(),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gridSections.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 11, crossAxisSpacing: 11, childAspectRatio: 0.92),
          itemBuilder: (context, i) => SectionCard(theme: theme, section: gridSections[i], onTap: () => onOpenSection(gridSections[i].id)).staggered(i),
        ),
      ],
    );
  }
}
