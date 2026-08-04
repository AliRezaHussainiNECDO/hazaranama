import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import 'video_player_screen.dart';

/// پروفایل یک هنرمند — کاور، آواتار، بیوگرافی، و شبکه‌ی ویدیوهایش با
/// تامبنیل و تعداد بازدید؛ با زدن روی هر ویدیو، پخش تمام‌عیار باز می‌شود.
class ArtistScreen extends StatefulWidget {
  final String artistId;
  const ArtistScreen({super.key, required this.artistId});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  List<ArtistVideo>? _videos;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final videos = await context.read<AppState>().fetchArtistVideos(widget.artistId);
      if (mounted) setState(() { _videos = videos; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'بارگذاری ویدیوها ناموفق بود.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().colors;
    final artists = context.watch<AppState>().artists;
    final artist = artists.where((a) => a.id == widget.artistId).cast<Artist?>().firstWhere((_) => true, orElse: () => null);

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
                title: Text(artist?.name ?? 'هنرمند', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.6)),
          SafeArea(
            child: artist == null
                ? Center(child: Text('این هنرمند پیدا نشد', style: TextStyle(color: theme.textFaint, fontSize: 12)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                      children: [
                        _ArtistHeader(theme: theme, artist: artist),
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(children: [
                            Icon(Icons.video_library_outlined, size: 15, color: theme.blue),
                            const SizedBox(width: 6),
                            Text('ویدیوها', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                          ]),
                        ),
                        const SizedBox(height: 10),
                        if (_loading)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
                        else if (_error != null)
                          Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Center(child: Text(_error!, style: TextStyle(color: theme.danger, fontSize: 12))))
                        else if ((_videos ?? []).isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
                            child: Center(child: Text('هنوز ویدیویی از این هنرمند اضافه نشده', textAlign: TextAlign.center, style: TextStyle(color: theme.textFaint, fontSize: 12))),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _videos!.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.82),
                              itemBuilder: (context, i) => _VideoCard(theme: theme, video: _videos![i], artistName: artist.name).staggered(i),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _ArtistHeader extends StatelessWidget {
  final AppColors theme;
  final Artist artist;
  const _ArtistHeader({required this.theme, required this.artist});

  @override
  Widget build(BuildContext context) {
    final hasCover = artist.coverUrl != null && artist.coverUrl!.isNotEmpty;
    final hasAvatar = artist.avatarUrl != null && artist.avatarUrl!.isNotEmpty;
    return Column(children: [
      Stack(clipBehavior: Clip.none, children: [
        Container(
          height: 130,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.blueDeep, theme.aiViolet, theme.yellow]),
            image: hasCover ? DecorationImage(image: NetworkImage(artist.coverUrl!), fit: BoxFit.cover, opacity: 0.55) : null,
          ),
        ),
        Positioned(
          bottom: -36, left: 0, right: 0,
          child: Center(
            child: Container(
              width: 84, height: 84,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, color: theme.bg, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 14)]),
              child: ClipOval(
                child: hasAvatar
                    ? Image.network(artist.avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackAvatar())
                    : _fallbackAvatar(),
              ),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 44),
      Text(artist.name, style: TextStyle(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
      if (artist.bio.isNotEmpty) ...[
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Text(artist.bio, textAlign: TextAlign.center, style: TextStyle(color: theme.textSecondary, fontSize: 11.5, height: 1.9)),
        ),
      ],
    ]);
  }

  Widget _fallbackAvatar() => Container(
        color: theme.bgCardAlt,
        child: Center(child: Text(artist.name.isNotEmpty ? artist.name[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 26))),
      );
}

class _VideoCard extends StatelessWidget {
  final AppColors theme;
  final ArtistVideo video;
  final String artistName;
  const _VideoCard({required this.theme, required this.video, required this.artistName});

  String _formatViews(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final hasThumb = video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty;
    return HzGlassCard(
      theme: theme,
      radius: 16,
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: video, artistName: artistName))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(fit: StackFit.expand, children: [
            hasThumb
                ? Image.network(video.thumbnailUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0x55000000)])),
            ),
            Center(
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.4), border: Border.all(color: Colors.white54)),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.4)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.visibility_outlined, size: 11, color: theme.textFaint),
              const SizedBox(width: 3),
              Text('${_formatViews(video.viewsCount)} بازدید', style: TextStyle(color: theme.textFaint, fontSize: 9.5)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _placeholder() => DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [theme.blue.withValues(alpha: 0.3), theme.aiViolet.withValues(alpha: 0.2)])),
        child: const Center(child: Icon(Icons.music_note, color: Colors.white70, size: 26)),
      );
}
