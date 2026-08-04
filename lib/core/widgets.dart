import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import 'app_colors.dart';
import 'app_logo.dart';

/// آواتار دایره‌ای — معادل کامپوننت Badge در دموی وب.
/// اگر avatarPath داده شود، عکس واقعی را نمایش می‌دهد؛ در غیر این صورت child
/// (مثلاً حرف اول نام یا یک آیکون) را در پس‌زمینه‌ی رنگی نشان می‌دهد.
class HzBadge extends StatelessWidget {
  final Widget child;
  final double size;
  final AppColors theme;
  final bool filled;
  final String? avatarPath;

  const HzBadge({
    super.key,
    required this.child,
    required this.theme,
    this.size = 42,
    this.filled = false,
    this.avatarPath,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarPath != null && avatarPath!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: filled && !hasImage
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.blue, theme.blueDeep],
              )
            : null,
        color: !filled && !hasImage ? theme.blue.withValues(alpha: 0.09) : null,
        border: Border.all(
          color: filled ? theme.yellow : theme.blue.withValues(alpha: 0.27),
          width: filled ? 2 : 1.5,
        ),
        boxShadow: filled
            ? [BoxShadow(color: theme.blue.withValues(alpha: 0.27), blurRadius: 14, offset: const Offset(0, 4))]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: !hasImage
          ? Center(child: child)
          : avatarPath!.startsWith('http')
              ? Image.network(avatarPath!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: child))
              : Image.file(File(avatarPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: child)),
    );
  }
}

/// نوار سه‌رنگ آبی-سفید-زرد — نشان‌واره‌ی تکرارشونده‌ی هزاره‌نامه.
class FlagStripe extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;
  const FlagStripe({super.key, this.height = 4, this.width, this.radius = 2});

  @override
  Widget build(BuildContext context) {
    Widget bar = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: width,
        child: const Row(children: [
          Expanded(flex: 11, child: ColoredBox(color: Color(0xFF2F6FB5))),
          Expanded(flex: 10, child: ColoredBox(color: Color(0xFFF4F6FA))),
          Expanded(flex: 11, child: ColoredBox(color: Color(0xFFF2BB2D))),
        ]),
      ),
    );
    return bar;
  }
}

/// باکس آیکون رنگی — برای کارت‌های آماری در پنل مدیریت.
class StatIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const StatIconBox({super.key, required this.icon, required this.color, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, color: color, size: size * 0.46),
    );
  }
}

/// دکمه‌ی اصلی (پُر، آبی)
class HzPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppColors theme;
  final IconData? icon;
  final bool loading;

  const HzPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.theme,
    this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.blue, theme.blueDeep]),
          boxShadow: disabled
              ? null
              : [BoxShadow(color: theme.blue.withValues(alpha: 0.38), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: loading ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Colors.white)),
                        if (icon != null) const SizedBox(width: 6),
                        if (icon != null) Icon(icon, size: 15, color: Colors.white),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// دکمه‌ی ثانویه (خطوط‌دار)
class HzSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final AppColors theme;
  const HzSecondaryButton({super.key, required this.label, required this.onPressed, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: theme.bgCard.withValues(alpha: 0.35),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onPressed,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.glassBorder, width: 1.3),
                ),
                child: Center(
                  child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: theme.textPrimary)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// دکمه‌ی گرد کوچک برای آیکون (بازگشت، دوربین، ...)
class HzIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final AppColors theme;
  final Color? iconColor;
  const HzIconButton({super.key, required this.icon, required this.onPressed, required this.theme, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: theme.bgCard.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.glassBorder),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 33, height: 33,
              child: Icon(icon, size: 16, color: iconColor ?? theme.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// فیلد ورودی متنی با آیکون، و پیشنهادهای اختیاری (معادل datalist در وب —
/// کاربر همچنان می‌تواند هرچیزی تایپ کند؛ پیشنهادها فقط کمک‌کننده‌اند).
class HzTextField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final AppColors theme;
  final bool obscureText;
  final Widget? suffix;
  final List<String>? suggestions;
  final TextInputType? keyboardType;

  const HzTextField({
    super.key,
    required this.controller,
    required this.icon,
    required this.hint,
    required this.theme,
    this.obscureText = false,
    this.suffix,
    this.suggestions,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textFaint, fontSize: 13),
        prefixIcon: Icon(icon, size: 16, color: theme.textFaint),
        suffixIcon: suffix,
        filled: true,
        fillColor: theme.bgCard.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.glassBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.blue, width: 1.6)),
      ),
    );

    if (suggestions == null || suggestions!.isEmpty) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: suggestions!.map((s) => GestureDetector(
                onTap: () => controller.text = s,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.bgCardAlt,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: theme.border),
                  ),
                  child: Text(s, style: TextStyle(fontSize: 10.5, color: theme.textSecondary)),
                ),
              )).toList(),
        ),
      ],
    );
  }
}

