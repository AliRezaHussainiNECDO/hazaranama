import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/afghan_calendar.dart' show toFaDigits;
import '../../core/app_colors.dart';
import '../../core/app_logo.dart' show StaggeredEntrance;
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

/// آیا این کتاب نسخه‌ی قابل دانلود (آزاد یا آپلودشده‌ی مدیر) دارد؟
bool bookIsDownloadable(ContentItem it) {
  final file = (it['file_url'] ?? '').toString();
  if (file.startsWith('http')) return true;
  return (it['archive_id'] ?? '').toString().isNotEmpty && (it['downloadable'] ?? '').toString() == '1';
}

String _s(ContentItem it, String k) => (it[k] ?? '').toString().trim();

/// باز کردن یک لینک داخل اپ (مرورگر درون‌برنامه‌ای)؛ در وب، تب تازه
Future<void> openInApp(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final ok = await launchUrl(uri, mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView);
  if (!ok && context.mounted) showHzToast(context, 'باز کردن لینک ممکن نشد.');
}

// =====================================================================
// قفسه‌ی کتابخانه
// =====================================================================
class BooksBody extends StatefulWidget {
  final AppColors theme;
  final List<ContentItem> items;
  const BooksBody({super.key, required this.theme, required this.items});

  @override
  State<BooksBody> createState() => _BooksBodyState();
}

class _BooksBodyState extends State<BooksBody> {
  String _filter = 'all'; // all | download | online

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final all = widget.items;
    final list = all.where((it) {
      if (_filter == 'download') return bookIsDownloadable(it);
      if (_filter == 'online') return _s(it, 'read_url').startsWith('http');
      return true;
    }).toList();
    final downloadable = all.where(bookIsDownloadable).length;

    return CustomScrollView(slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
        sliver: SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [const Color(0xFF2FBE86).withValues(alpha: 0.85), theme.blueDeep]),
            ),
            child: Row(children: [
              const Icon(Icons.local_library_rounded, color: Colors.white, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('کتابخانه‌ی هزاره‌نامه', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text('${toFaDigits(all.length)} اثر • ${toFaDigits(downloadable)} قابل دانلود داخل اپ', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                ]),
              ),
            ]),
          ).animate().fadeIn(duration: 350.ms),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
        sliver: SliverToBoxAdapter(
          child: Wrap(spacing: 8, children: [
            for (final (k, l, ic) in const [('all', 'همه', Icons.apps_rounded), ('download', 'قابل دانلود', Icons.download_rounded), ('online', 'خواندن آنلاین', Icons.chrome_reader_mode_rounded)])
              ChoiceChip(
                selected: _filter == k,
                onSelected: (_) => setState(() => _filter = k),
                avatar: Icon(ic, size: 15, color: _filter == k ? Colors.white : theme.textSecondary),
                label: Text(l, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _filter == k ? Colors.white : theme.textSecondary)),
                selectedColor: theme.blue,
                backgroundColor: theme.bgCard.withValues(alpha: 0.6),
                side: BorderSide(color: theme.glassBorder),
                showCheckmark: false,
              ),
          ]),
        ),
      ),
      if (list.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('کتابی با این فیلتر پیدا نشد.', style: TextStyle(color: theme.textFaint, fontSize: 12.5))),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 12, childAspectRatio: 0.54),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _BookTile(theme: theme, item: list[i]).staggered(i),
              childCount: list.length,
            ),
          ),
        ),
    ]);
  }
}

class _BookTile extends StatelessWidget {
  final AppColors theme;
  final ContentItem item;
  const _BookTile({required this.theme, required this.item});

