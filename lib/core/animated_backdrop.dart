import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// پس‌زمینه‌ی متحرکِ سراسری هزاره‌نامه — چند بلوب رنگی محو که به‌آرامی و
/// پیوسته در مداری نرم شناورند، روی یک گرادیان پایه به‌علاوه وینیت ملایم
/// برای عمق و خوانایی. این ویجت پایه‌ی بصری تمام شل‌ها و صفحات احراز
/// هویت است؛ محتوای هر صفحه روی این پس‌زمینه با پنل‌های شیشه‌ای
/// (HzGlassCard) شناور می‌شود.
///
/// عمداً بدون هیچ پکیج بیرونی — فقط AnimationController + Transform روی
/// دایره‌های بلورشده — تا سبک و مطمئن بماند.
class AnimatedBackdrop extends StatefulWidget {
  final AppColors theme;
  final double intensity; // 0..1 — چقدر بلوب‌ها دیده شوند (صفحات فرم‌محور کمتر)
  const AnimatedBackdrop({super.key, required this.theme, this.intensity = 1});

  @override
  State<AnimatedBackdrop> createState() => _AnimatedBackdropState();
}

class _AnimatedBackdropState extends State<AnimatedBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final colors = theme.meshColors;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: theme.meshBaseGradient),
        child: ClipRect(
          child: LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 420.0;
            final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 860.0;
            return AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value * 2 * math.pi;
                return Stack(children: [
                  _orbitBlob(colors[0 % colors.length], w, h, size: math.min(w, h) * 0.72, t: t, phase: 0.0, radiusX: 0.34, radiusY: 0.24, alpha: 0.24 * widget.intensity),
                  _orbitBlob(colors[1 % colors.length], w, h, size: math.min(w, h) * 0.8, t: t, phase: 2.2, radiusX: 0.30, radiusY: 0.30, alpha: 0.18 * widget.intensity),
                  _orbitBlob(colors[2 % colors.length], w, h, size: math.min(w, h) * 0.6, t: t, phase: 4.1, radiusX: 0.26, radiusY: 0.22, alpha: 0.17 * widget.intensity),
                  _orbitBlob(colors[3 % colors.length], w, h, size: math.min(w, h) * 0.66, t: t, phase: 1.2, radiusX: 0.22, radiusY: 0.28, alpha: 0.14 * widget.intensity),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.15,
                          colors: [Colors.transparent, theme.bg.withValues(alpha: 0.6)],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ]);
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _orbitBlob(
    Color color,
    double w,
    double h, {
    required double size,
    required double t,
    required double phase,
    required double radiusX,
    required double radiusY,
    required double alpha,
  }) {
    final angle = t + phase;
    final cx = w * 0.5 + w * radiusX * math.cos(angle);
    final cy = h * 0.5 + h * radiusY * math.sin(angle * 0.85 + phase);
    return Positioned(
      left: cx - size / 2,
      top: cy - size / 2,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: alpha)),
        ),
      ),
    );
  }
}