/// فیلد انتخابی (dropdown) — برای زبان مادری و مواردی که واقعاً باید محدود
/// به یک لیست ثابت باشند.
class HzSelectField extends StatelessWidget {
  final String? value;
  final IconData icon;
  final String hint;
  final List<String> options;
  final AppColors theme;
  final ValueChanged<String?> onChanged;

  const HzSelectField({
    super.key,
    required this.value,
    required this.icon,
    required this.hint,
    required this.options,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
      dropdownColor: theme.bgCard,
      style: TextStyle(color: theme.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textFaint, fontSize: 13),
        prefixIcon: Icon(icon, size: 16, color: theme.textFaint),
        filled: true,
        fillColor: theme.bgCard.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.glassBorder)),
      ),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: onChanged,
    );
  }
}

/// نوار پله‌ای بالای فرم‌های چندمرحله‌ای (ثبت‌نام)
class StepDots extends StatelessWidget {
  final int step;
  final int total;
  final AppColors theme;
  const StepDots({super.key, required this.step, required this.total, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(left: i == total - 1 ? 0 : 6),
            height: 4,
            decoration: BoxDecoration(
              color: active ? theme.blue : theme.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

/// چک‌باکس ساده (برای «مرا به‌خاطر بسپار»)
class HzCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final AppColors theme;
  const HzCheckbox({super.key, required this.value, required this.onChanged, required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            color: value ? theme.blue : Colors.transparent,
            border: Border.all(color: value ? theme.blue : theme.border, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: value ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 11.5, color: theme.textSecondary)),
      ]),
    );
  }
}

/// نمودار خطی کوچک (روند آماری) — با CustomPaint، بدون نیاز به پکیج جدا.
class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double width;
  final double height;
  const Sparkline({super.key, required this.data, required this.color, this.width = 90, this.height = 30});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(width, height), painter: _SparklinePainter(data, color));
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final minV = data.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = data.length == 1 ? 0.0 : (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

// =============================================================================
// ویجت‌های بازطراحی مدرن — کارت شیشه‌ای، پس‌زمینه‌ی متحرک، دکمه‌ی دستیار هوشمند
// =============================================================================

/// کارت شیشه‌ای مدرن (glassmorphism) — برای بخش‌های برجسته مثل پیشنهادهای
/// هوش مصنوعی و هدرهای جدید؛ با BackdropFilter پشت خودش را کمی تار می‌کند.
class HzGlassCard extends StatelessWidget {
  final Widget child;
  final AppColors theme;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Gradient? borderGradient;
  final VoidCallback? onTap;
  final double blur;
  final bool sheen;

  const HzGlassCard({
    super.key,
    required this.child,
    required this.theme,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.borderGradient,
    this.onTap,
    this.blur = 22,
    this.sheen = true,
  });

  @override
  Widget build(BuildContext context) {
    final panel = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: theme.glassBorder, width: 1.2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 28, offset: const Offset(0, 14))],
          ),
          child: Stack(children: [
            // پرشدگی شیشه‌ای پایه
            Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55))),
            ),
            // درخشش موربِ بالا — حس واقعی نور روی شیشه
            if (sheen) Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: theme.glassSheen))),
            Padding(padding: padding, child: child),
          ]),
        ),
      ),
    );
    if (onTap == null) return panel;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: panel),
      ),
    );
  }
}

/// پس‌زمینه‌ی تزئینی از دایره‌های محو رنگی که به‌آرامی شناورند — حس مدرن و
/// پویا به صفحات اصلی (خانه، دستیار هوشمند) می‌دهد؛ بدون هیچ پکیج اضافه.
class BlobBackground extends StatelessWidget {
  final AppColors theme;
  const BlobBackground({super.key, required this.theme});

  Widget _blob(Color color, double size) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
      child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(children: [
        Positioned(top: -60, right: -40, child: _blob(theme.blue.withValues(alpha: 0.22), 220)),
        Positioned(top: 170, left: -70, child: _blob(theme.aiViolet.withValues(alpha: 0.16), 200)),
        Positioned(bottom: -80, right: 30, child: _blob(theme.yellow.withValues(alpha: 0.14), 240)),
      ]).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: 14, duration: 5200.ms, curve: Curves.easeInOut),
    );
  }
}

/// یک آیتم نوار پایین شیشه‌ای — آیکون عادی/فعال + برچسب.
class HzGlassNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const HzGlassNavItem({required this.icon, required this.activeIcon, required this.label});
}

