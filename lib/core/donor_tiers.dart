import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/models.dart';
import 'app_colors.dart';
import 'widgets.dart';

/// بخش‌های مربوط به حمایت مالی (فهرست حامیان و فرم‌ها) فقط روی وب و
/// اندروید نشان داده می‌شوند (راهنمای اپ‌استور 3.1.1). مقام‌ها اما از
/// فعالیت به دست می‌آیند و روی همه‌ی سکوها یکسان‌اند.
bool get donorPerksEnabled => kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;

/// آستانه‌ی مقام لازم برای باز شدن استیکرهای اختصاصی (از «اسطوره» به بالا).
const int kVipStickerTierIndex = 7;

/// استیکرهای محرمانه/اختصاصی — فقط برای کاربرانی که به مقام «اسطوره» یا
/// بالاتر رسیده‌اند، در واکنش پست‌ها و کامنت‌ها باز می‌شود.
const List<String> kVipStickers = ['👑', '💎', '🔥', '⚡', '🐉', '🏆'];

/// سبک تاج هر مقام — چون از مقام ۸ به بالا هرکدام تاج متفاوتی دارند
/// (نقره‌ای، طلاییِ نگین‌دار، یا تاج شاهیِ کامل).
enum DonorCrownStyle { none, silver, gold, imperial }

/// ده مرحله‌ی مقام — از «امتیاز فعالیت» (XP) در همه‌ی بخش‌های اپ به دست می‌آید:
/// آمدن روزانه، خواندن، تماشا، کتاب، خبر، پست، کامنت، واکنش، مسابقه‌ی مقاله…
/// (جدول امتیازها در cloudflare/api/src/xp.ts و lib/models/rank.dart).
/// هرچه کاربر فعال‌تر باشد، نام مقام و قاب دور عکس پروفایلش ارتقا می‌یابد.
class DonorTier {
  final int index;
  final int minXp;
  final String title;
  final List<Color> colors; // برای SweepGradient حلقه — اولین و آخرین باید یکی باشند
  final bool glow;
  final bool sparkle;
  final bool fireAnim; // شعله‌های متحرک دور قاب (استاد، فرمانروا، پادشاه)
  final bool starBadge; // آیکون ستاره‌ی کوچک بالای پروفایل (فقط «ستاره»)
  final DonorCrownStyle crownStyle;
  final Color? tickColor; // تیک تأیید اختصاصیِ رنگی کنار نام — فقط مقام‌های VIP
  const DonorTier({
    required this.index,
    required this.minXp,
    required this.title,
    required this.colors,
    this.glow = false,
    this.sparkle = false,
    this.fireAnim = false,
    this.starBadge = false,
    this.crownStyle = DonorCrownStyle.none,
    this.tickColor,
  });
}

const List<DonorTier> kDonorTiers = [
  DonorTier(
    index: 1, minXp: 0, title: 'تازه‌وارد',
    colors: [Color(0xFFB9BEC7), Color(0xFFEFEFF2), Color(0xFFB9BEC7)],
  ),
  DonorTier(
    index: 2, minXp: 60, title: 'همراه',
    colors: [Color(0xFF4FA8FF), Color(0xFFBFE0FF), Color(0xFF4FA8FF)],
  ),
  DonorTier(
    index: 3, minXp: 180, title: 'کوشا',
    colors: [Color(0xFF2FBE86), Color(0xFF8FF0C8), Color(0xFF2FBE86)],
    glow: true, tickColor: Color(0xFF2FBE86),
  ),
  DonorTier(
    index: 4, minXp: 400, title: 'پژوهشگر',
    colors: [Color(0xFF8E6BFF), Color(0xFFB79CFF), Color(0xFF8E6BFF)],
    glow: true,
  ),
  DonorTier(
    index: 5, minXp: 800, title: 'ستاره',
    colors: [Color(0xFFFFC94D), Color(0xFFFFE096), Color(0xFFFFC94D)],
    glow: true, starBadge: true,
  ),
  DonorTier(
    index: 6, minXp: 1500, title: 'استاد',
    colors: [Color(0xFFFF6A3D), Color(0xFFFFC94D), Color(0xFFFF3D3D), Color(0xFFFF6A3D)],
    glow: true, fireAnim: true,
  ),
  DonorTier(
    index: 7, minXp: 3000, title: 'اسطوره',
    colors: [Color(0xFF6BC8FF), Color(0xFFFFFFFF), Color(0xFF8E6BFF), Color(0xFF6BC8FF)],
    glow: true, sparkle: true,
  ),
  DonorTier(
    index: 8, minXp: 5500, title: 'قهرمان',
    colors: [Color(0xFFD7DEE8), Color(0xFFFFFFFF), Color(0xFFAEB8C6), Color(0xFFD7DEE8)],
    glow: true, sparkle: true, crownStyle: DonorCrownStyle.silver, tickColor: Color(0xFF8E6BFF),
  ),
  DonorTier(
    index: 9, minXp: 9000, title: 'فرمانروا',
    colors: [Color(0xFFFFC94D), Color(0xFFFF6FA8), Color(0xFF8E6BFF), Color(0xFFFFC94D)],
    glow: true, sparkle: true, fireAnim: true, crownStyle: DonorCrownStyle.gold, tickColor: Color(0xFFB07CFF),
  ),
  DonorTier(
    index: 10, minXp: 15000, title: 'خاقان',
    colors: [Color(0xFFFF6FA8), Color(0xFFFFC94D), Color(0xFF6BFFB3), Color(0xFF6BC8FF), Color(0xFF8E6BFF), Color(0xFFFF6FA8)],
    glow: true, sparkle: true, fireAnim: true, crownStyle: DonorCrownStyle.imperial, tickColor: Color(0xFFFFC94D),
  ),
];

