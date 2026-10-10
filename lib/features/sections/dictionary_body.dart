import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';

/// واژه‌نامه‌ی گسترده‌تر هزارگی به دری (گردآوری نبی‌زاده، منتشرشده در سایت مشعل)
const kMashalHazaragiGlossary =
    'https://mashal.org/blog/%D8%AA%D8%B1%D8%AC%D9%85%D9%87-%DB%8C-%D9%84%D9%87%D8%AC%D9%87-%D9%88-%DA%AF%D9%88%DB%8C%D8%B4-%D9%87%D8%B2%D8%A7%D8%B1%D9%87-%DA%AF%DB%8C-%D8%A8%D9%87-%D8%AF%D8%B1%DB%8C/';

String _fa(int n) {
  const map = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return n.toString().split('').map((d) => map[int.parse(d)]).join();
}

String _s(ContentItem it, String key) {
  final v = it[key];
  return v == null ? '' : v.toString().trim();
}

/// ---------------- زبان و گویش هزارگی: واژه‌نامه ----------------
/// سربرگ با «واژه‌ی امروز»، جست‌وجو (هزارگی، دری یا انگلیسی)، دسته‌ها،
/// کارت‌های بازشونده با آوانویسی، نمونه‌ی کاربرد، توضیح و منبع.
class DictionaryBody extends StatefulWidget {
  final AppColors theme;
  final List<ContentItem> items;
  const DictionaryBody({super.key, required this.theme, required this.items});

  @override
  State<DictionaryBody> createState() => _DictionaryBodyState();
}

class _DictionaryBodyState extends State<DictionaryBody> {
  final _search = TextEditingController();
  String _query = '';
  String? _cat;
  final Set<String> _open = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _cats {
    final out = <String>[];
    for (final it in widget.items) {
      final c = _s(it, 'cat');
      if (c.isNotEmpty && !out.contains(c)) out.add(c);
    }
    return out;
  }

  Color _catColor(String cat) {
    final t = widget.theme;
    final palette = [t.blue, t.aiViolet, t.aiTeal, t.yellow, t.success, t.blueDeep, t.danger];
    final i = _cats.indexOf(cat);
    return palette[(i < 0 ? 0 : i) % palette.length];
  }