  @override
  Widget build(BuildContext context) {
    final dl = bookIsDownloadable(item);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookScreen(item: item))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Hero(
            tag: 'book-${item.id}',
            child: _BookCover(theme: theme, item: item, radius: 14),
          ),
        ),
        const SizedBox(height: 8),
        Text(_s(item, 'title'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.5)),
        const SizedBox(height: 2),
        Text(_s(item, 'author'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 11)),
        const SizedBox(height: 5),
        Row(children: [
          Icon(dl ? Icons.download_for_offline_rounded : (_s(item, 'read_url').isNotEmpty ? Icons.chrome_reader_mode_rounded : Icons.info_outline_rounded),
              size: 14, color: dl ? theme.success : theme.blue),
          const SizedBox(width: 4),
          Expanded(
            child: Text(dl ? 'دانلود داخل اپ' : (_s(item, 'read_url').isNotEmpty ? 'خواندن آنلاین' : 'معرفی اثر'),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dl ? theme.success : theme.blue, fontSize: 10.5, fontWeight: FontWeight.w800)),
          ),
          if (_s(item, 'year').isNotEmpty) Text(_s(item, 'year'), style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
        ]),
      ]),
    );
  }
}

/// جلد کتاب: عکس جلد اگر باشد، وگرنه یک جلد طراحی‌شده با عنوان
class _BookCover extends StatelessWidget {
  final AppColors theme;
  final ContentItem item;
  final double radius;
  const _BookCover({required this.theme, required this.item, required this.radius});

  static const _palettes = [
    [Color(0xFF223A85), Color(0xFF5B93FF)],
    [Color(0xFF1F6F5C), Color(0xFF2FBE86)],
    [Color(0xFF6B2E8F), Color(0xFFA06BFF)],
    [Color(0xFF8A3B12), Color(0xFFFF8A3D)],
    [Color(0xFF7A1F3D), Color(0xFFFF5C7A)],
  ];

  @override
  Widget build(BuildContext context) {
    final pal = _palettes[item.id.hashCode.abs() % _palettes.length];
    final img = item.imageUrl ?? '';
    final designed = Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: pal)),
      padding: const EdgeInsets.fromLTRB(12, 14, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 26, height: 3, color: Colors.white70),
        const SizedBox(height: 10),
        Expanded(
          child: Text(_s(item, 'title'), maxLines: 6, overflow: TextOverflow.fade, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900, height: 1.45)),
        ),
        Text(_s(item, 'author'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.4)),
      ]),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(fit: StackFit.expand, children: [
          designed,
          if (img.isNotEmpty) Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          // لبه‌ی عطف کتاب
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 7,
            child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent], begin: Alignment.centerRight, end: Alignment.centerLeft))),
          ),
        ]),
      ),
    );
  }
}

// =====================================================================
// صفحه‌ی یک کتاب: معرفی، مشخصات، دانلود داخل اپ، خواندن آنلاین
// =====================================================================
class BookScreen extends StatefulWidget {
  final ContentItem item;
  const BookScreen({super.key, required this.item});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  List<BookFile>? _files; // جلدهای قابل دانلود (از سرور)
  final Map<String, String> _local = {}; // نام جلد ← مسیر فایل روی دستگاه
  String? _busy; // نام جلدی که در حال دانلود است
  double _progress = 0;
  String? _error;

  ContentItem get it => widget.item;

  @override
  void initState() {
    super.initState();
    _scanLocal();
  }

  String _safe(String name) => name.replaceAll(RegExp(r'[^\w\u0600-\u06FF-]+'), '_');

