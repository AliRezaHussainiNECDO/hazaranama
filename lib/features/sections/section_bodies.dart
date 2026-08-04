import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/article_screen.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';

const _chapterIcons = [
  Icons.groups, Icons.menu_book, Icons.account_balance, Icons.local_fire_department,
  Icons.map, Icons.shield, Icons.history_edu, Icons.explore, Icons.trending_up, Icons.public,
];

String _toFa(int n) {
  const map = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return n.toString().split('').map((d) => map[int.parse(d)]).join();
}

/// ---------------- هویت و تاریخچه: شبکه‌ی فصل‌ها ----------------
class TimelineBody extends StatelessWidget {
  final AppColors theme;
  final List<ContentItem> items;
  const TimelineBody({super.key, required this.theme, required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 11, crossAxisSpacing: 11, childAspectRatio: 0.86),
      itemBuilder: (context, i) {
        final it = items[i];
        final icon = _chapterIcons[i % _chapterIcons.length];
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(ArticleScreen.route(
            theme: theme,
            badge: HzBadge(theme: theme, size: 34, child: Icon(Icons.history_edu, size: 15, color: theme.blue)),
            title: it['era'] as String,
            subtitle: 'هویت و تاریخچه',
            body: (it['full'] ?? it['text']) as String,
            imageUrl: it.imageUrl,
            videoUrl: it.videoUrl,
          )),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 13),
            decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.glassBorder)),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              Positioned(
                top: -10, left: 4,
                child: Text(_toFa(i + 1), style: TextStyle(fontSize: 46, fontWeight: FontWeight.w800, color: theme.blue.withValues(alpha: 0.08))),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ContentMediaCover(item: it, height: 32, width: 32, radius: 10, fallback: StatIconBox(icon: icon, color: theme.blue, size: 32)),
                const SizedBox(height: 9),
                Text(it['era'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700, height: 1.4)),
                const SizedBox(height: 6),
                Expanded(child: Text(it['text'] as String, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 10.5, height: 1.7))),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('فصل ${_toFa(i + 1)} · مطالعه', style: TextStyle(color: theme.blue, fontSize: 9.5, fontWeight: FontWeight.w700)),
                  Icon(Icons.arrow_back, size: 13, color: theme.blue),
                ]),
              ]),
            ]),
          ),
        ).staggered(i);
      },
    );
  }
}

/// ---------------- شخصیت‌های برجسته: شبکه‌ی معرفی گروه‌بندی‌شده ----------------
class PeopleBody extends StatelessWidget {
  final AppColors theme;
  final List<ContentItem> items;
  const PeopleBody({super.key, required this.theme, required this.items});

  static const _categoryMeta = {
    'سیاست و رهبری': Icons.account_balance,
    'حقوق بشر و جامعه مدنی': Icons.shield,
    'علم و پژوهش': Icons.menu_book,
    'هنر و ادبیات': Icons.palette,
    'ورزش': Icons.emoji_events,
  };

