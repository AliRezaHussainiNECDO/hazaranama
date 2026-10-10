import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import 'artist_screen.dart';

/// بخش «موسیقی و شعر» — به‌جای فهرست ساده‌ی آهنگ‌ها، حالا یک گالری از
/// هنرمندان است: هر هنرمند یک کارت با آواتار و تعداد ویدیو؛ با زدن روی
/// هرکدام، پروفایل و گالری ویدیوهای همان هنرمند باز می‌شود.
class ArtistsGalleryBody extends StatefulWidget {
  final AppColors theme;
  const ArtistsGalleryBody({super.key, required this.theme});

  @override
  State<ArtistsGalleryBody> createState() => _ArtistsGalleryBodyState();
}

class _ArtistsGalleryBodyState extends State<ArtistsGalleryBody> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    if (app.artists.isEmpty) _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      await context.read<AppState>().loadArtists();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final artists = context.watch<AppState>().artists;

    if (_loading && artists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (artists.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
          children: [
            Icon(Icons.music_note_outlined, size: 40, color: theme.textFaint),
            const SizedBox(height: 12),
            Text('هنوز هیچ هنرمندی افزوده نشده', textAlign: TextAlign.center, style: TextStyle(color: theme.textFaint, fontSize: 12.5)),
            const SizedBox(height: 6),
            Text('مدیر می‌تواند از پنل مدیریت، هنرمند و ویدیوهایش را اضافه کند.', textAlign: TextAlign.center, style: TextStyle(color: theme.textFaint, fontSize: 12, height: 1.8)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        itemCount: artists.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 13, crossAxisSpacing: 13, childAspectRatio: 0.78),
        itemBuilder: (context, i) => _ArtistCard(theme: theme, artist: artists[i]).staggered(i),
      ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final AppColors theme;
  final Artist artist;
  const _ArtistCard({required this.theme, required this.artist});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = artist.avatarUrl != null && artist.avatarUrl!.isNotEmpty;
    return HzGlassCard(
      theme: theme,
      radius: 22,
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArtistScreen(artistId: artist.id))),
      child: Column(children: [
        const SizedBox(height: 18),
        Container(
          width: 74, height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.aiViolet, theme.blue]),
            boxShadow: [BoxShadow(color: theme.blue.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          padding: const EdgeInsets.all(2.5),
          child: ClipOval(
            child: hasAvatar
                ? Image.network(artist.avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initial(theme, artist.name))
                : _initial(theme, artist.name),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(artist.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: theme.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.play_circle_fill_rounded, size: 12, color: theme.blue),
            const SizedBox(width: 4),
            Text('${artist.videoCount} ویدیو', style: TextStyle(color: theme.blue, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
        const Spacer(),
      ]),
    );
  }

  Widget _initial(AppColors theme, String name) => ColoredBox(
        color: theme.bgCardAlt,
        child: Center(
          child: Text(name.isNotEmpty ? name[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)),
        ),
      );
}
