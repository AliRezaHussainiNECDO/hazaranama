import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/afghan_calendar.dart';
import '../../core/app_colors.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../contest/article_contest_screen.dart';

/// نوار بالای صفحه‌ی خانه — فقط تبلیغ «مسابقه‌ی مقالات» با تایمر معکوس زنده
/// تا پایان مهلت ارسال (طبق درخواست، دیگر سلایدهای «روایت امروز» حذف
/// شده‌اند و فقط همین یک کارت می‌ماند).
class StoryCarousel extends StatefulWidget {
  final AppColors theme;
  const StoryCarousel({super.key, required this.theme});

  @override
  State<StoryCarousel> createState() => _StoryCarouselState();
}

class _StoryCarouselState extends State<StoryCarousel> {
  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadContestSettings();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppState>().contestSettings;
    return SizedBox(height: 272, child: _ContestSlide(theme: widget.theme, settings: settings));
  }
}

/// اسلاید تبلیغاتی «مسابقه‌ی مقالات هزاره‌نامه» — با کلیک، صفحه‌ی مسابقه
/// (قوانین + فرم شرکت + وضعیت مقالات کاربر) باز می‌شود؛ خودِ کارت هم یک
/// تایمر معکوسِ زنده تا پایان مهلت ارسال (روز ۲۸ دوره) نشان می‌دهد.
class _ContestSlide extends StatefulWidget {
  final AppColors theme;
  final ContestSettings settings;
  const _ContestSlide({required this.theme, required this.settings});

  @override
  State<_ContestSlide> createState() => _ContestSlideState();
}

class _ContestSlideState extends State<_ContestSlide> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final settings = widget.settings;
    final remaining = settings.timeUntilDeadline;

    return HzGlassCard(
      theme: theme,
      radius: 24,
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArticleContestScreen())),
      child: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [theme.yellow.withValues(alpha: 0.9), theme.blueDeep.withValues(alpha: 0.85), theme.aiViolet.withValues(alpha: 0.8)],
              ),
            ),
          ),
        ),
        Positioned(
          top: -18, left: -18,
          child: Icon(Icons.emoji_events, size: 130, color: Colors.white.withValues(alpha: 0.12)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(999)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.emoji_events, size: 13, color: Colors.white),
                SizedBox(width: 5),
                Text('مسابقه‌ی مقالات', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('نویسنده‌ی هزاره‌نامه شوید',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.3)),
              const SizedBox(height: 4),
              const Text('مقاله‌تان را روی موضوع این دوره بنویسید؛ برای سه مقام برتر جایزه در نظر گرفته شده.',
                  style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.7)),
              const SizedBox(height: 10),
              if (settings.hasActiveRound && settings.submissionsOpen)
                _CountdownRow(remaining: remaining)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    settings.hasActiveRound ? 'مهلت ارسال تمام شده — در انتظار رتبه‌بندی' : 'دوره‌ی تازه به‌زودی آغاز می‌شود',
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('شرکت در مسابقه', style: TextStyle(color: theme.blueDeep, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 5),
                  Icon(Icons.arrow_back, size: 13, color: theme.blueDeep),
                ]),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// تایمر معکوس زنده: روز / ساعت / دقیقه / ثانیه، با ارقام فارسی.
class _CountdownRow extends StatelessWidget {
  final Duration remaining;
  const _CountdownRow({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    return Row(mainAxisSize: MainAxisSize.min, children: [
      _unit(days, 'روز'),
      _colon(),
      _unit(hours, 'ساعت'),
      _colon(),
      _unit(minutes, 'دقیقه'),
      _colon(),
      _unit(seconds, 'ثانیه'),
    ]);
  }

  Widget _colon() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 3),
        child: Text(':', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w800)),
      );

  Widget _unit(int value, String label) {
    return Column(children: [
      Container(
        width: 34,
        padding: const EdgeInsets.symmetric(vertical: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
        child: Text(toFaDigits(value.toString().padLeft(2, '0')), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 8.5)),
    ]);
  }
}