  @override
  Widget build(BuildContext context) {
    final categories = <String>[];
    for (final it in items) {
      final c = it['category'] as String?;
      if (c != null && !categories.contains(c)) categories.add(c);
    }
    final groups = categories.isEmpty ? [null] : categories;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        for (final cat in groups) ...[
          if (cat != null) ...[
            Row(children: [
              StatIconBox(icon: _categoryMeta[cat] ?? Icons.person, color: theme.yellow, size: 26),
              const SizedBox(width: 8),
              Text(cat, style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 11),
          ],
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.where((p) => cat == null || p['category'] == cat).length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 11, crossAxisSpacing: 11, childAspectRatio: 0.8),
            itemBuilder: (context, i) {
              final person = items.where((p) => cat == null || p['category'] == cat).toList()[i];
              final color = _categoryMeta.containsKey(cat) ? theme.yellow : theme.blue;
              final icon = _categoryMeta[cat] ?? Icons.person;
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.of(context).push(ArticleScreen.route(
                  theme: theme,
                  badge: HzBadge(theme: theme, size: 34, filled: true, child: Text((person['name'] as String)[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
                  title: person['name'] as String,
                  subtitle: person['category'] as String?,
                  body: (person['bio'] ?? person['field']) as String,
                  imageUrl: person.imageUrl,
                  videoUrl: person.videoUrl,
                )),
                child: Container(
                  decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.glassBorder)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    ContentMediaCover(item: person, height: 44, radius: 0, fallback: Container(height: 44, color: color.withValues(alpha: 0.14))),
                    Transform.translate(
                      offset: const Offset(0, -27),
                      child: Stack(alignment: Alignment.center, children: [
                        HzBadge(theme: theme, size: 54, filled: true, child: Text((person['name'] as String)[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),
                        Positioned(
                          bottom: -2, left: 8,
                          child: Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: theme.bgCard, width: 2)),
                            child: Icon(icon, size: 10, color: theme.bg),
                          ),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
                      child: Column(children: [
                        Text(person['name'] as String, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(person['field'] as String, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 9.5, height: 1.6)),
                      ]),
                    ),
                  ]),
                ),
              ).staggered(i);
            },
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// ---------------- نسل‌کشی هزاره‌ها: کارت‌های تودرتو با جزئیات کامل ----------------
class IncidentsBody extends StatelessWidget {
  final AppColors theme;
  final List<ContentItem> items;
  const IncidentsBody({super.key, required this.theme, required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        for (final (i, it) in items.indexed) ...[
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(ArticleScreen.route(
              theme: theme,
              badge: HzBadge(theme: theme, size: 34, child: Icon(Icons.local_fire_department, size: 15, color: theme.yellow)),
              title: it['title'] as String,
              subtitle: '${it['date']} · ${it['location']}',
              body: ((it['full'] as String?)?.isNotEmpty == true ? it['full'] : it['text']) as String,
              imageUrl: it.imageUrl,
              videoUrl: it.videoUrl,
            )),
            child: Container(
              decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.glassBorder)),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ContentMediaCover(
                  item: it,
                  height: 56,
                  radius: 0,
                  fallback: Container(
                    height: 56, width: double.infinity, color: theme.bgCardAlt,
                    child: Center(
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: theme.yellow.withValues(alpha: 0.14), border: Border.all(color: theme.yellow)),
                        child: Icon(Icons.local_fire_department, size: 15, color: theme.yellow),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it['date'] as String, style: TextStyle(color: theme.blue, fontSize: 10, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text(it['title'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.5)),
                    const SizedBox(height: 7),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _chip(theme, Icons.location_on, it['location'] as String),
                      _chip(theme, Icons.groups, it['attacker'] as String),
                    ]),
                    const SizedBox(height: 9),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: theme.danger.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
                      child: Text(it['deaths'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.danger, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 9),
                    Text(it['text'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 11, height: 1.8)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('مشاهده‌ی شرح کامل', style: TextStyle(color: theme.blue, fontSize: 10, fontWeight: FontWeight.w700)),
                      Icon(Icons.arrow_back, size: 13, color: theme.blue),
                    ]),
                  ]),
                ),
              ]),
            ),
          ).staggered(i, step: const Duration(milliseconds: 45)),
          const SizedBox(height: 12),
        ],
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('منابع: ویکی‌پدیا · دیده‌بان حقوق بشر · یوناما · عفو بین‌الملل',
                textAlign: TextAlign.center, style: TextStyle(color: theme.textFaint, fontSize: 9.5, height: 1.8)),
          ),
        ),
      ],
    );
  }

  Widget _chip(AppColors theme, IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: theme.bgCardAlt, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: theme.textSecondary),
          const SizedBox(width: 4),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 10))),
        ]),
      );
}

/// ---------------- فرهنگ و زندگی: فهرست کارت ----------------
class GridBody extends StatelessWidget {
  final AppColors theme;
  final List<ContentItem> items;
  const GridBody({super.key, required this.theme, required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final it = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
          child: Row(children: [
            ContentMediaCover(item: it, height: 32, width: 32, radius: 10, fallback: StatIconBox(icon: Icons.auto_awesome, color: theme.blue, size: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it['name'] as String, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(it['note'] as String, style: TextStyle(color: theme.textFaint, fontSize: 10.5, height: 1.6)),
              ]),
            ),
          ]),
        ).staggered(i);
      },
    );
  }
}