  bool _matches(ContentItem it) {
    if (_cat != null && _s(it, 'cat') != _cat) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return ['hazaragi', 'fa', 'en', 'tr', 'example', 'example_fa']
        .any((k) => _s(it, k).toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final items = widget.items;
    final filtered = items.where(_matches).toList();
    final cats = _cats;

    // در حالت عادی واژه‌ها زیر سرفصل دسته‌ها می‌آیند؛ در جست‌وجو یک فهرست ساده.
    final rows = <Widget>[];
    if (_query.isEmpty && _cat == null && cats.isNotEmpty) {
      for (final c in cats) {
        final group = filtered.where((it) => _s(it, 'cat') == c).toList();
        if (group.isEmpty) continue;
        rows.add(_CatHeader(theme: theme, title: c, count: group.length, color: _catColor(c)));
        for (final it in group) {
          rows.add(_tile(it));
        }
      }
      final rest = filtered.where((it) => _s(it, 'cat').isEmpty).toList();
      if (rest.isNotEmpty) {
        rows.add(_CatHeader(theme: theme, title: 'واژه‌های دیگر', count: rest.length, color: theme.blue));
        for (final it in rest) {
          rows.add(_tile(it));
        }
      }
    } else {
      for (final it in filtered) {
        rows.add(_tile(it));
      }
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (items.isNotEmpty) _Hero(theme: theme, items: items, catCount: cats.length),
              const SizedBox(height: 14),
              _searchField(theme),
              const SizedBox(height: 10),
              if (cats.isNotEmpty) _chips(theme, cats),
              const SizedBox(height: 6),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => rows[i],
              childCount: rows.length,
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                Icon(Icons.search_off_rounded, color: theme.textFaint, size: 40),
                const SizedBox(height: 8),
                Text('واژه‌ای با «$_query» پیدا نشد.', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
              ]),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            child: _MashalCard(theme: theme),
          ),
        ),
      ],
    );
  }

  Widget _searchField(AppColors theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bgCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.glassBorder),
      ),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v.trim()),
        style: TextStyle(color: theme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'جست‌وجو به هزارگی، دری یا انگلیسی…',
          hintStyle: TextStyle(color: theme.textFaint, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: theme.blue),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded, color: theme.textFaint, size: 18),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _chips(AppColors theme, List<String> cats) {
    Widget chip(String label, String? value, Color color) {
      final selected = _cat == value;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: GestureDetector(
          onTap: () => setState(() => _cat = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color : theme.bgCard.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: selected ? color : theme.glassBorder),
            ),
            child: Text(label,
                style: TextStyle(
                  color: selected ? Colors.white : theme.textSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                )),
          ),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('همه', null, theme.blue),
          for (final c in cats) chip(c, c, _catColor(c)),
        ],
      ),
    );
  }

  Widget _tile(ContentItem it) {
    final theme = widget.theme;
    final open = _open.contains(it.id);
    final cat = _s(it, 'cat');
    final color = cat.isEmpty ? theme.blue : _catColor(cat);
    final tr = _s(it, 'tr');
    final example = _s(it, 'example');
    final exampleFa = _s(it, 'example_fa');
    final note = _s(it, 'note');
    final src = _s(it, 'src');
    final en = _s(it, 'en');
    final hasMore = example.isNotEmpty || note.isNotEmpty || src.isNotEmpty || (it.imageUrl ?? '').isNotEmpty || (it.videoUrl ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GestureDetector(
        onTap: hasMore ? () => setState(() => open ? _open.remove(it.id) : _open.add(it.id)) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          decoration: BoxDecoration(
            color: theme.bgCard.withValues(alpha: open ? 0.85 : 0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: open ? color.withValues(alpha: 0.6) : theme.glassBorder),
            boxShadow: open ? [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6))] : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
              PositionedDirectional(start: 0, top: 0, bottom: 0, width: 5, child: ColoredBox(color: color)),
              Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(19, 12, 12, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Expanded(
                        child: Text(_s(it, 'hazaragi'),
                            style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w900, height: 1.3)),
                      ),
                      if (tr.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text(tr,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(color: color, fontSize: 11, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
                        ),
                      if (hasMore) ...[
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: open ? 0.5 : 0,
                          duration: const Duration(milliseconds: 240),
                          child: Icon(Icons.expand_more_rounded, color: theme.textFaint, size: 20),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 5),
                    Text(_s(it, 'fa'), style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600, height: 1.5)),
                    if (en.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(en, textDirection: TextDirection.ltr, style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
                    ],
                    AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: !open
                          ? const SizedBox(width: double.infinity)
                          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if ((it.imageUrl ?? '').isNotEmpty || (it.videoUrl ?? '').isNotEmpty) ...[
                                const SizedBox(height: 10),
                                ContentMediaCover(
                                  item: it,
                                  height: 120,
                                  radius: 12,
                                  fallback: SectionMediaPlaceholder(accent: color, icon: Icons.translate, height: 120),
                                ),
                              ],
                              if (example.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: color.withValues(alpha: 0.35)),
                                  ),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('نمونه', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text('«$example»', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                                    if (exampleFa.isNotEmpty)
                                      Text('یعنی: $exampleFa', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                                  ]),
                                ),
                              ],
                              if (note.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Icon(Icons.lightbulb_outline_rounded, color: theme.yellow, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(note, style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.6))),
                                ]),
                              ],
                              if (src.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('منبع: $src', style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
                              ],
                            ]),
                    ),
                  ]),
              ),
          ]),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final AppColors theme;
  final List<ContentItem> items;
  final int catCount;
  const _Hero({required this.theme, required this.items, required this.catCount});

  @override
  Widget build(BuildContext context) {
    // «واژه‌ی امروز»: هر روز یک واژه‌ی دیگر (ترجیحاً تک‌واژه، نه عبارت دستوری)
    final pool = items.where((it) => !_s(it, 'hazaragi').startsWith('-') && _s(it, 'fa').isNotEmpty).toList();
    final list = pool.isEmpty ? items : pool;
    final day = DateTime.now().difference(DateTime(2024)).inDays;
    final today = list[day % list.length];
    final tr = _s(today, 'tr');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [theme.blueDeep, theme.aiViolet, theme.aiTeal],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: theme.aiViolet.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        PositionedDirectional(
          end: -10,
          bottom: -38,
          child: Text('هزارگی',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.08), fontSize: 96, fontWeight: FontWeight.w900)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.translate_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('واژه‌نامه‌ی هزارگی', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  Text(
                    catCount > 0 ? '${_fa(items.length)} واژه و عبارت در ${_fa(catCount)} دسته' : '${_fa(items.length)} واژه و عبارت',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  Text('واژه‌ی امروز', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                Text(_s(today, 'hazaragi'), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.25)),
                if (tr.isNotEmpty)
                  Text(tr, textDirection: TextDirection.ltr, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12, fontStyle: FontStyle.italic)),
                const SizedBox(height: 4),
                Text(_s(today, 'fa'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ]),
    ).staggered(0);
  }
}

class _CatHeader extends StatelessWidget {
  final AppColors theme;
  final String title;
  final int count;
  final Color color;
  const _CatHeader({required this.theme, required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
          child: Text(_fa(count), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: theme.glassBorder)),
      ]),
    );
  }
}

class _MashalCard extends StatelessWidget {
  final AppColors theme;
  const _MashalCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.bgCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.yellow.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.menu_book_rounded, color: theme.yellow, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('واژه‌نامه‌ی گسترده‌تر',
                style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w900)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          'فهرست بزرگ «ترجمه‌ی لهجه و گویش هزاره‌گی به دری» با بیش از هزار واژه، گردآوری‌شده از سوی نبی‌زاده، در سایت مشعل منتشر شده است.',
          style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.7),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: () => openContentUrl(context, kMashalHazaragiGlossary),
            icon: Icon(Icons.open_in_new_rounded, color: theme.blue, size: 16),
            label: Text('خواندن در سایت مشعل', style: TextStyle(color: theme.blue, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }
}
