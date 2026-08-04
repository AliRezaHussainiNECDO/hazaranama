import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../core/app_colors.dart';

/// پلیر سفارشی ویدیو — پخش/توقف، نوار پیشرفت قابل‌کشیدن، زمان جاری/کل،
/// و دکمه‌ی تمام‌صفحه؛ کاملاً هم‌راستا با زبان بصری شیشه‌ای اپ.
/// [onFirstPlay] دقیقاً یک‌بار، همان لحظه‌ای که کاربر واقعاً پخش را
/// شروع می‌کند صدا زده می‌شود — برای افزایش امن شمارنده‌ی بازدید.
class HzVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final AppColors theme;
  final VoidCallback? onFirstPlay;
  final bool startFullscreen;

  const HzVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.theme,
    this.thumbnailUrl,
    this.onFirstPlay,
    this.startFullscreen = false,
  });

  @override
  State<HzVideoPlayer> createState() => _HzVideoPlayerState();
}

class _HzVideoPlayerState extends State<HzVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;
  bool _controlsVisible = true;
  bool _countedView = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      if (widget.startFullscreen) _controller.play();
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _failed = true);
    });
    _controller.addListener(_onTick);
  }

  void _onTick() {
    if (!_countedView && _controller.value.isPlaying) {
      _countedView = true;
      widget.onFirstPlay?.call();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller.value.isPlaying) {
      _controller.pause();
      _hideTimer?.cancel();
      setState(() => _controlsVisible = true);
    } else {
      _controller.play();
      _scheduleHide();
    }
    setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) setState(() => _controlsVisible = false);
    });
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  void _openFullscreen() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullscreenVideoPage(controller: _controller, theme: widget.theme),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return AspectRatio(
      aspectRatio: _ready ? _controller.value.aspectRatio : 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(alignment: Alignment.center, fit: StackFit.expand, children: [
          const ColoredBox(color: Colors.black),
          if (!_ready && widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
            Image.network(widget.thumbnailUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          if (_ready)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _controlsVisible = !_controlsVisible);
                if (_controlsVisible && _controller.value.isPlaying) _scheduleHide();
              },
              child: Center(child: AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller))),
            ),
          if (!_ready && !_failed) const CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.4),
          if (_failed)
            const Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, color: Colors.white54, size: 34),
              SizedBox(height: 6),
              Text('پخش ویدیو ممکن نشد', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ]),
          if (_ready && _controlsVisible) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                  stops: const [0, 0.6],
                ),
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.4), border: Border.all(color: Colors.white38)),
                  child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow_rounded, color: Colors.white, size: 30),
                ),
              ),
            ),
            Positioned(
              left: 10, right: 10, bottom: 8,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  height: 22,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.6,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: theme.blue,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: theme.blue,
                    ),
                    child: Slider(
                      min: 0,
                      max: _controller.value.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                      value: _controller.value.position.inMilliseconds.toDouble().clamp(0, _controller.value.duration.inMilliseconds.toDouble().clamp(1, double.infinity)),
                      onChanged: (v) => _controller.seekTo(Duration(milliseconds: v.toInt())),
                    ),
                  ),
                ),
                Row(children: [
                  const SizedBox(width: 4),
                  Text('${_fmt(_controller.value.position)} / ${_fmt(_controller.value.duration)}', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  InkWell(onTap: _openFullscreen, child: const Icon(Icons.fullscreen, color: Colors.white, size: 20)),
                  const SizedBox(width: 4),
                ]),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final AppColors theme;
  const _FullscreenVideoPage({required this.controller, required this.theme});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    widget.controller.addListener(_tick);
    _scheduleHide();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.value.isPlaying) setState(() => _controlsVisible = false);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_tick);
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    super.dispose();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = widget.theme;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _controlsVisible = !_controlsVisible);
          if (_controlsVisible && c.value.isPlaying) _scheduleHide();
        },
        child: Stack(alignment: Alignment.center, children: [
          Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
          if (_controlsVisible) ...[
            Positioned(
              top: 8, right: 8,
              child: SafeArea(
                child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: () {
                  if (c.value.isPlaying) {
                    c.pause();
                  } else {
                    c.play();
                    _scheduleHide();
                  }
                  setState(() {});
                },
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.4), border: Border.all(color: Colors.white38)),
                  child: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow_rounded, color: Colors.white, size: 34),
                ),
              ),
            ),
            Positioned(
              left: 16, right: 16, bottom: 16,
              child: SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: theme.blue,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: theme.blue,
                    ),
                    child: Slider(
                      min: 0,
                      max: c.value.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                      value: c.value.position.inMilliseconds.toDouble().clamp(0, c.value.duration.inMilliseconds.toDouble().clamp(1, double.infinity)),
                      onChanged: (v) => c.seekTo(Duration(milliseconds: v.toInt())),
                    ),
                  ),
                  Row(children: [
                    Text('${_fmt(c.value.position)} / ${_fmt(c.value.duration)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
