import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/widgets.dart';
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Feature(theme: theme, icon: Icons.account_balance, label: 'تاریخ و هویت', delay: 600),
                      const SizedBox(width: 20),
                      _Feature(theme: theme, icon: Icons.auto_awesome, label: 'فرهنگ و هنر', delay: 660),
                      const SizedBox(width: 20),
                      _Feature(theme: theme, icon: Icons.forum, label: 'حافظه جمعی', delay: 720),
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
  final IconData icon;
  final String label;
  final int delay;
  const _Feature({required this.theme, required this.icon, required this.label, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      HzBadge(theme: theme, size: 44, child: Icon(icon, color: theme.blue, size: 18)),
      const SizedBox(height: 7),
      Text(label, style: TextStyle(fontSize: 10, color: theme.textFaint)),
    ]).animate(delay: Duration(milliseconds: delay)).fadeIn(duration: 350.ms).scale(begin: const Offset(0.7, 0.7));
  }
}
