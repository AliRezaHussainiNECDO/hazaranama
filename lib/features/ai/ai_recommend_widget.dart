import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets.dart';
import '../../core/app_logo.dart';
import '../../core/app_colors.dart';
import '../../data/sections.dart';
import '../../state/app_state.dart';
import '../../services/ai_service.dart';
import '../home/section_card.dart';

/// بخش «پیشنهاد هوشمند برای تو» در صفحه‌ی خانه — بر اساس پروفایل کاربر
/// (طایفه، ولایت خاستگاه، زبان مادری)، دستیار هوشمند سه بخش مرتبط را
/// پیشنهاد می‌دهد. اگر هوش مصنوعی در دسترس نباشد، این بخش بی‌سروصدا پنهان می‌شود
/// و هیچ خطایی به کاربر نشان نمی‌دهد — چون این یک ویژگی جانبی است، نه اصلی.
class AiRecommendSection extends StatefulWidget {
  final void Function(String sectionId) onOpenSection;
  const AiRecommendSection({super.key, required this.onOpenSection});

  @override
  State<AiRecommendSection> createState() => _AiRecommendSectionState();
}

class _AiRecommendSectionState extends State<AiRecommendSection> {
  final _ai = AiService();
  bool _loading = true;
  bool _failed = false;
  List<AiSectionPick> _picks = [];
  String? _loadedForUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppState>();
    final userId = app.currentUser?.id;
    if (userId != null && userId != _loadedForUserId) {
      _loadedForUserId = userId;
      _load(app);
    }
  }

  Future<void> _load(AppState app) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final profile = app.currentUser;
    if (profile == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    try {
      final sections = kSections
          .where((s) => s.id != 'oral' && s.id != 'dailyStory')
          .map((s) => {'id': s.id, 'title': s.title, 'description': s.description})
          .toList();
      final picks = await _ai.recommend(profile: {
        'tribe': profile.tribe,
        'originProvince': profile.originProvince,
        'nativeLanguage': profile.nativeLanguage,
        'bio': profile.bio,
      }, sections: sections);
      if (mounted) {
        setState(() {
          _picks = picks;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().colors;
    if (_failed || (!_loading && _picks.isEmpty)) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.auto_awesome, size: 14, color: theme.aiViolet),
        const SizedBox(width: 6),
        Text('پیشنهاد هوشمند برای تو', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 3),
      Text('بر اساس پروفایل تو، این‌ها را دوست خواهی داشت', style: TextStyle(color: theme.textFaint, fontSize: 12)),
      const SizedBox(height: 10),
      SizedBox(
        height: 108,
        child: _loading
            ? ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _SkeletonCard(theme: theme),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _picks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final pick = _picks[i];
                  final section = sectionById(pick.sectionId);
                  return Pressable(
                    onTap: () => widget.onOpenSection(pick.sectionId),
                    child: Container(
                      width: 170,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [theme.aiViolet.withValues(alpha: 0.14), theme.aiTeal.withValues(alpha: 0.10)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.aiViolet.withValues(alpha: 0.25)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        StatIconBox(icon: iconForSection(section.id), color: theme.aiViolet, size: 30),
                        const Spacer(),
                        Text(section.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(pick.reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 11, height: 1.3)),
                      ]),
                    ),
                  ).staggered(i);
                },
              ),
      ),
      const SizedBox(height: 22),
    ]);
  }
}

class _SkeletonCard extends StatelessWidget {
  final AppColors theme;
  const _SkeletonCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.5, end: 1, duration: 700.ms);
  }
}
