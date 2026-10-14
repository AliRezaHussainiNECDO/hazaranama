import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/afghan_calendar.dart';
import '../../core/app_colors.dart';
import '../../core/backend_config.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../library/library_screens.dart' show openInApp;

String _s(ContentItem it, String k) => (it[k] ?? '').toString().trim();

/// عنوان نمایشی خبر — برگردان فارسی اگر آماده باشد
String newsTitle(ContentItem it) => _s(it, 'title_fa').isNotEmpty ? _s(it, 'title_fa') : _s(it, 'title');

/// خلاصه‌ی نمایشی خبر — فارسی اگر آماده باشد
String newsSummary(ContentItem it) => _s(it, 'snippet_fa').isNotEmpty ? _s(it, 'snippet_fa') : _s(it, 'snippet');

/// تاریخ خبر به تقویم افغانستان
String newsDate(ContentItem it) {
  final d = DateTime.tryParse(_s(it, 'published'));
  return d != null ? afghanDateLabel(d.toLocal()) : _s(it, 'date');
}

/// چند وقت پیش — برای کارت‌ها
String newsAgo(ContentItem it) {
  final d = DateTime.tryParse(_s(it, 'published'));
  if (d == null) return _s(it, 'date');
  final diff = DateTime.now().difference(d.toLocal());
  if (diff.inMinutes < 60) return '${toFaDigits(diff.inMinutes.clamp(1, 59))} دقیقه پیش';
  if (diff.inHours < 24) return '${toFaDigits(diff.inHours)} ساعت پیش';
  if (diff.inDays < 7) return '${toFaDigits(diff.inDays)} روز پیش';
  return afghanDateLabel(d.toLocal());
}

/// عکس خبر از سایت ناشر؛ در نسخه‌ی وب از مسیر سرور هزاره‌نامه (با CORS)
String? newsImage(ContentItem it) {
  final u = it.imageUrl ?? '';
  if (!u.startsWith('http')) return null;
  if (!kIsWeb || u.startsWith(BackendConfig.apiUrl)) return u;
  return '${BackendConfig.apiUrl}/img-proxy?u=${Uri.encodeComponent(u)}';
}

DateTime _pub(ContentItem it) => DateTime.tryParse(_s(it, 'published')) ?? DateTime(2000);

// =====================================================================
// فهرست خبرها
// =====================================================================
class NewsBody extends StatelessWidget {
  final AppColors theme;
  final List<ContentItem> items;
  const NewsBody({super.key, required this.theme, required this.items});

