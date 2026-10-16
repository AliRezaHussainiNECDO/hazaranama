import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/afghan_calendar.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

/// فهرست قدردانی از حامیان — مرتب‌شده بر پایه‌ی مجموع دلاریِ تقریبیِ
/// کمک‌های تأییدشده‌ی هرکس؛ برای تشویق و قدردانی از همه‌ی کمک‌کنندگان.
class DonorLeaderboardScreen extends StatefulWidget {
  const DonorLeaderboardScreen({super.key});
  @override
  State<DonorLeaderboardScreen> createState() => _DonorLeaderboardScreenState();
}

class _DonorLeaderboardScreenState extends State<DonorLeaderboardScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await context.read<AppState>().loadDonorLeaderboard();
    } catch (_) {
      // ویوی donor_leaderboard هنوز اجرا نشده یا شبکه در دسترس نیست؛
      // فهرست فعلی (شاید خالی) همچنان نمایش داده می‌شود.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final entries = app.donorLeaderboard;

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
                leading: IconButton(icon: Icon(Icons.arrow_forward_rounded, color: theme.textPrimary, size: 20), onPressed: () => Navigator.of(context).pop()),
                title: Text('فهرست حامیان', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.6)),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.success.withValues(alpha: 0.85), theme.aiTeal.withValues(alpha: 0.75)]),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(children: [
                            Icon(Icons.emoji_events_rounded, color: Colors.white, size: 26),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'سپاس از همه‌ی کسانی که هزاره‌نامه را زنده نگه می‌دارند. حلقه‌ی دور عکس هر کس نشان مقام فعالیت اوست، نه مبلغ حمایت.',
                                style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.9, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 18),
                        if (entries.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: Text('هنوز هیچ حمایتی تأیید نشده — اولین نفر باش!', style: TextStyle(color: theme.textFaint, fontSize: 12))),
                          )
                        else ...[
                          Row(children: [
                            Icon(Icons.emoji_events_rounded, size: 15, color: theme.yellow),
                            const SizedBox(width: 6),
                            Text('جدول قهرمانان', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                          ]),
                          const SizedBox(height: 10),
                          _Podium(theme: theme, top3: entries.take(3).toList()),
                          if (entries.length > 3) ...[
                            const SizedBox(height: 22),
                            for (final (i, e) in entries.skip(3).indexed) ...[
                              _DonorRow(theme: theme, rank: i + 4, entry: e).staggered(i),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ],
                      ],
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _DonorRow extends StatelessWidget {
  final AppColors theme;
  final int rank;
  final DonorRankEntry entry;
  const _DonorRow({required this.theme, required this.rank, required this.entry});

  (Color, IconData)? get _medal => switch (rank) {
        1 => (const Color(0xFFFFC94D), Icons.emoji_events_rounded),
        2 => (const Color(0xFFC0C8D6), Icons.emoji_events_rounded),
        3 => (const Color(0xFFCD7F4A), Icons.emoji_events_rounded),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final tier = context.read<AppState>().donorTierForUserId(entry.userId);
    final medal = _medal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.bgCard.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: medal != null ? medal.$1.withValues(alpha: 0.5) : theme.glassBorder),
      ),
      child: Row(children: [
        SizedBox(
          width: 26,
          child: medal != null
              ? Icon(medal.$2, size: 20, color: medal.$1)
              : Text(toFaDigits('$rank'), textAlign: TextAlign.center, style: TextStyle(color: theme.textFaint, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 8),
        DonorRing(
          theme: theme, tier: tier, size: 52, childSize: 40,
          child: HzBadge(theme: theme, size: 40, filled: true, avatarPath: entry.avatarPath,
              child: Text(entry.name.isNotEmpty ? entry.name[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.name, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              if (tier != null) ...[
                DonorTierChip(tier: tier),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  entry.lastDonationAt != null ? 'آخرین حمایت: ${afghanDateLabel(entry.lastDonationAt!)}' : '',
                  style: TextStyle(color: theme.textFaint, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('~${entry.totalUsd.toStringAsFixed(0)}\$', style: TextStyle(color: theme.success, fontSize: 13, fontWeight: FontWeight.w800)),
          Text('${toFaDigits('${entry.donationCount}')} حمایت', style: TextStyle(color: theme.textFaint, fontSize: 11)),
        ]),
      ]),
    );
  }
}

/// سکوی ۳ نفر برتر — طلا، نقره، برنز — با قاب‌های متحرکِ مقام‌شان.
class _Podium extends StatelessWidget {
  final AppColors theme;
  final List<DonorRankEntry> top3;
  const _Podium({required this.theme, required this.top3});

  @override
  Widget build(BuildContext context) {
    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 20, 10, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [theme.yellow.withValues(alpha: 0.14), Colors.transparent]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: second != null ? _PodiumSpot(theme: theme, entry: second, rank: 2, standHeight: 60, standColor: const Color(0xFFC0C8D6)) : const SizedBox()),
        const SizedBox(width: 8),
        Expanded(child: first != null ? _PodiumSpot(theme: theme, entry: first, rank: 1, standHeight: 86, standColor: const Color(0xFFFFC94D)) : const SizedBox()),
        const SizedBox(width: 8),
        Expanded(child: third != null ? _PodiumSpot(theme: theme, entry: third, rank: 3, standHeight: 46, standColor: const Color(0xFFCD7F4A)) : const SizedBox()),
      ]),
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  final AppColors theme;
  final DonorRankEntry entry;
  final int rank;
  final double standHeight;
  final Color standColor;
  const _PodiumSpot({required this.theme, required this.entry, required this.rank, required this.standHeight, required this.standColor});

  @override
  Widget build(BuildContext context) {
    final tier = context.read<AppState>().donorTierForUserId(entry.userId);
    final avatarSize = rank == 1 ? 56.0 : 46.0;
    final ringSize = rank == 1 ? 66.0 : 56.0;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (rank == 1) const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFC94D), size: 22) else const SizedBox(height: 22),
      const SizedBox(height: 4),
      DonorRing(
        theme: theme, tier: tier, size: ringSize, childSize: avatarSize,
        child: HzBadge(theme: theme, size: avatarSize, filled: true, avatarPath: entry.avatarPath,
            child: Text(entry.name.isNotEmpty ? entry.name[0] : '؟', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: rank == 1 ? 18 : 14))),
      ),
      const SizedBox(height: 6),
      Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
      Text('~${entry.totalUsd.toStringAsFixed(0)}\$', style: TextStyle(color: theme.success, fontSize: 11.5, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        height: standHeight,
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: standColor.withValues(alpha: 0.22),
          border: Border.all(color: standColor.withValues(alpha: 0.55)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Text('$rank', style: TextStyle(color: standColor, fontSize: 20, fontWeight: FontWeight.w900)),
      ),
    ]);
  }
}
