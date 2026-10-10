import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/widgets.dart';
import '../../state/app_state.dart';
import '../donations/donation_screen.dart';

/// کارت نازک تبلیغاتی «کمک‌های مالی» — درست زیر سلاید مسابقه‌ی مقالات در
/// صفحه‌ی خانه؛ با تپیدن کلیک، صفحه‌ی کامل کمک‌های مالی باز می‌شود.
class DonationHomeCard extends StatefulWidget {
  final AppColors theme;
  const DonationHomeCard({super.key, required this.theme});

  @override
  State<DonationHomeCard> createState() => _DonationHomeCardState();
}

class _DonationHomeCardState extends State<DonationHomeCard> {
  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadDonationSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final settings = context.watch<AppState>().donationSettings;

    return HzGlassCard(
      theme: theme,
      radius: 20,
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DonationScreen())),
      child: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight, end: Alignment.bottomLeft,
                colors: [theme.success.withValues(alpha: 0.85), theme.aiTeal.withValues(alpha: 0.8), theme.blueDeep.withValues(alpha: 0.82)],
              ),
            ),
          ),
        ),
        Positioned(bottom: -14, left: -6, child: Icon(Icons.favorite, size: 74, color: Colors.white.withValues(alpha: 0.13))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('به بازسازی هزارستان کمک کنید', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  settings.totalRaised > 0
                      ? 'تاکنون ${settings.totalRaised.toStringAsFixed(0)} ${settings.currency} با کمک شما جمع شده'
                      : 'خانواده، شفاخانه، مکتب، پل و سرک — با شفافیت کامل',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('کمک کنید', style: TextStyle(color: theme.blueDeep, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_back, size: 12, color: theme.blueDeep),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