/// نوار پایین شناور و شیشه‌ای — جایگزین NavigationBar استاندارد؛ روی
/// پس‌زمینه‌ی متحرک (AnimatedBackdrop) شناور می‌ماند و با یک نشانگر گرد
/// متحرک، تب فعال را برجسته می‌کند.
class HzGlassNavBar extends StatelessWidget {
  final AppColors theme;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<HzGlassNavItem> items;
  const HzGlassNavBar({super.key, required this.theme, required this.selectedIndex, required this.onSelected, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: theme.bgElevated.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: theme.glassBorder, width: 1.2),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 32, offset: const Offset(0, 14))],
            ),
            child: Row(children: [for (var i = 0; i < items.length; i++) Expanded(child: _navItem(i))]),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i) {
    final active = i == selectedIndex;
    final item = items[i];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(i),
        borderRadius: BorderRadius.circular(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
            decoration: BoxDecoration(
              gradient: active ? LinearGradient(colors: [theme.blue.withValues(alpha: 0.28), theme.blue.withValues(alpha: 0.1)]) : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(active ? item.activeIcon : item.icon, size: 20, color: active ? theme.blue : theme.textFaint),
          ),
          const SizedBox(height: 3),
          Text(item.label, style: TextStyle(fontSize: 9.5, color: active ? theme.blue : theme.textFaint, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }
}

/// دکمه‌ی شناور «دستیار هوشمند» — گرادیان بنفش-فیروزه‌ای با هاله‌ی نرم و
/// یک ضربان آرام؛ در صفحات اصلی اپ کاربر را به گفتگو با هوش مصنوعی دعوت می‌کند.
class AiFab extends StatelessWidget {
  final AppColors theme;
  final VoidCallback onTap;
  const AiFab({super.key, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: theme.aiGradient,
          boxShadow: [BoxShadow(color: theme.aiViolet.withValues(alpha: 0.45), blurRadius: 22, spreadRadius: 1, offset: const Offset(0, 8))],
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1, end: 1.06, duration: 1400.ms, curve: Curves.easeInOut);
  }
}

/// سه نقطه‌ی «در حال نوشتن» — نشانگر فکرکردن دستیار هوشمند در چت.
class TypingDots extends StatelessWidget {
  final Color color;
  const TypingDots({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
              .animate(onPlay: (c) => c.repeat())
              .fade(begin: 0.25, end: 1, duration: 420.ms, delay: (i * 160).ms)
              .then()
              .fade(begin: 1, end: 0.25, duration: 420.ms),
        );
      }),
    );
  }
}

/// باز کردن یک لینک ویدیو (یوتیوب، آپارات، لینک مستقیم و…) در مرورگر یا
/// اپ خارجی مربوطه. اگر لینک نامعتبر بود یا باز نشد، پیام کوتاه نشان می‌دهد.
Future<void> openContentUrl(BuildContext context, String url) async {
  final fixedUrl = url.contains('://') ? url : 'https://$url';
  final uri = Uri.tryParse(fixedUrl);
  if (uri == null) {
    if (context.mounted) showHzToast(context, 'لینک نامعتبر است.');
    return;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showHzToast(context, 'باز کردن لینک ممکن نشد.');
}

/// کاور رسانه‌ای یک آیتم محتوا (عکس و/یا لینک ویدیو) — با گوشه‌های گرد،
/// سایه‌ی ملایم پایینی برای خوانایی متن روی عکس، و دکمه‌ی شفاف «پخش» اگر
/// ویدیو داشته باشد. اگر آیتم هیچ عکس/ویدیویی نداشته باشد، دقیقاً همان
/// [fallback] (مثلاً آیکون یا گرادیان قبلی) را بدون هیچ تغییری نشان می‌دهد —
/// یعنی افزودن این ویجت به بخش‌های موجود، ظاهر آیتم‌های بدون رسانه را
/// دست‌نخورده نگه می‌دارد.
class ContentMediaCover extends StatelessWidget {
  final ContentItem item;
  final Widget fallback;
  final double height;
  final double? width;
  final double radius;
  const ContentMediaCover({
    super.key,
    required this.item,
    required this.fallback,
    this.height = 120,
    this.width,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    final videoUrl = item.videoUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    if (!hasImage && !hasVideo) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: width ?? double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          if (hasImage)
            Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)
          else
            fallback,
          if (hasImage)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x40000000)],
                ),
              ),
            ),
          if (hasVideo)
            Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => openContentUrl(context, videoUrl),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0x73000000),
                      border: Border.all(color: Colors.white70, width: 1.5),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// پیام کوتاه شناور — معادل Toast در دموی وب.
void showHzToast(BuildContext context, String message) {
  final theme = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, textAlign: TextAlign.center),
      backgroundColor: theme.textPrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      margin: const EdgeInsets.only(bottom: 90, left: 60, right: 60),
      duration: const Duration(milliseconds: 1800),
    ),
  );
}
