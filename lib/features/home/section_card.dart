import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';

/// نگاشت شناسه‌ی بخش به آیکون متریال — معادل آیکون‌های lucide-react در وب.
const Map<String, IconData> kSectionIcons = {
  'identity': Icons.account_balance,
  'figures': Icons.groups,
  'genocide': Icons.history_edu,
  'culture': Icons.auto_awesome,
  'music': Icons.music_note,
  'language': Icons.translate,
  'map': Icons.map,
  'album': Icons.image,
  'news': Icons.newspaper,
  'library': Icons.menu_book,
  'oral': Icons.mic,
  'dailyStory': Icons.auto_awesome,
  'articleWinners': Icons.emoji_events,
};

IconData iconForSection(String id) => kSectionIcons[id] ?? Icons.circle;

class SectionCard extends StatelessWidget {
  final AppColors theme;
  final ContentSection section;
  final VoidCallback onTap;
  const SectionCard({super.key, required this.theme, required this.section, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HzGlassCard(
      theme: theme,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(13, 15, 13, 13),
      onTap: onTap,
      blur: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const FlagStripe(height: 3, radius: 2),
        const SizedBox(height: 9),
        StatIconBox(icon: iconForSection(section.id), color: theme.blue, size: 34),
        const SizedBox(height: 10),
        Text(section.title, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(section.description, style: TextStyle(color: theme.textFaint, fontSize: 10, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
