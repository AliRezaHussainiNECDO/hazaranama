import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/section_style.dart';
import '../../models/models.dart';

IconData iconForSection(String id) => sectionStyle(id).icon;

/// کارت «دروازه»ی هر بخش — رنگ و آیکون اختصاصی بخش، آیکون بزرگ محو در
/// پس‌زمینه، شمار مطالب و توضیح کوتاه؛ با فشردن کمی کوچک می‌شود.
class SectionCard extends StatelessWidget {
  final AppColors theme;
  final ContentSection section;
  final VoidCallback onTap;
  final int count;
  final bool wide;
  const SectionCard({super.key, required this.theme, required this.section, required this.onTap, this.count = 0, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final st = sectionStyle(section.id);
    final countLabel = sectionCountLabel(section, count);

    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: st.a.withValues(alpha: 0.28)),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color.alphaBlend(st.a.withValues(alpha: 0.16), theme.bgCard.withValues(alpha: 0.9)),
              theme.bgCard.withValues(alpha: 0.72),
            ],
          ),
          boxShadow: [BoxShadow(color: st.a.withValues(alpha: 0.12), blurRadius: 22, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            // آیکون بزرگ و محو — واترمارک هویتی بخش
            PositionedDirectional(
              end: -18,
              bottom: -22,
              child: Transform.rotate(
                angle: -0.18,
                child: Icon(st.icon, size: wide ? 130 : 104, color: st.a.withValues(alpha: 0.09)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: st.gradient,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: st.a.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))],
                    ),
                    child: Icon(st.icon, color: Colors.white, size: 23),
                  ),
                  const Spacer(),
                  if (countLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: st.a.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: st.a.withValues(alpha: 0.3)),
                      ),
                      child: Text(countLabel, style: TextStyle(color: theme.textPrimary, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ),
                ]),
                const Spacer(),
                Text(section.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.textPrimary, fontSize: wide ? 17 : 14.5, fontWeight: FontWeight.w800, height: 1.35)),
                const SizedBox(height: 4),
                Text(section.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.textSecondary, fontSize: 11.5, height: 1.5)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
