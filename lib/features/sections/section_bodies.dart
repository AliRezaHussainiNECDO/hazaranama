import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/article_screen.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';

const _chapterIcons = [
  Icons.groups_rounded, Icons.menu_book_rounded, Icons.account_balance_rounded, Icons.local_fire_department_rounded,
  Icons.map_rounded, Icons.shield_rounded, Icons.history_edu_rounded, Icons.explore_rounded, Icons.trending_up_rounded, Icons.public_rounded,
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
            badge: HzBadge(theme: theme, size: 34, child: Icon(Icons.history_edu_rounded, size: 15, color: theme.blue)),
            title: it['era'] as String,
            subtitle: 'هویت و تاریخچه',
            body: (it['full'] ?? it['text']) as String,
            imageUrl: it.imageUrl,
            videoUrl: it.videoUrl,
            item: it,
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
                ContentMediaCover(item: it, height: 32, width: 32, radius: 10, fallback: SectionMediaPlaceholder(accent: theme.blue, icon: icon, height: 32, width: 32)),
                const SizedBox(height: 9),
                Text(it['era'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700, height: 1.4)),
                const SizedBox(height: 6),
                Expanded(child: Text(it['text'] as String, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 12, height: 1.7))),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('فصل ${_toFa(i + 1)} · مطالعه', style: TextStyle(color: theme.blue, fontSize: 11, fontWeight: FontWeight.w700)),
                  Icon(Icons.arrow_back_rounded, size: 13, color: theme.blue),
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
    'سیاست و رهبری': Icons.account_balance_rounded,
    'حقوق بشر و جامعه مدنی': Icons.shield_rounded,
    'علم و پژوهش': Icons.menu_book_rounded,
    'هنر و ادبیات': Icons.palette_rounded,
    'ورزش': Icons.emoji_events_rounded,
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
              StatIconBox(icon: _categoryMeta[cat] ?? Icons.person_rounded, color: theme.yellow, size: 26),
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
              final icon = _categoryMeta[cat] ?? Icons.person_rounded;
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
                  item: person,
                )),
                child: Container(
                  decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.glassBorder)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    // عکس کامل شخصیت (بی‌برش)؛ اگر عکس نباشد، حرف نخست نام روی زمینه‌ی رنگی
                    Expanded(
                      child: (person.imageUrl ?? '').isNotEmpty
                          ? HzFullImage(url: person.imageUrl!, error: _PersonInitial(name: person['name'] as String, color: color, icon: icon))
                          : _PersonInitial(name: person['name'] as String, color: color, icon: icon),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                      child: Column(children: [
                        Text(person['name'] as String, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(person['field'] as String, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 11, height: 1.6)),
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
              badge: HzBadge(theme: theme, size: 34, child: Icon(Icons.local_fire_department_rounded, size: 15, color: theme.yellow)),
              title: it['title'] as String,
              subtitle: '${it['date']} · ${it['location']}',
              body: ((it['full'] as String?)?.isNotEmpty == true ? it['full'] : it['text']) as String,
              imageUrl: it.imageUrl,
              videoUrl: it.videoUrl,
              item: it,
            )),
            child: Container(
              decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.glassBorder)),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ContentMediaCover(
                  item: it,
                  height: (it.imageUrl ?? '').isNotEmpty ? 170 : 56,
                  radius: 0,
                  fallback: SectionMediaPlaceholder(accent: theme.yellow, icon: Icons.local_fire_department_rounded, height: (it.imageUrl ?? '').isNotEmpty ? 170 : 56),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it['date'] as String, style: TextStyle(color: theme.blue, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text(it['title'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.5)),
                    const SizedBox(height: 7),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _chip(theme, Icons.location_on_rounded, it['location'] as String),
                      _chip(theme, Icons.groups_rounded, it['attacker'] as String),
                    ]),
                    const SizedBox(height: 9),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: theme.danger.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
                      child: Text(it['deaths'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.danger, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 9),
                    Text(it['text'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.8)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('مشاهده‌ی شرح کامل', style: TextStyle(color: theme.blue, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      Icon(Icons.arrow_back_rounded, size: 13, color: theme.blue),
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
                textAlign: TextAlign.center, style: TextStyle(color: theme.textFaint, fontSize: 11, height: 1.8)),
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
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 11.5))),
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
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(ArticleScreen.route(
            theme: theme,
            badge: HzBadge(theme: theme, size: 34, child: Icon(Icons.auto_awesome_rounded, size: 15, color: theme.aiViolet)),
            title: it['name'] as String,
            subtitle: 'فرهنگ و زندگی',
            body: (it['full'] ?? it['note']) as String,
            imageUrl: it.imageUrl,
            videoUrl: it.videoUrl,
            item: it,
          )),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
            child: Row(children: [
              ContentMediaCover(item: it, height: 32, width: 32, radius: 10, fallback: SectionMediaPlaceholder(accent: theme.aiViolet, icon: Icons.auto_awesome_rounded, height: 32, width: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it['name'] as String, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(it['note'] as String, style: TextStyle(color: theme.textFaint, fontSize: 12, height: 1.6)),
                ]),
              ),
              Icon(Icons.chevron_left_rounded, size: 16, color: theme.textFaint),
            ]),
          ),
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
                child: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it['title'] as String, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                Text(it['artist'] as String, style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
              ]),
            ),
            Row(children: [
              Icon(Icons.access_time_rounded, size: 11, color: theme.textFaint),
              const SizedBox(width: 4),
              Text(it['duration'] as String, style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
            ]),
          ]),
          ),
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
    // مدخل‌هایی با diaspora=true اجتماعات برون‌مرزی‌اند: روی نقشه نقطه نمی‌گیرند و در فهرست پایین می‌آیند.
    final items = widget.items.where((i) => i.fields['diaspora'] != true).toList();
    final diaspora = widget.items.where((i) => i.fields['diaspora'] == true).map((i) => i.fields).toList();
    final diasporaList = diaspora.isNotEmpty ? diaspora : kDiaspora;
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
            textAlign: TextAlign.center, style: TextStyle(color: theme.textFaint, fontSize: 11)),
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
                  child: Text(r['name'] as String, style: TextStyle(color: isActive ? theme.blue : theme.textSecondary, fontSize: 12.5, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
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
            if ((active.imageUrl ?? '').isNotEmpty) ...[
              ContentMediaCover(item: active, height: 160, radius: 12, fallback: SectionMediaPlaceholder(accent: theme.blue, icon: Icons.terrain_rounded, height: 160)),
              if (active.imageCredit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text('📷 ${active.imageCredit}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 9.5)),
                ),
              const SizedBox(height: 10),
            ],
            Row(children: [
              Icon(Icons.location_on_rounded, size: 14, color: theme.blue),
              const SizedBox(width: 7),
              Expanded(child: Text(active['name'] as String, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 6),
            Text(active['note'] as String, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.9)),
            if ((active['full'] ?? '').toString().isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => _openRegion(context, active),
                  icon: Icon(Icons.arrow_back_rounded, size: 15, color: theme.blue),
                  label: Text('بیشتر بخوانید', style: TextStyle(color: theme.blue, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 20),
        Text('اجتماعات برون‌مرزی', style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final d in diasporaList) ...[
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openRegion(context, d),
            child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
            child: Row(children: [
              StatIconBox(icon: Icons.public_rounded, color: theme.yellow, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['name'] as String, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(d['note'] as String, style: TextStyle(color: theme.textFaint, fontSize: 11.5, height: 1.6)),
                ]),
              ),
              Icon(Icons.chevron_left_rounded, size: 18, color: theme.textFaint),
            ]),
          ),
          ),
        ],
      ],
    );
  }

  void _openRegion(BuildContext context, dynamic r) {
    final theme = widget.theme;
    final item = r is ContentItem ? r : null;
    final full = (r['full'] ?? '').toString();
    Navigator.of(context).push(ArticleScreen.route(
      theme: theme,
      badge: HzBadge(theme: theme, size: 34, child: Icon(Icons.location_on_rounded, size: 15, color: theme.blue)),
      title: r['name'] as String,
      subtitle: 'نقشه‌ی هزارستان',
      body: full.isNotEmpty ? full : r['note'] as String,
      imageUrl: item?.imageUrl,
      videoUrl: item?.videoUrl,
      item: item,
    ));
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
      text: TextSpan(text: 'کابل', style: TextStyle(fontFamily: 'Vazirmatn', color: theme.textFaint, fontSize: 11.5)),
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
                onTap: hasImage ? () => _openFullscreen(context, it) : null,
                child: ContentMediaCover(
                  item: it,
                  height: double.infinity,
                  width: double.infinity,
                  radius: 0,
                  fallback: SectionMediaPlaceholder(accent: colors[i % 2], icon: Icons.photo_camera_rounded, height: double.infinity, width: double.infinity),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it['caption'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 11.5)),
                if (it.imageCredit.isNotEmpty)
                  Text(it.imageCredit, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 9.5)),
              ]),
            ),
          ]),
        ).staggered(i);
      },
    );
  }

  void _openFullscreen(BuildContext context, ContentItem it) {
    final imageUrl = it.imageUrl!;
    final caption = it['caption'] as String;
    final desc = (it['desc'] ?? '').toString();
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
            leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
            title: Text(caption, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          body: Column(children: [
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(imageUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48)),
                ),
              ),
            ),
            if (desc.isNotEmpty || it.imageCredit.isNotEmpty)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (desc.isNotEmpty) Text(desc, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.8)),
                    if (it.imageCredit.isNotEmpty)
                      InkWell(
                        onTap: it.imagePage.isEmpty ? null : () => openContentUrl(context, it.imagePage),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('📷 ${it.imageCredit}', style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
                        ),
                      ),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    ));
  }
}

/// جای عکس برای شخصیتی که عکس آزاد ندارد
class _PersonInitial extends StatelessWidget {
  final String name;
  final Color color;
  final IconData icon;
  const _PersonInitial({required this.name, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0.12)]),
      ),
      alignment: Alignment.center,
      child: Text(name.isNotEmpty ? name.characters.first : '؟', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
    );
  }
}