  Future<Directory?> _dir() async {
    if (kIsWeb) return null;
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/books');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// جلدهایی که پیش‌تر دانلود شده‌اند
  Future<void> _scanLocal() async {
    final d = await _dir();
    if (d == null) return;
    final prefix = '${it.id}__';
    final found = <String, String>{};
    await for (final e in d.list()) {
      final n = e.uri.pathSegments.last;
      if (e is File && n.startsWith(prefix) && n.endsWith('.pdf') && await e.length() > 0) {
        found[Uri.decodeComponent(n.substring(prefix.length, n.length - 4))] = e.path;
      }
    }
    if (mounted) setState(() => _local..clear()..addAll(found));
  }

  Future<void> _onDownloadPressed() async {
    final app = context.read<AppState>();
    setState(() => _error = null);
    try {
      _files ??= await app.bookFiles(it.id);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      return;
    }
    final files = _files!;
    if (!mounted || files.isEmpty) return;
    if (files.length == 1) return _download(files.first);
    _pickVolume(files);
  }

  void _pickVolume(List<BookFile> files) {
    final theme = context.read<AppState>().colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          decoration: BoxDecoration(color: theme.bgElevated, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.glassBorder)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('کدام جلد را دانلود کنیم؟', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${toFaDigits(files.length)} فایل در دسترس است', style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: files.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final f = files[i];
                  final have = _local.containsKey(_safe(f.name));
                  return Material(
                    color: theme.bgCard.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      leading: Icon(have ? Icons.check_circle_rounded : Icons.picture_as_pdf_rounded, color: have ? theme.success : theme.danger),
                      title: Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: f.size != null ? Text(_mb(f.size!), style: TextStyle(color: theme.textFaint, fontSize: 11)) : null,
                      trailing: Icon(have ? Icons.menu_book_rounded : Icons.download_rounded, color: theme.blue),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        if (have) {
                          OpenFilex.open(_local[_safe(f.name)]!);
                        } else {
                          _download(f);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _mb(int bytes) => '${toFaDigits((bytes / 1048576).toStringAsFixed(1))} مگابایت';

  Future<void> _download(BookFile f) async {
    final app = context.read<AppState>();
    if (kIsWeb) {
      await launchUrl(Uri.parse(f.url), mode: LaunchMode.platformDefault);
      app.trackActivity('book', it.id);
      return;
    }
    setState(() {
      _busy = f.name;
      _progress = 0;
      _error = null;
    });
    final client = http.Client();
    try {
      final d = (await _dir())!;
      final file = File('${d.path}/${it.id}__${Uri.encodeComponent(_safe(f.name))}.pdf');
      final res = await client.send(http.Request('GET', Uri.parse(f.url)));
      if (res.statusCode != 200) throw 'سرور فایل پاسخ نداد (${res.statusCode}).';
      final total = res.contentLength ?? f.size ?? 0;
      final sink = file.openWrite();
      var got = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0 && mounted) setState(() => _progress = got / total);
      }
      await sink.close();
      app.trackActivity('book', it.id);
      if (!mounted) return;
      setState(() {
        _busy = null;
        _local[_safe(f.name)] = file.path;
      });
      await _scanLocal();
      if (!mounted) return;
      showHzToast(context, 'کتاب دانلود شد و روی دستگاه شما ذخیره است 📚');
      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = e is String ? e : 'دانلود ناموفق بود؛ اینترنت را بررسی کنید و دوباره امتحان کنید.';
      });
    } finally {
      client.close();
    }
  }

  Future<void> _deleteLocal(String name) async {
    final p = _local[name];
    if (p == null) return;
    try {
      await File(p).delete();
    } catch (_) {}
    if (mounted) setState(() => _local.remove(name));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final dl = bookIsDownloadable(it);
    final readUrl = _s(it, 'read_url');
    final buyUrl = _s(it, 'buy_url');
    final note = _s(it, 'note');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bg,
        body: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 330,
            backgroundColor: theme.bg,
            leading: IconButton(icon: Icon(Icons.arrow_forward_rounded, color: theme.textPrimary), onPressed: () => Navigator.of(context).pop()),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [theme.blueDeep.withValues(alpha: 0.6), theme.bg]),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60, bottom: 20),
                    child: AspectRatio(
                      aspectRatio: 0.68,
                      child: Hero(tag: 'book-${it.id}', child: _BookCover(theme: theme, item: it, radius: 12)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(_s(it, 'title'), textAlign: TextAlign.center, style: TextStyle(color: theme.textPrimary, fontSize: 19, fontWeight: FontWeight.w900, height: 1.6)),
                const SizedBox(height: 4),
                Text(_s(it, 'author'), textAlign: TextAlign.center, style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                const SizedBox(height: 12),
                Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                  if (_s(it, 'year').isNotEmpty) _InfoChip(theme: theme, icon: Icons.event_rounded, text: _s(it, 'year')),
                  if (_s(it, 'lang').isNotEmpty) _InfoChip(theme: theme, icon: Icons.translate_rounded, text: _s(it, 'lang')),
                  if (_s(it, 'tag').isNotEmpty) _InfoChip(theme: theme, icon: Icons.category_rounded, text: _s(it, 'tag')),
                  if (dl) _InfoChip(theme: theme, icon: Icons.verified_rounded, text: 'نسخه‌ی آزاد', color: theme.success),
                ]),
                const SizedBox(height: 18),
                // ---------- دکمه‌های اصلی ----------
                if (dl) ...[
                  if (_busy != null)
                    Column(children: [
                      Text(_busy!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(value: _progress == 0 ? null : _progress, minHeight: 9, backgroundColor: theme.bgCardAlt, color: theme.success),
                      ),
                      const SizedBox(height: 6),
                      Text(_progress == 0 ? 'در حال آماده‌سازی…' : 'در حال دانلود… ${toFaDigits((_progress * 100).round())}٪', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                    ])
                  else
                    _BigButton(
                      theme: theme,
                      icon: Icons.download_rounded,
                      label: _local.isEmpty ? (kIsWeb ? 'دانلود کتاب (PDF)' : 'دانلود داخل اپ (PDF)') : 'دانلود جلدهای دیگر',
                      color: theme.success,
                      outlined: _local.isNotEmpty,
                      onTap: _onDownloadPressed,
                    ),
                  if (_local.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final e in _local.entries)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                        decoration: BoxDecoration(color: theme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.success.withValues(alpha: 0.35))),
                        child: Row(children: [
                          Icon(Icons.check_circle_rounded, size: 18, color: theme.success),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.key.replaceAll('_', ' '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700))),
                          TextButton.icon(
                            onPressed: () => OpenFilex.open(e.value),
                            icon: Icon(Icons.menu_book_rounded, size: 16, color: theme.success),
                            label: Text('باز کردن', style: TextStyle(color: theme.success, fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                          IconButton(onPressed: () => _deleteLocal(e.key), tooltip: 'حذف از دستگاه', icon: Icon(Icons.delete_outline_rounded, size: 19, color: theme.danger)),
                        ]),
                      ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: theme.danger, fontSize: 12)),
                  ],
                  const SizedBox(height: 10),
                ],
                if (readUrl.startsWith('http')) ...[
                  _BigButton(
                    theme: theme,
                    icon: Icons.chrome_reader_mode_rounded,
                    label: _s(it, 'read_url_label').isNotEmpty ? _s(it, 'read_url_label') : 'خواندن آنلاین',
                    color: theme.blue,
                    outlined: dl,
                    onTap: () {
                      app.trackActivity('book', it.id);
                      openInApp(context, readUrl);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                if (buyUrl.startsWith('http'))
                  _BigButton(
                    theme: theme,
                    icon: Icons.travel_explore_rounded,
                    label: _s(it, 'buy_url_label').isNotEmpty ? _s(it, 'buy_url_label') : 'صفحه‌ی ناشر',
                    color: theme.aiViolet,
                    outlined: true,
                    onTap: () => openInApp(context, buyUrl),
                  ),
                if (!dl) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.glassBorder)),
                    child: Row(children: [
                      Icon(Icons.copyright_rounded, size: 16, color: theme.textFaint),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('این اثر حق نشر دارد؛ به احترام نویسنده فقط معرفی، خواندن آنلاین یا امانت دیجیتال از منبع رسمی ممکن است.',
                            style: TextStyle(color: theme.textFaint, fontSize: 11.5, height: 1.7)),
                      ),
                    ]),
                  ),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text('درباره‌ی این اثر', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  for (final para in note.split('\n\n'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(para, style: TextStyle(color: theme.textSecondary, fontSize: 13.5, height: 2.0)),
                    ),
                ],
                if (it.imageCredit.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(it.imageCredit, style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final AppColors theme;
  final IconData icon;
  final String text;
  final Color? color;
  const _InfoChip({required this.theme, required this.icon, required this.text, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? theme.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: c.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 5),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _BigButton extends StatelessWidget {
  final AppColors theme;
  final IconData icon;
  final String label;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;
  const _BigButton({required this.theme, required this.icon, required this.label, required this.color, required this.onTap, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    final style = outlined
        ? OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withValues(alpha: 0.6)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))
        : ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)));
    final child = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 18),
      const SizedBox(width: 8),
      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
    ]);
    return SizedBox(
      width: double.infinity,
      child: outlined ? OutlinedButton(onPressed: onTap, style: style, child: child) : ElevatedButton(onPressed: onTap, style: style, child: child),
    );
  }
}