/// ---------------- موسیقی و شعر ----------------
class TracksBody extends StatelessWidget {
  final AppColors theme;
  final List<ContentItem> items;
  const TracksBody({super.key, required this.theme, required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, i) {
        final it = items[i];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: (it.videoUrl != null && it.videoUrl!.isNotEmpty) ? () => openContentUrl(context, it.videoUrl!) : null,
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
          child: Row(children: [
            ContentMediaCover(
              item: it, height: 32, width: 32, radius: 16,
              fallback: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(shape: BoxShape.circle, color: theme.blue),
                child: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it['title'] as String, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                Text(it['artist'] as String, style: TextStyle(color: theme.textFaint, fontSize: 10)),
              ]),
            ),
            Row(children: [
              Icon(Icons.access_time, size: 11, color: theme.textFaint),
              const SizedBox(width: 4),
              Text(it['duration'] as String, style: TextStyle(color: theme.textFaint, fontSize: 10)),
            ]),
          ]),
          ),
        ).staggered(i);
      },
    );
  }
}

/// ---------------- زبان و گویش هزارگی ----------------
class DictionaryBody extends StatelessWidget {
  final AppColors theme;
  final List<ContentItem> items;
  const DictionaryBody({super.key, required this.theme, required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, i) {
        final it = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((it.imageUrl != null && it.imageUrl!.isNotEmpty) || (it.videoUrl != null && it.videoUrl!.isNotEmpty)) ...[
              ContentMediaCover(item: it, height: 90, radius: 12, fallback: const SizedBox.shrink()),
              const SizedBox(height: 10),
            ],
            Text(it['hazaragi'] as String, style: TextStyle(color: theme.blue, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${it['fa']}  ·  ${it['en']}', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
          ]),
        ).staggered(i);
      },
    );
  }
}

/// ---------------- نقشه‌ی هزارستان: مناطق + اجتماعات برون‌مرزی ----------------
class RegionsBody extends StatefulWidget {
  final AppColors theme;
  final List<ContentItem> items;
  const RegionsBody({super.key, required this.theme, required this.items});

  @override
  State<RegionsBody> createState() => _RegionsBodyState();
}

class _RegionsBodyState extends State<RegionsBody> {
  String? _activeId;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    _activeId ??= items.first.id;
    final active = items.firstWhere((i) => i.id == _activeId, orElse: () => items.first);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Container(
          height: 220,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.glassBorder)),
          child: LayoutBuilder(builder: (context, constraints) {
            return Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _MapShapePainter(theme))),
              for (final r in items)
                Positioned(
                  left: (r.mapX ?? 0.5) * constraints.maxWidth - 9,
                  top: (r.mapY ?? 0.5) * constraints.maxHeight - 9,
                  child: GestureDetector(
                    onTap: () => setState(() => _activeId = r.id),
                    child: Container(
                      width: r.id == _activeId ? 20 : 15,
                      height: r.id == _activeId ? 20 : 15,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: r.id == _activeId ? theme.yellow : theme.blue,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3)],
                      ),
                    ),
                  ),
                ),
            ]);
          }),
        ),
        const SizedBox(height: 6),
        Text('نقشه‌ای نمادین و ساده‌شده برای نمایش پراکندگی نسبی مناطق است، نه نقشه‌ی دقیق جغرافیایی.',
            textAlign: TextAlign.center, style: TextStyle(color: theme.textFaint, fontSize: 9.5)),
        const SizedBox(height: 14),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, i) {
              final r = items[i];
              final isActive = r.id == _activeId;
              return GestureDetector(
                onTap: () => setState(() => _activeId = r.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive ? theme.blue.withValues(alpha: 0.12) : Colors.transparent,
                    border: Border.all(color: isActive ? theme.blue : theme.border),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(r['name'] as String, style: TextStyle(color: isActive ? theme.blue : theme.textSecondary, fontSize: 11, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.location_on, size: 14, color: theme.blue),
              const SizedBox(width: 7),
              Text(active['name'] as String, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            Text(active['note'] as String, style: TextStyle(color: theme.textSecondary, fontSize: 11.5, height: 1.9)),
            if ((active.imageUrl != null && active.imageUrl!.isNotEmpty) || (active.videoUrl != null && active.videoUrl!.isNotEmpty)) ...[
              const SizedBox(height: 10),
              ContentMediaCover(item: active, height: 110, radius: 12, fallback: const SizedBox.shrink()),
            ],
          ]),
        ),
        const SizedBox(height: 20),
        Text('اجتماعات برون‌مرزی', style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final d in kDiaspora) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
            child: Row(children: [
              StatIconBox(icon: Icons.public, color: theme.yellow, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['name'] as String, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(d['note'] as String, style: TextStyle(color: theme.textFaint, fontSize: 10, height: 1.6)),
                ]),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

class _MapShapePainter extends CustomPainter {
  final AppColors theme;
  _MapShapePainter(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = theme.bgElevated;
    final stroke = Paint()..color = theme.border..style = PaintingStyle.stroke..strokeWidth = 1;
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.24)
      ..quadraticBezierTo(size.width * 0.05, size.height * 0.5, size.width * 0.18, size.height * 0.76)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.94, size.width * 0.58, size.height * 0.88)
      ..quadraticBezierTo(size.width * 0.82, size.height * 0.82, size.width * 0.86, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.9, size.height * 0.28, size.width * 0.66, size.height * 0.14)
      ..quadraticBezierTo(size.width * 0.46, size.height * 0.02, size.width * 0.18, size.height * 0.24)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    // نقطه‌ی مرجع کابل
    final kabulPaint = Paint()..color = theme.textFaint;
    canvas.drawCircle(Offset(size.width * 0.63, size.height * 0.38), 3, kabulPaint);
    final tp = TextPainter(
      text: TextSpan(text: 'کابل', style: TextStyle(color: theme.textFaint, fontSize: 10)),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, Offset(size.width * 0.65, size.height * 0.40));
  }

  @override
  bool shouldRepaint(covariant _MapShapePainter oldDelegate) => false;
}

/// ---------------- آلبوم عکس ----------------
class PhotosBody extends StatelessWidget {
  final AppColors theme;
  final List<ContentItem> items;
  const PhotosBody({super.key, required this.theme, required this.items});

  @override
  Widget build(BuildContext context) {
    final colors = [theme.blue, theme.yellow];
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.95),
      itemBuilder: (context, i) {
        final it = items[i];
        final hasImage = it.imageUrl != null && it.imageUrl!.isNotEmpty;
        return Container(
          decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Expanded(
              child: InkWell(
                onTap: hasImage ? () => _openFullscreen(context, it.imageUrl!, it['caption'] as String) : null,
                child: ContentMediaCover(
                  item: it,
                  height: double.infinity,
                  width: double.infinity,
                  radius: 0,
                  fallback: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [colors[i % 2].withValues(alpha: 0.35), colors[(i + 1) % 2].withValues(alpha: 0.2)],
                    )),
                    child: Icon(Icons.photo_camera_outlined, color: colors[i % 2].withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(it['caption'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 10)),
            ),
          ]),
        ).staggered(i);
      },
    );
  }

  void _openFullscreen(BuildContext context, String imageUrl, String caption) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
            title: Text(caption, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.network(imageUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 48)),
            ),
          ),
        ),
      ),
    ));
  }
}

