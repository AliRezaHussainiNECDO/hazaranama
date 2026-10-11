import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/afghan_calendar.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import 'artist_screen.dart';

/// بخش «موسیقی و شعر»: سربرگ با آمار، فیلتر گروه‌ها، و برای هر گروه یک ردیف
/// افقی از کارت‌های هنرمند (مثل اپ‌های موسیقی) — مرتب، هم‌اندازه و بدون جای خالی.
class ArtistsGalleryBody extends StatefulWidget {
  final AppColors theme;
  const ArtistsGalleryBody({super.key, required this.theme});

  @override
  State<ArtistsGalleryBody> createState() => _ArtistsGalleryBodyState();
}

const _groupOrder = [
  'اساتید و پیشکسوتان موسیقی اصیل و سنتی',
  'خوانندگان برجسته‌ی پاپ و تلفیقی',
  'هنرمندان و نوازندگان دمبوره و محلی',
  'نسل جوان و فعالان معاصر',
  'استودیوها و کانال‌های رسمی',
];
const _groupShort = ['اساتید و پیشکسوتان', 'پاپ و تلفیقی', 'دمبوره و محلی', 'نسل جوان', 'استودیوها'];
const _groupIcons = [Icons.workspace_premium_rounded, Icons.mic_external_on_rounded, Icons.music_note_rounded, Icons.auto_awesome_rounded, Icons.smart_display_rounded];
const _groupColors = [
  [Color(0xFFF59E0B), Color(0xFFEF4444)],
  [Color(0xFFEC4899), Color(0xFF8B5CF6)],
  [Color(0xFF10B981), Color(0xFF0EA5E9)],
  [Color(0xFF6366F1), Color(0xFFA855F7)],
  [Color(0xFFEF4444), Color(0xFFF97316)],
];

int _gi(String k) => _groupOrder.contains(k) ? _groupOrder.indexOf(k) : 99;

class _ArtistsGalleryBodyState extends State<ArtistsGalleryBody> {
  bool _loading = false;
  String? _filter; // null = همه

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

