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

    // گروه‌بندی به ترتیب ثابت؛ هنرمندان بی‌گروه در «دیگر هنرمندان»
    const order = [
      'اساتید و پیشکسوتان موسیقی اصیل و سنتی',
      'خوانندگان برجسته‌ی پاپ و تلفیقی',
      'هنرمندان و نوازندگان دمبوره و محلی',
      'نسل جوان و فعالان معاصر',
      'استودیوها و کانال‌های رسمی',
    ];
    const icons = [Icons.workspace_premium_rounded, Icons.mic_external_on_rounded, Icons.music_note_rounded, Icons.auto_awesome_rounded, Icons.smart_display_rounded];
    final groups = <String, List<Artist>>{};
    for (final a in artists) {
      groups.putIfAbsent(a.category.isEmpty ? 'دیگر هنرمندان' : a.category, () => []).add(a);
    }
    final keys = groups.keys.toList()..sort((x, y) => (order.contains(x) ? order.indexOf(x) : 99).compareTo(order.contains(y) ? order.indexOf(y) : 99));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          for (final k in keys) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 11, top: 4),
              child: Row(children: [
                StatIconBox(icon: order.contains(k) ? icons[order.indexOf(k)] : Icons.people_alt_rounded, color: theme.aiViolet, size: 28),
                const SizedBox(width: 9),
                Expanded(child: Text(k, style: TextStyle(color: theme.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800))),
                Text('${groups[k]!.length}', style: TextStyle(color: theme.textFaint, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: groups[k]!.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 13, crossAxisSpacing: 13, childAspectRatio: 0.72),
              itemBuilder: (context, i) => _ArtistCard(theme: theme, artist: groups[k]![i]).staggered(i),
            ),
            const SizedBox(height: 22),
          ],
        ],
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
    final soon = artist.videoCount == 0;
    final tagline = artist.bio.split('\n').first;
    return HzGlassCard(
      theme: theme,
      radius: 22,
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArtistScreen(artistId: artist.id))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Stack(fit: StackFit.expand, children: [
              hasAvatar ? HzFullImage(url: artist.avatarUrl!, error: _initial(theme, artist.name)) : _initial(theme, artist.name),
              // نشان «به‌زودی» یا شمار ویدیوها
              PositionedDirectional(
                top: 8,
                start: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: soon ? const Color(0xE6F59E0B) : theme.blue.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6)],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(soon ? Icons.schedule_rounded : Icons.play_circle_fill_rounded, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(soon ? 'به‌زودی' : '${artist.videoCount} ویدیو', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Column(children: [
            Text(artist.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
            if (tagline.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(tagline, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 10.5, height: 1.6)),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _initial(AppColors theme, String name) => DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [theme.aiViolet.withValues(alpha: 0.75), theme.blueDeep])),
        child: Stack(children: [
          PositionedDirectional(end: -14, bottom: -14, child: Icon(Icons.music_note_rounded, size: 96, color: Colors.white.withValues(alpha: 0.08))),
          Center(
            child: Text(name.replaceFirst('استاد ', '').characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 40)),
          ),
        ]),
      );
}
