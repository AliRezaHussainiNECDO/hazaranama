import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
export 'package:flutter_animate/flutter_animate.dart';

/// لوگوی رسمی هزاره‌نامه — همان تصویری که برای برنامه طراحی شده،
/// در همه‌جا (صفحه‌ی خوش‌آمدگویی، ورود، نوار بالای اپ، بارگذاری) از همین
/// یک منبع استفاده می‌کند تا همه‌جا یکسان باشد.
class AppLogo extends StatelessWidget {
  final double size;
  final bool glow;
  const AppLogo({super.key, this.size = 64, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final image = ClipOval(
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
    if (!glow) return image;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: const Color(0xFFF2BB2D).withValues(alpha: 0.35), blurRadius: size * 0.35, spreadRadius: size * 0.03),
        ],
      ),
      child: image,
    );
  }
}

/// لوگوی بزرگ با ورود انیمیشنی — برای صفحه‌ی خوش‌آمدگویی و بارگذاری.
/// ترکیبی از بزرگ‌شدن نرم + محوشدن + یک هاله‌ی نورانی که به‌آرامی تپش دارد.
class AnimatedAppLogo extends StatelessWidget {
  final double size;
  const AnimatedAppLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return AppLogo(size: size, glow: true)
        .animate()
        .scale(begin: const Offset(0.6, 0.6), duration: 650.ms, curve: Curves.easeOutBack)
        .fadeIn(duration: 500.ms)
        .then()
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1, end: 1.035, duration: 1600.ms, curve: Curves.easeInOut);
  }
}

/// بسته‌بندی برای هر عنصر قابل‌لمس — با فشردن، کمی کوچک می‌شود
/// (همان حس لمسی «hz-press» در نسخه‌ی وب) تا اپ زنده‌تر احساس شود.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Pressable({super.key, required this.child, this.onTap});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// ورود پلکانی برای آیتم‌های یک شبکه/فهرست — هر آیتم کمی دیرتر از قبلی
/// محو و بزرگ می‌شود تا لیست‌ها به‌جای ظاهرشدن یک‌دفعه‌ای، زنده به‌نظر برسند.
extension StaggeredEntrance on Widget {
  Widget staggered(int index, {Duration step = const Duration(milliseconds: 45)}) {
    return animate(delay: step * index)
        .fadeIn(duration: 320.ms, curve: Curves.easeOut)
        .slideY(begin: 0.08, end: 0, duration: 320.ms, curve: Curves.easeOut);
  }
}
