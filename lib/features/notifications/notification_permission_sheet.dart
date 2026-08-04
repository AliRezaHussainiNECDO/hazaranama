import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/app_colors.dart';
import '../../core/widgets.dart';

/// کارت دوستانه‌ی درخواست اجازه‌ی اعلان — پیش از این‌که پنجره‌ی رسمی
/// سیستم‌عامل (iOS/اندروید) ناگهان ظاهر شود، به کاربر توضیح می‌دهد چرا این
/// اجازه لازم است و با آگاهی خودش تصمیم می‌گیرد. این دقیقاً همان الگویی است
/// که اپ‌استور و پلی‌استور برای گرفتن دسترسی‌های حساس توصیه می‌کنند: هرگز
/// بدون زمینه و توضیح از کاربر دسترسی نخواهید.
class NotificationPermissionSheet extends StatelessWidget {
  final AppColors theme;
  final VoidCallback onAllow;
  final VoidCallback onDecline;
  const NotificationPermissionSheet({super.key, required this.theme, required this.onAllow, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [theme.bgElevated.withValues(alpha: 0.98), theme.bgCard.withValues(alpha: 0.96)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.blue.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.32), blurRadius: 28, offset: const Offset(0, 12))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          StatIconBox(icon: Icons.notifications_active_rounded, color: theme.blue, size: 52)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1, end: 1.08, duration: 1100.ms, curve: Curves.easeInOut),
          const SizedBox(height: 14),
          Text('اجازه‌ی نمایش اعلان', textAlign: TextAlign.center, style: TextStyle(color: theme.textPrimary, fontSize: 15.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'با فعال کردن اعلان، همان لحظه از پاسخ نظرات، وضعیت مقاله‌ی مسابقه و تأیید کمک مالی‌تان باخبر می‌شوید — حتی وقتی اپ بسته است.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.7),
          ),
          const SizedBox(height: 18),
          HzPrimaryButton(label: 'اجازه می‌دهم', icon: Icons.check_rounded, theme: theme, onPressed: onAllow),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onDecline,
            child: Text('شاید بعداً', style: TextStyle(color: theme.textFaint, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.25, end: 0, duration: 460.ms, curve: Curves.easeOutBack);
  }
}