/// نرخ تبدیل تقریبی و ثابت به دلار — فقط برای رتبه‌بندی/مقام، نه حسابداری
/// دقیق. باید با نرخ‌های ثابتِ داخل ویوی donor_leaderboard در SQL هماهنگ بماند.
double usdRateFor(String currency) {
  switch (currency) {
    case 'USD':
      return 1.0;
    case 'EUR':
      return 1.08;
    case 'CHF':
      return 1.12;
    case 'GBP':
      return 1.27;
    case 'AFN':
      return 0.014;
    default:
      return 1.0;
  }
}

/// مقام فعلی بر اساس امتیاز فعالیت — چون مرحله‌ی اول («تازه‌وارد») آستانه‌ی
/// صفر دارد، همیشه یک مقام واقعی برمی‌گرداند.
DonorTier rankTierForXp(int xp) {
  var found = kDonorTiers.first;
  for (final t in kDonorTiers) {
    if (xp >= t.minXp) {
      found = t;
    } else {
      break;
    }
  }
  return found;
}

/// مقام مؤثر برای نمایش حلقه‌ی دور عکس — مدیر همیشه بالاترین مقام (خاقان)
/// را دارد؛ بقیه بر پایه‌ی امتیاز فعالیت.
DonorTier rankTierByRole(UserRole? role, int xp) => role == UserRole.admin ? kDonorTiers.last : rankTierForXp(xp);

/// مقام بعدی (برای نوار پیشرفت)؛ null یعنی کاربر در بالاترین مقام است.
DonorTier? nextRankTier(int xp) {
  for (final t in kDonorTiers) {
    if (xp < t.minXp) return t;
  }
  return null;
}

/// پیشرفت (۰ تا ۱) از مقام فعلی تا مقام بعدی.
double progressToNextRank(int xp) {
  final next = nextRankTier(xp);
  if (next == null) return 1.0;
  final base = rankTierForXp(xp).minXp;
  final span = next.minXp - base;
  if (span <= 0) return 1.0;
  return ((xp - base) / span).clamp(0.0, 1.0);
}

const List<Color> kDefaultRingColors = [Color(0xFF2159C4), Colors.white, Color(0xFFFFC94D), Color(0xFF2159C4)];

/// حلقه‌ی پویای دور عکس پروفایل — با هر مقام تازه رنگ‌های بیشتر، درخشش،
/// جرقه‌های شناور، شعله‌های متحرک، آیکون ستاره یا تاج (نقره‌ای/طلایی/شاهی)
/// می‌گیرد — دقیقاً مثل نشان‌های در حال ارتقای تیک‌تاک/اینستاگرام، تا
/// کاربران برای فعالیت بیشتر در هزاره‌نامه تشویق شوند.
class DonorRing extends StatefulWidget {
  final AppColors theme;
  final DonorTier? tier;
  final double size;
  final double childSize;
  final Widget child;
  const DonorRing({super.key, required this.theme, required this.tier, required this.size, required this.childSize, required this.child});

  @override
  State<DonorRing> createState() => _DonorRingState();
}