    if (_loading && artists.isEmpty) return const Center(child: CircularProgressIndicator());
    if (artists.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 60, 24, 24), children: [
          Icon(Icons.music_note_outlined, size: 40, color: theme.textFaint),
          const SizedBox(height: 12),
          Text('هنوز هیچ هنرمندی افزوده نشده', textAlign: TextAlign.center, style: TextStyle(color: theme.textFaint, fontSize: 12.5)),
        ]),
      );
    }

    final groups = <String, List<Artist>>{};
    for (final a in artists) {
      groups.putIfAbsent(a.category.isEmpty ? 'دیگر هنرمندان' : a.category, () => []).add(a);
    }
    final keys = groups.keys.toList()..sort((x, y) => _gi(x).compareTo(_gi(y)));
    final videos = artists.fold<int>(0, (n, a) => n + a.videoCount);
    final shown = _filter == null ? keys : keys.where((k) => k == _filter).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(top: 14, bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _Hero(artists: artists.length, groups: keys.length, videos: videos),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                _Chip(theme: theme, label: 'همه', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                for (final k in keys)
                  _Chip(
                    theme: theme,
                    label: _gi(k) < 99 ? _groupShort[_gi(k)] : k,
                    icon: _gi(k) < 99 ? _groupIcons[_gi(k)] : Icons.people_alt_rounded,
                    selected: _filter == k,
                    onTap: () => setState(() => _filter = _filter == k ? null : k),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final k in shown) ...[
            _GroupHeader(theme: theme, title: k, count: groups[k]!.length),
            const SizedBox(height: 12),
            if (_filter == null)
              SizedBox(
                height: 232,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: groups[k]!.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => SizedBox(
                    width: 152,
                    child: _ArtistCard(theme: theme, artist: groups[k]![i], colors: _gi(k) < 99 ? _groupColors[_gi(k)] : null),
                  ).staggered(i),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: groups[k]!.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 232),
                itemBuilder: (context, i) => _ArtistCard(theme: theme, artist: groups[k]![i], colors: _gi(k) < 99 ? _groupColors[_gi(k)] : null).staggered(i),
              ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final int artists, groups, videos;
  const _Hero({required this.artists, required this.groups, required this.videos});

  @override
  Widget build(BuildContext context) {
    Widget stat(String v, String l) => Expanded(
          child: Column(children: [
            Text(v, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
            Text(l, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
          ]),
        );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFFEC4899), Color(0xFF8B5CF6), Color(0xFF312E81)]),
        boxShadow: [BoxShadow(color: const Color(0xFFEC4899).withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Stack(children: [
        PositionedDirectional(end: -24, top: -26, child: Icon(Icons.graphic_eq_rounded, size: 150, color: Colors.white.withValues(alpha: 0.09))),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('صدای هزارستان', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('از دمبوره‌ی اصیل تا موسیقی تلفیقی — هنرمندانی که روایت ما را می‌خوانند',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, height: 1.6)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                stat(toFaDigits(artists), 'هنرمند'),
                Container(width: 1, height: 28, color: Colors.white24),
                stat(toFaDigits(groups), 'گروه'),
                Container(width: 1, height: 28, color: Colors.white24),
                stat(toFaDigits(videos), 'ویدیو'),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final AppColors theme;
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.theme, required this.label, required this.selected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected ? const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]) : null,
            color: selected ? null : theme.bgCard.withValues(alpha: 0.6),
            border: Border.all(color: selected ? Colors.transparent : theme.glassBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 14, color: selected ? Colors.white : theme.textSecondary), const SizedBox(width: 5)],
            Text(label, style: TextStyle(color: selected ? Colors.white : theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final AppColors theme;
  final String title;
  final int count;
  const _GroupHeader({required this.theme, required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final i = _gi(title);
    final c = i < 99 ? _groupColors[i] : [theme.blue, theme.aiViolet];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(gradient: LinearGradient(colors: c), borderRadius: BorderRadius.circular(10)),
          child: Icon(i < 99 ? _groupIcons[i] : Icons.people_alt_rounded, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w900))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(999)),
          child: Text('${toFaDigits(count)} هنرمند', style: TextStyle(color: theme.textFaint, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final AppColors theme;
  final Artist artist;
  final List<Color>? colors;
  const _ArtistCard({required this.theme, required this.artist, this.colors});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = artist.avatarUrl != null && artist.avatarUrl!.isNotEmpty;
    final soon = artist.videoCount == 0;
    final c = colors ?? [theme.aiViolet, theme.blueDeep];
    return Material(
      color: theme.bgCard.withValues(alpha: 0.75),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: theme.glassBorder)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArtistScreen(artistId: artist.id))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 156,
            child: Stack(fit: StackFit.expand, children: [
              hasAvatar ? HzFullImage(url: artist.avatarUrl!, error: _placeholder(c)) : _placeholder(c),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0x80000000)])),
              ),
              PositionedDirectional(
                top: 8,
                start: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: soon ? const Color(0xEB0F172A) : const Color(0xEBEC4899),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: soon ? const Color(0x66F59E0B) : Colors.transparent),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(soon ? Icons.schedule_rounded : Icons.play_arrow_rounded, size: 11, color: soon ? const Color(0xFFFBBF24) : Colors.white),
                    const SizedBox(width: 3),
                    Text(soon ? 'به‌زودی' : '${toFaDigits(artist.videoCount)} ویدیو',
                        style: TextStyle(color: soon ? const Color(0xFFFBBF24) : Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(artist.bio.split('\n').first, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 10.2, height: 1.55)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder(List<Color> c) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [c[0].withValues(alpha: 0.85), c[1].withValues(alpha: 0.55), const Color(0xFF0F172A)]),
        ),
        child: Stack(children: [
          PositionedDirectional(end: -18, bottom: -22, child: Icon(Icons.music_note_rounded, size: 110, color: Colors.white.withValues(alpha: 0.09))),
          Center(
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
              ),
              child: Text(artist.name.replaceFirst('استاد ', '').characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
            ),
          ),
        ]),
      );
}