  @override
  Widget build(BuildContext context) {
    // خبرهای دستی مدیر (بدون تاریخ انتشار) بالا؛ بقیه از تازه به کهنه
    final sorted = [...items]..sort((a, b) {
        final ma = _s(a, 'published').isEmpty, mb = _s(b, 'published').isEmpty;
        if (ma != mb) return ma ? -1 : 1;
        return _pub(b).compareTo(_pub(a));
      });
    if (sorted.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(30), child: Text('هنوز خبری ثبت نشده است.', style: TextStyle(color: theme.textFaint, fontSize: 13))));
    }
    final lead = sorted.first;
    final rest = sorted.skip(1).toList();
    return RefreshIndicator(
      onRefresh: () => context.read<AppState>().reloadSection('news'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          _LeadCard(theme: theme, item: lead).animate().fadeIn(duration: 380.ms).slideY(begin: 0.04, end: 0),
          const SizedBox(height: 16),
          Row(children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: theme.blue, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 8),
            Text('تازه‌ترین خبرها', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 10),
          for (final (i, it) in rest.indexed) ...[
            _NewsRow(theme: theme, item: it).animate().fadeIn(delay: (35 * i.clamp(0, 12)).ms, duration: 300.ms),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

void _open(BuildContext context, ContentItem it) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewsDetailScreen(item: it)));

class _LeadCard extends StatelessWidget {
  final AppColors theme;
  final ContentItem item;
  const _LeadCard({required this.theme, required this.item});

  @override
  Widget build(BuildContext context) {
    final img = newsImage(item);
    return GestureDetector(
      onTap: () => _open(context, item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 250,
          child: Stack(fit: StackFit.expand, children: [
            DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [theme.blueDeep, theme.aiViolet]))),
            if (img != null) Hero(tag: 'news-${item.id}', child: Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x10000000), Color(0xE6000000)], stops: [0.25, 1])),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: theme.danger, borderRadius: BorderRadius.circular(999)),
                child: const Text('خبر برتر', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(newsTitle(item), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w900, height: 1.6)),
                const SizedBox(height: 6),
                Row(children: [
                  if (_s(item, 'source').isNotEmpty) ...[
                    const Icon(Icons.public_rounded, size: 13, color: Colors.white70),
                    const SizedBox(width: 4),
                    Flexible(child: Text(_s(item, 'source'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700))),
                    const Text('  •  ', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                  Text(newsAgo(item), style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NewsRow extends StatelessWidget {
  final AppColors theme;
  final ContentItem item;
  const _NewsRow({required this.theme, required this.item});

  @override
  Widget build(BuildContext context) {
    final img = newsImage(item);
    final summary = newsSummary(item);
    return Material(
      color: theme.bgCard.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(context, item),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.glassBorder)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 96,
                height: 96,
                child: Stack(fit: StackFit.expand, children: [
                  DecoratedBox(
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [theme.blue.withValues(alpha: 0.5), theme.aiViolet.withValues(alpha: 0.4)])),
                    child: const Icon(Icons.newspaper_rounded, color: Colors.white54, size: 30),
                  ),
                  if (img != null) Hero(tag: 'news-${item.id}', child: Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
                ]),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(newsTitle(item), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800, height: 1.6)),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 11.5, height: 1.6)),
                ],
                const SizedBox(height: 5),
                Row(children: [
                  if (_s(item, 'source').isNotEmpty)
                    Flexible(child: Text(_s(item, 'source'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.blue, fontSize: 10.5, fontWeight: FontWeight.w800))),
                  Text('  •  ${newsAgo(item)}', style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// =====================================================================
// جزئیات کامل یک خبر
// =====================================================================
class NewsDetailScreen extends StatefulWidget {
  final ContentItem item;
  const NewsDetailScreen({super.key, required this.item});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  late ContentItem _it = widget.item;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    app.trackActivity('news', widget.item.id);
    // خبرهای خودکاری که هنوز عکس/خلاصه/برگردان ندارند، همین حالا کامل می‌شوند
    if (widget.item.id.startsWith('news-') && _s(widget.item, 'enriched').isEmpty) {
      _loading = true;
      app.fetchNewsItem(widget.item.id).then((full) {
        if (!mounted) return;
        setState(() {
          if (full != null) _it = full;
          _loading = false;
        });
      }).catchError((_) {
        if (mounted) setState(() => _loading = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().colors;
    final it = _it;
    final img = newsImage(it);
    final url = _s(it, 'url');
    final summary = newsSummary(it);
    final original = _s(it, 'snippet');
    final body = _s(it, 'body'); // متن کامل خبرهای دستی مدیر
    final hasFa = _s(it, 'title_fa').isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bg,
        body: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: img != null ? 280 : 0,
            backgroundColor: theme.bg,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: img == null ? Text('خبرنامه', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)) : null,
            flexibleSpace: img == null
                ? null
                : FlexibleSpaceBar(
                    background: Stack(fit: StackFit.expand, children: [
                      Hero(tag: 'news-${it.id}', child: Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => DecoratedBox(decoration: BoxDecoration(color: theme.bgCard)))),
                      DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, theme.bg], stops: const [0.55, 1]))),
                    ]),
                  ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (_s(it, 'source').isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: theme.blue.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                      child: Text(_s(it, 'source'), style: TextStyle(color: theme.blue, fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.schedule_rounded, size: 13, color: theme.textFaint),
                    const SizedBox(width: 4),
                    Text(newsDate(it), style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
                  ]),
                ]),
                const SizedBox(height: 12),
                Text(newsTitle(it), style: TextStyle(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, height: 1.7)),
                if (hasFa) ...[
                  const SizedBox(height: 6),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(_s(it, 'title'), style: TextStyle(color: theme.textFaint, fontSize: 13, height: 1.5, fontStyle: FontStyle.italic)),
                  ),
                ],
                const SizedBox(height: 16),
                if (_loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text('در حال آماده‌سازی خلاصه و برگردان فارسی…', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                    ]),
                  ),
                if (body.isNotEmpty)
                  for (final p in body.split('\n\n'))
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(p, style: TextStyle(color: theme.textSecondary, fontSize: 14.5, height: 2.0)))
                else if (summary.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: theme.bgCard.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border(right: BorderSide(color: theme.blue, width: 3)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('خلاصه‌ی خبر', style: TextStyle(color: theme.blue, fontSize: 12, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(summary, style: TextStyle(color: theme.textSecondary, fontSize: 14, height: 2.0)),
                    ]),
                  ),
                  if (hasFa && original.isNotEmpty && original != summary) ...[
                    const SizedBox(height: 12),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(original, style: TextStyle(color: theme.textFaint, fontSize: 12.5, height: 1.7)),
                    ),
                  ],
                ] else if (!_loading)
                  Text('برای خواندن جزئیات کامل این خبر، آن را در منبع اصلی باز کنید.', style: TextStyle(color: theme.textFaint, fontSize: 13, height: 1.9)),
                if (url.startsWith('http')) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => openInApp(context, url),
                      icon: const Icon(Icons.article_outlined, size: 18),
                      label: Text(_s(it, 'source').isNotEmpty ? 'خواندن متن کامل در ${_s(it, 'source')}' : 'خواندن متن کامل خبر', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(backgroundColor: theme.blue, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('متن کامل داخل همین اپ، در صفحه‌ی خودِ رسانه باز می‌شود.', textAlign: TextAlign.center, style: TextStyle(color: theme.textFaint, fontSize: 11)),
                ],
                if (hasFa) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    Icon(Icons.auto_awesome_rounded, size: 13, color: theme.aiViolet),
                    const SizedBox(width: 5),
                    Expanded(child: Text('عنوان و خلاصه با هوش مصنوعی به فارسی برگردانده شده است.', style: TextStyle(color: theme.textFaint, fontSize: 10.5))),
                  ]),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
