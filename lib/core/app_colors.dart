import 'package:flutter/material.dart';

/// رنگ‌ها و توکن‌های طراحی هزاره‌نامه — نسخه‌ی «شیشه‌ای مدرن» (Glassmorphism).
/// همان اسکلت قبلی (بازمانده از دموی وب) حفظ شده تا هیچ صفحه‌ای نشکند، اما
/// مقادیر پررنگ‌تر و چندلایه‌تر شده‌اند و چند توکن تازه برای سطوح شیشه‌ای و
/// پس‌زمینه‌ی متحرک اضافه شده — [glassTint]، [glassBorder]، [glassSheenAlpha]،
/// [meshColors].
class AppColors {
  final Color bg;
  final Color bgElevated;
  final Color bgCard;
  final Color bgCardAlt;
  final Color border;
  final Color blue;
  final Color blueDeep;
  final Color blueSoft;
  final Color yellow;
  final Color yellowSoft;
  final Color white;
  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;
  final Color danger;
  final Color success;

  // --- هویت بصری هوش مصنوعی ---
  final Color aiViolet; // رنگ اصلی هویت بصری «دستیار هوشمند»
  final Color aiTeal; // رنگ دوم گرادیان‌های هوش مصنوعی
  final Color glassOverlay; // پوشش نیمه‌شفاف عمومی برای لایه‌های شیشه‌ای

  // --- توکن‌های تازه‌ی سیستم شیشه‌ای (Glassmorphism) ---
  final Color glassTint; // رنگ پایه‌ی پرشدگی پنل‌های شیشه‌ای
  final Color glassBorder; // خط لبه‌ی روشن روی هر پنل شیشه‌ای
  final double glassSheenAlpha; // شدت درخشش مورب بالای هر کارت شیشه‌ای
  final List<Color> meshColors; // رنگ‌های بلوب‌های شناور پس‌زمینه‌ی متحرک

  const AppColors({
    required this.bg,
    required this.bgElevated,
    required this.bgCard,
    required this.bgCardAlt,
    required this.border,
    required this.blue,
    required this.blueDeep,
    required this.blueSoft,
    required this.yellow,
    required this.yellowSoft,
    required this.white,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.danger,
    required this.success,
    required this.aiViolet,
    required this.aiTeal,
    required this.glassOverlay,
    required this.glassTint,
    required this.glassBorder,
    required this.glassSheenAlpha,
    required this.meshColors,
  });

  /// گرادیان هویتی هوش مصنوعی — روی دکمه‌ها، FAB و هدرهای دستیار استفاده می‌شود.
  LinearGradient get aiGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [aiViolet, aiTeal],
      );

  /// گرادیان هویتی برند — آبی عمیق تا زرد، برای هدرهای قهرمان (hero) صفحه‌ی خانه.
  LinearGradient get heroGradient => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [blueDeep, blue, yellow],
      );

  /// درخشش موربِ بالای هر پنل شیشه‌ای — با BackdropFilter ترکیب می‌شود تا
  /// حس واقعی شیشه‌ی نورخورده بدهد.
  LinearGradient get glassSheen => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withValues(alpha: glassSheenAlpha), Colors.white.withValues(alpha: 0)],
      );

  /// گرادیان چندرنگِ پس‌زمینه‌ی سراسری — پایه‌ی [AnimatedBackdrop].
  LinearGradient get meshBaseGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [bg, bgElevated, bg],
      );

  /// همان تم با رنگ تأکیدی دیگر — صفحه‌ی هر بخش با رنگ هویتی همان بخش رنگ می‌گیرد.
  AppColors withAccent(Color accent) => AppColors(
        bg: bg,
        bgElevated: bgElevated,
        bgCard: bgCard,
        bgCardAlt: bgCardAlt,
        border: border,
        blue: accent,
        blueDeep: blueDeep,
        blueSoft: blueSoft,
        yellow: yellow,
        yellowSoft: yellowSoft,
        white: white,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        textFaint: textFaint,
        danger: danger,
        success: success,
        aiViolet: aiViolet,
        aiTeal: aiTeal,
        glassOverlay: glassOverlay,
        glassTint: glassTint,
        glassBorder: glassBorder,
        glassSheenAlpha: glassSheenAlpha,
        meshColors: meshColors,
      );

  static const dark = AppColors(
    bg: Color(0xFF05070F),
    bgElevated: Color(0xFF0D1226),
    bgCard: Color(0xFF161B33),
    bgCardAlt: Color(0xFF1C2340),
    border: Color(0xFF2C3559),
    blue: Color(0xFF5B93FF),
    blueDeep: Color(0xFF223A85),
    blueSoft: Color(0xFFA7C3FF),
    yellow: Color(0xFFFFC94D),
    yellowSoft: Color(0xFFFFE096),
    white: Color(0xFFF7F9FF),
    textPrimary: Color(0xFFF5F7FF),
    textSecondary: Color(0xFFA9B3D6),
    textFaint: Color(0xFF7D86B0),
    danger: Color(0xFFFF6B85),
    success: Color(0xFF4EDBA0),
    aiViolet: Color(0xFFA06BFF),
    aiTeal: Color(0xFF2FE3D6),
    glassOverlay: Color(0x24FFFFFF),
    glassTint: Color(0x33161B33),
    glassBorder: Color(0x33FFFFFF),
    glassSheenAlpha: 0.10,
    meshColors: [Color(0xFF223A85), Color(0xFFA06BFF), Color(0xFFFFC94D), Color(0xFF2FE3D6)],
  );

  static const light = AppColors(
    bg: Color(0xFFEFF3FC),
    bgElevated: Color(0xFFFFFFFF),
    bgCard: Color(0xFFFFFFFF),
    bgCardAlt: Color(0xFFF4F7FD),
    border: Color(0xFFDCE4F4),
    blue: Color(0xFF2159C4),
    blueDeep: Color(0xFF163C87),
    blueSoft: Color(0xFF6F97DE),
    yellow: Color(0xFFC98A0A),
    yellowSoft: Color(0xFFE6AE3E),
    white: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0D1730),
    textSecondary: Color(0xFF4A5578),
    textFaint: Color(0xFF8792B3),
    danger: Color(0xFFD3435E),
    success: Color(0xFF1E9463),
    aiViolet: Color(0xFF7A4CE0),
    aiTeal: Color(0xFF0BA69E),
    glassOverlay: Color(0x1A0D1730),
    glassTint: Color(0xB3FFFFFF),
    glassBorder: Color(0xFFDCE4F4),
    glassSheenAlpha: 0.55,
    meshColors: [Color(0xFFBFD3FF), Color(0xFFD8C6FF), Color(0xFFFFE3A8), Color(0xFFB8F0E8)],
  );
}