/// ---------------- خبرنامه ----------------
class NewsBody extends StatelessWidget {
  final AppColors theme;
  final List<ContentItem> items;
  const NewsBody({super.key, required this.theme, required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final it = items[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.glassBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((it.imageUrl != null && it.imageUrl!.isNotEmpty) || (it.videoUrl != null && it.videoUrl!.isNotEmpty)) ...[
              ContentMediaCover(item: it, height: 130, radius: 12, fallback: const SizedBox.shrink()),
              const SizedBox(height: 10),
            ],
            Text(it['date'] as String, style: TextStyle(color: theme.blue, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(it['title'] as String, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.5)),
            const SizedBox(height: 5),
            Text(it['snippet'] as String, style: TextStyle(color: theme.textFaint, fontSize: 10.5, height: 1.8)),
          ]),
        ).staggered(i);
      },
    );
  }
}

/// ---------------- کتابخانه‌ی دیجیتال ----------------
class BooksBody extends StatelessWidget {
  final AppColors theme;
  final List<ContentItem> items;
  const BooksBody({super.key, required this.theme, required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 11, crossAxisSpacing: 11, childAspectRatio: 0.82),
      itemBuilder: (context, i) {
        final it = items[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.glassBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ContentMediaCover(
              item: it,
              height: 54,
              radius: 10,
              fallback: Container(
                width: double.infinity, height: 54,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [theme.blue.withValues(alpha: 0.2), theme.yellow.withValues(alpha: 0.12)]), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.menu_book, color: theme.textSecondary, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            Text(it['title'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.w700, height: 1.5)),
            const SizedBox(height: 4),
            Text(it['author'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 9.5)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: theme.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
              child: Text(it['tag'] as String, style: TextStyle(color: theme.blue, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ]),
        ).staggered(i);
      },
    );
  }
}
