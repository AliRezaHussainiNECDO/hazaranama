import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/widgets.dart';
import '../../core/section_style.dart';
import '../../state/app_state.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bg,
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme)),
          SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(app.isDark ? Icons.light_mode : Icons.dark_mode, color: app.isDark ? theme.yellow : theme.blue),
                onPressed: () => app.toggleTheme(),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(children: [
                  const SizedBox(height: 8),
                  // لوگوی بزرگ و متحرک برنامه
                  const AnimatedAppLogo(size: 132),
                  const SizedBox(height: 22),
                  Text('هزاره‌نامه', style: TextStyle(color: theme.textPrimary, fontSize: 27, fontWeight: FontWeight.w800))
                      .animate(delay: 250.ms).fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0),
                  const SizedBox(height: 6),
                  Text('روایت زنده‌ی هویت ما', style: TextStyle(color: theme.blue, fontSize: 13, fontWeight: FontWeight.w600))
                      .animate(delay: 340.ms).fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0),
                  const SizedBox(height: 14),
                  const FlagStripe(width: 70).animate(delay: 420.ms).fadeIn(duration: 350.ms).scaleX(begin: 0.3, end: 1),
                  const SizedBox(height: 14),
                  Text(
                    'مرجعی دیجیتال برای شناخت، حفظ و گرامی‌داشت تاریخ، فرهنگ و زندگی مردم هزاره — از هویت تا حافظه‌ی جمعی نسل‌ها.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 2),
                  ).animate(delay: 500.ms).fadeIn(duration: 450.ms).slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 26),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.75,
                    children: [
                      _Feature(theme: theme, sectionId: 'identity', label: 'تاریخ و هویت', sub: '۱۳ فصل مستند', delay: 600),
                      _Feature(theme: theme, sectionId: 'culture', label: 'فرهنگ و هنر', sub: 'آیین‌ها، موسیقی، شعر', delay: 660),
                      _Feature(theme: theme, sectionId: 'language', label: 'زبان هزارگی', sub: 'واژه‌نامه‌ی زنده', delay: 720),
                      _Feature(theme: theme, sectionId: 'oral', label: 'حافظه‌ی جمعی', sub: 'روایت‌های شما', delay: 780),
                    ],
                  ),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(children: [
                HzPrimaryButton(theme: theme, label: 'ورود به حساب', onPressed: () => app.goTo(AuthStage.login))
                    .animate(delay: 800.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 10),
                HzSecondaryButton(theme: theme, label: 'ساخت حساب تازه', onPressed: () => app.goTo(AuthStage.register))
                    .animate(delay: 860.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
              ]),
            ),
          ]),
          ),
        ]),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final AppColors theme;
  final String sectionId;
  final String label;
  final String sub;
  final int delay;
  const _Feature({required this.theme, required this.sectionId, required this.label, required this.sub, required this.delay});

  @override
  Widget build(BuildContext context) {
    final st = sectionStyle(sectionId);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.bgCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: st.a.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(gradient: st.gradient, borderRadius: BorderRadius.circular(13)),
          child: Icon(st.icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
          ]),
        ),
      ]),
    ).animate(delay: delay.ms).fadeIn(duration: 380.ms).slideY(begin: 0.15, end: 0);
  }
}