class _DonorRingState extends State<DonorRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    final tierIndex = widget.tier?.index ?? 0;
    final seconds = (14 - tierIndex * 0.7).clamp(6.0, 14.0);
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: (seconds * 1000).round()))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    final colors = tier?.colors ?? kDefaultRingColors;
    final crownStyle = tier?.crownStyle ?? DonorCrownStyle.none;
    final gapSize = widget.childSize + (widget.size - widget.childSize) * 0.36;

    return SizedBox(
      width: widget.size, height: widget.size,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        if (tier?.glow == true)
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final pulse = (math.sin(_c.value * 2 * math.pi) + 1) / 2;
              return Container(
                width: widget.size, height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.22 + pulse * 0.22), blurRadius: 14 + pulse * 10, spreadRadius: 1)],
                ),
              );
            },
          ),
        AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Transform.rotate(angle: _c.value * 2 * math.pi, child: child),
          child: Container(
            width: widget.size, height: widget.size,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: colors)),
          ),
        ),
        Container(width: gapSize, height: gapSize, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.theme.bgCard)),
        SizedBox(width: widget.childSize, height: widget.childSize, child: widget.child),
        if (tier?.sparkle == true)
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Stack(children: [for (int i = 0; i < 5; i++) _sparkleDot(i)]),
          ),
        if (tier?.fireAnim == true)
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Stack(children: [for (int i = 0; i < 3; i++) _fireDot(i)]),
          ),
        if (crownStyle != DonorCrownStyle.none)
          Positioned(top: crownStyle == DonorCrownStyle.imperial ? -19 : -10, child: _CrownBadge(style: crownStyle, glowColor: colors.first))
        else if (tier?.starBadge == true)
          Positioned(top: -7, child: _StarBadge(color: colors.first)),
      ]),
    );
  }

  Widget _sparkleDot(int i) {
    final angle = _c.value * 2 * math.pi + i * (2 * math.pi / 5);
    final radius = widget.size / 2 - 2;
    final dx = radius * math.cos(angle);
    final dy = radius * math.sin(angle);
    final twinkle = (math.sin(_c.value * 2 * math.pi * 3 + i) + 1) / 2;
    return Positioned(
      left: widget.size / 2 + dx - 2,
      top: widget.size / 2 + dy - 2,
      child: Opacity(
        opacity: 0.35 + twinkle * 0.65,
        child: Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
      ),
    );
  }

  Widget _fireDot(int i) {
    final angle = _c.value * 2 * math.pi * -1 + i * (2 * math.pi / 3);
    final radius = widget.size / 2 - 1;
    final dx = radius * math.cos(angle);
    final dy = radius * math.sin(angle);
    final flicker = (math.sin(_c.value * 2 * math.pi * 4 + i * 2) + 1) / 2;
    return Positioned(
      left: widget.size / 2 + dx - 5,
      top: widget.size / 2 + dy - 5,
      child: Opacity(
        opacity: 0.5 + flicker * 0.5,
        child: Icon(Icons.local_fire_department_rounded, size: 9 + flicker * 3, color: const Color(0xFFFF6A3D)),
      ),
    );
  }
}

/// نشانِ تاج بالای آواتار — عکس واقعیِ سه تاج جواهرنشان (بدون پس‌زمینه)،
/// هرکدام مخصوص یک مقام بالا: تاج نقره‌ایِ یاقوت‌کبود (قهرمان)، تاج طلاییِ
/// جواهرنشان (فرمانروا)، و تاجِ اژدهاییِ کامل با شعله و جواهر (پادشاه/خاقان).
class _CrownBadge extends StatelessWidget {
  final DonorCrownStyle style;
  final Color glowColor;
  const _CrownBadge({required this.style, required this.glowColor});

  String? get _asset => switch (style) {
        DonorCrownStyle.silver => 'assets/crowns/champion_silver.png',
        DonorCrownStyle.gold => 'assets/crowns/sovereign_gold.png',
        DonorCrownStyle.imperial => 'assets/crowns/emperor_imperial.png',
        DonorCrownStyle.none => null,
      };

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    if (asset == null) return const SizedBox.shrink();
    final isImperial = style == DonorCrownStyle.imperial;
    final width = isImperial ? 34.0 : 29.0;
    final height = isImperial ? 37.0 : 20.0;
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: glowColor.withValues(alpha: 0.6), blurRadius: isImperial ? 11 : 7, spreadRadius: 0.5)],
      ),
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}

class _StarBadge extends StatelessWidget {
  final Color color;
  const _StarBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 5)]),
      child: Icon(Icons.star_rounded, size: 11, color: color),
    );
  }
}

/// تیک تأیید اختصاصیِ رنگی کنار نام — فقط برای مقام‌های VIP (قهرمان،
/// فرمانروا، پادشاه) که [DonorTier.tickColor] برایشان تعریف شده.
class DonorVipTick extends StatelessWidget {
  final Color color;
  final double size;
  const DonorVipTick({super.key, required this.color, this.size = 13});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)]),
      child: Icon(Icons.check_rounded, size: size * 0.72, color: Colors.white),
    );
  }
}

