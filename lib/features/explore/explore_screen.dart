import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_logo.dart';
import '../../data/sections.dart';
import '../../state/app_state.dart';
import '../home/section_card.dart';

class ExploreScreen extends StatelessWidget {
  final void Function(String sectionId) onOpenSection;
  const ExploreScreen({super.key, required this.onOpenSection});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        Text('بخش‌های هزاره‌نامه', style: TextStyle(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('یازده دروازه به سوی یک هویت', style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
        const SizedBox(height: 16),
        for (final group in kGroupOrder) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: theme.yellow, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(kGroupLabel[group]!, style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kSections.where((s) => s.group == group).length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 11, crossAxisSpacing: 11, childAspectRatio: 0.92),
            itemBuilder: (context, i) {
              final s = kSections.where((s) => s.group == group).toList()[i];
              return SectionCard(theme: theme, section: s, onTap: () => onOpenSection(s.id)).staggered(i);
            },
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
