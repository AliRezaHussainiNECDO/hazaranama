import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/afghan_calendar.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/section_style.dart';
import '../../data/sections.dart';
import '../../state/app_state.dart';
import '../home/section_card.dart';

const Map<String, IconData> _groupIcons = {
  'history': Icons.history_edu_rounded,
  'culture': Icons.palette_rounded,
  'resources': Icons.inventory_2_rounded,
};

class ExploreScreen extends StatelessWidget {
  final void Function(String sectionId) onOpenSection;
  const ExploreScreen({super.key, required this.onOpenSection});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final visible = kSections.where((s) => kGroupOrder.contains(s.group)).toList();
    final totalItems = app.content.entries.where((e) => e.key != 'dailyStory').fold<int>(0, (n, e) => n + e.value.length);
    int countOf(String id) => id == 'music' ? app.artists.length : (app.content[id]?.length ?? 0) + (id == 'language' ? kHazaragiGlossaryCount : 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
      children: [
        _ExploreHero(theme: theme, sections: visible.length, items: totalItems).animate().fadeIn(duration: 380.ms).slideY(begin: -0.05, end: 0),
        const SizedBox(height: 22),
        for (final group in kGroupOrder) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Icon(_groupIcons[group] ?? Icons.circle, size: 18, color: theme.yellow),
              const SizedBox(width: 8),
              Text(kGroupLabel[group]!, style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: theme.glassBorder)),
            ]),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: kSections.where((s) => s.group == group).length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.0),
            itemBuilder: (context, i) {
              final s = kSections.where((s) => s.group == group).toList()[i];
              return SectionCard(theme: theme, section: s, count: countOf(s.id), onTap: () => onOpenSection(s.id)).staggered(i);
            },
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _ExploreHero extends StatelessWidget {
  final AppColors theme;
  final int sections;
  final int items;
  const _ExploreHero({required this.theme, required this.sections, required this.items});

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5)),
          ]),
        );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [theme.blueDeep, theme.blue, theme.aiViolet]),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: theme.blue.withValues(alpha: 0.3), blurRadius: 26, offset: const Offset(0, 12))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        PositionedDirectional(
          end: -30,
          top: -30,
          child: Icon(Icons.explore_rounded, size: 170, color: Colors.white.withValues(alpha: 0.08)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('کاوش در هزاره‌نامه', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('تاریخ، فرهنگ، زبان و حافظه‌ی مردم هزاره — در یک‌جا', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5, height: 1.5)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                stat(toFaDigits(sections), 'بخش'),
                Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.2)),
                stat(toFaDigits(items), 'مطلب مستند'),
                Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.2)),
                stat(toFaDigits(kGroupOrder.length), 'دسته'),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
