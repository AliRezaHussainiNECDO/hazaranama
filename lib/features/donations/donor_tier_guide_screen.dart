import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/afghan_calendar.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/donor_tiers.dart';
import '../../state/app_state.dart';

/// راهنمای کامل ۱۰ مرحله‌ی مقام — توضیح می‌دهد هر مرحله با چند دلار کمک
/// تأییدشده باز می‌شود، قاب دور عکس پروفایل چه شکلی می‌گیرد، و از کدام
/// مرحله به بعد ویژگی‌های ویژه (تیک رنگی، پین‌شدن کامنت، استیکر اختصاصی)
/// فعال می‌شود — تا کاربران با آگاهی کامل برای رسیدن به مقام بالاتر کمک کنند.
class DonorTierGuideScreen extends StatelessWidget {
  const DonorTierGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: AppBar(
                backgroundColor: theme.bgElevated.withValues(alpha: 0.5),
                elevation: 0,
                leading: IconButton(icon: Icon(Icons.arrow_forward, color: theme.textPrimary, size: 20), onPressed: () => Navigator.of(context).pop()),
                title: Text('راهنمای مقام‌ها', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.6)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.aiViolet.withValues(alpha: 0.85), theme.blueDeep.withValues(alpha: 0.8)]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(children: [
                    Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 26),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'با هر کمک مالی تأییدشده، مقام و قاب دور عکس پروفایلت یک پله بالاتر می‌رود — تا مرحله‌ی ۱۰: پادشاه (خاقان). مقام‌ها دائمی‌اند و هرگز افت نمی‌کنند.',
                        style: TextStyle(color: Colors.white, fontSize: 11, height: 1.9, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
                for (final (i, t) in kDonorTiers.indexed) ...[
                  _TierGuideCard(theme: theme, tier: t).staggered(i),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.star_border_rounded, size: 15, color: theme.yellow),
                      const SizedBox(width: 7),
                      Text('ویژگی‌های ویژه‌ی مقام‌های بالا', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      '• قهرمان و فرمانروا: تیک تأیید بنفش کنار نام، در پست‌ها و کامنت‌ها.\n'
                      '• پادشاه (خاقان): تیک طلایی، نام درشت و طلایی، و کامنت‌هایش همیشه بالای فهرست کامنت‌ها پین می‌شود.\n'
                      '• از مرحله‌ی اسطوره به بالا: دسترسی به استیکرهای اختصاصی برای واکنش و کامنت.\n'
                      '• رسیدن به مرحله‌ی پادشاه، با یک پیام سراسری به همه‌ی کاربران هزاره‌نامه اعلام می‌شود. 👑',
                      style: TextStyle(color: theme.textSecondary, fontSize: 11, height: 2.1),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _TierGuideCard extends StatelessWidget {
  final AppColors theme;
  final DonorTier tier;
  const _TierGuideCard({required this.theme, required this.tier});

  String get _thresholdLabel => tier.minUsd <= 0 ? 'از همان لحظه‌ی ثبت‌نام' : 'از ${tier.minUsd.toStringAsFixed(0)}\$ کمک تأییدشده به بالا';

  String get _effectLabel => switch (tier.index) {
        1 => 'یک حلقه‌ی نازک و ساده‌ی خاکستری/سفید دور عکس پروفایل.',
        2 => 'حلقه‌ی آبی روشن با چرخش ملایم.',
        3 => 'حلقه‌ی سبز درخشان + تیک سبز کنار نام.',
        4 => 'قاب بنفش با افکت نئونی درخشان.',
        5 => 'قاب طلایی شیک + آیکون ستاره‌ی کوچک بالای پروفایل.',
        6 => 'قاب آتشین با شعله‌های متحرک دور عکس.',
        7 => 'قاب شیشه‌ای درخشان با ذرات شاین شناور.',
        8 => 'تاج نقره‌ای روی آواتار + قاب پلاتینیومی با هاله‌ی نور.',
        9 => 'تاج طلایی با نگین‌های متحرک + شعله‌های درخشان دور آواتار.',
        _ => 'تاج شاهیِ کامل، الماس‌نشان و متحرک + نورِ ویژه دور تمام تصویر.',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.bgCard.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.glassBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DonorRing(
          theme: theme, tier: tier, size: 56, childSize: 46,
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, color: tier.colors.first.withValues(alpha: 0.18)),
            alignment: Alignment.center,
            child: Text(toFaDigits(tier.index), style: TextStyle(color: tier.colors.first, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('مرحله ${toFaDigits(tier.index)} — ${tier.title}', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
              if (tier.tickColor != null) ...[
                const SizedBox(width: 6),
                DonorVipTick(color: tier.tickColor!, size: 13),
              ],
            ]),
            const SizedBox(height: 3),
            Text(_thresholdLabel, style: TextStyle(color: theme.success, fontSize: 10.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(_effectLabel, style: TextStyle(color: theme.textSecondary, fontSize: 10.5, height: 1.8)),
          ]),
        ),
      ]),
    );
  }
}