/// نشانِ کوچکِ مقامِ کاربر — کنار نام، مشابه نشانِ نقش مدیر/ویراستار.
class DonorTierChip extends StatelessWidget {
  final DonorTier tier;
  const DonorTierChip({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = tier.colors.first;
    final secondColor = tier.colors.length > 1 ? tier.colors[1] : color;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.28), secondColor.withValues(alpha: 0.14)]),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(tier.crownStyle != DonorCrownStyle.none ? Icons.emoji_events_rounded : Icons.favorite_rounded, size: 9.5, color: color),
        const SizedBox(width: 3),
        Text(tier.title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
    // مقام‌های تاج‌دار (قهرمان به بالا) یک درخشش ملایم و پیوسته می‌گیرند تا
    // نشان ویژه‌شان در فید/کامنت/پروفایل بلافاصله به چشم بیاید.
    return tier.crownStyle != DonorCrownStyle.none ? chip.royalShimmer() : chip;
  }
}

/// جلوه‌ی کوچک درخشش طلایی — برای کامنت/پست کاربرانی که به مقام «پادشاه»
/// رسیده‌اند. چون افزودن صدای اختصاصی واقعی نیاز به بسته‌ی صوتی و فایل صدا
/// دارد که فعلاً در پروژه نیست، این جلوه‌ی بصری به‌جای آن استفاده می‌شود.
extension RoyalFlourish on Widget {
  Widget royalShimmer() {
    return animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 1600.ms, color: const Color(0xFFFFE096));
  }
}

/// فهرست کامنت‌های سطح‌اول را طوری مرتب می‌کند که کامنت‌های کاربران
/// «پادشاه» (بالاترین مقام) همیشه بالای فهرست پین شوند — بدون به‌هم‌ریختن
/// ترتیب بقیه‌ی کامنت‌ها.
List<T> pinTopTierComments<T>(List<T> comments, DonorTier? Function(T) tierOf) {
  final pinned = <T>[];
  final rest = <T>[];
  for (final c in comments) {
    if (tierOf(c)?.index == kDonorTiers.last.index) {
      pinned.add(c);
    } else {
      rest.add(c);
    }
  }
  return [...pinned, ...rest];
}

/// شیت انتخاب استیکر — واکنش‌های همیشگی + بخش استیکرهای اختصاصیِ VIP که از
/// مقام «اسطوره» به بالا باز می‌شود؛ برای کاربرانی که هنوز نرسیده‌اند، با
/// آیکون قفل نمایش داده می‌شود (برای تشویق به فعالیت بیشتر).
void showVipStickerPicker({
  required BuildContext context,
  required AppColors theme,
  required DonorTier? myTier,
  required List<String> baseChoices,
  required void Function(String emoji) onPick,
}) {
  final unlocked = (myTier?.index ?? 1) >= kVipStickerTierIndex;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: theme.bgElevated, borderRadius: BorderRadius.circular(22), border: Border.all(color: theme.glassBorder)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(
            alignment: WrapAlignment.center, spacing: 14, runSpacing: 14,
            children: baseChoices
                .map((e) => _StickerDot(theme: theme, emoji: e, locked: false, onTap: () {
                      Navigator.of(ctx).pop();
                      onPick(e);
                    }))
                .toList(),
          ),
          const SizedBox(height: 14),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.workspace_premium_rounded, size: 14, color: theme.yellow),
            const SizedBox(width: 6),
            Text(unlocked ? 'استیکرهای اختصاصیِ اسطوره به بالا' : 'استیکر اختصاصی — از مقام «اسطوره» باز می‌شود',
                style: TextStyle(color: theme.textFaint, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center, spacing: 14, runSpacing: 14,
            children: kVipStickers
                .map((e) => _StickerDot(
                      theme: theme, emoji: e, locked: !unlocked,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        if (unlocked) {
                          onPick(e);
                        } else {
                          showHzToast(context, 'این استیکر مخصوص مقام «اسطوره» به بالاست — با فعالیت بیشتر در هزاره‌نامه بازش کن!');
                        }
                      },
                    ))
                .toList(),
          ),
        ]),
      ),
    ),
  );
}

class _StickerDot extends StatelessWidget {
  final AppColors theme;
  final String emoji;
  final bool locked;
  final VoidCallback onTap;
  const _StickerDot({required this.theme, required this.emoji, required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46, height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: locked ? theme.bgCardAlt.withValues(alpha: 0.5) : theme.bgCard,
          border: Border.all(color: locked ? theme.glassBorder : theme.blue.withValues(alpha: 0.4)),
        ),
        child: locked ? Icon(Icons.lock_rounded, size: 16, color: theme.textFaint) : Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}
