import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/widgets.dart';
import '../../data/sections.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../core/section_style.dart';

class ContentManagerPage extends StatefulWidget {
  final String sectionId;
  const ContentManagerPage({super.key, required this.sectionId});

  @override
  State<ContentManagerPage> createState() => _ContentManagerPageState();
}

class _ContentManagerPageState extends State<ContentManagerPage> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  String get sectionId => widget.sectionId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final section = sectionId == 'dailyStory'
        ? const ContentSection(id: 'dailyStory', title: 'روایت امروز', description: 'کارت‌های چرخشی صفحه‌ی نخست', group: '', kind: SectionKind.stories, fields: [
            ContentFieldSpec('date', 'برچسب تاریخ'), ContentFieldSpec('title', 'عنوان'),
            ContentFieldSpec('desc', 'توضیح کوتاه', multiline: true), ContentFieldSpec('full', 'متن کامل', multiline: true),
          ])
        : sectionById(sectionId);
    final all = app.content[sectionId] ?? [];
    final q = _q.text.trim().toLowerCase();
    final items = q.isEmpty ? all : all.where((it) => it.fields.values.whereType<String>().any((v) => v.toLowerCase().contains(q))).toList();
    final primaryKey = section.fields.isNotEmpty ? section.fields[0].key : null;
    final secondaryKey = section.fields.length > 1 ? section.fields[1].key : null;
    final st = sectionStyle(sectionId);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(gradient: st.gradient, borderRadius: BorderRadius.circular(14)),
            child: Icon(st.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(section.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
              Text('${all.length} مورد در پایگاه‌داده', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
            ]),
          ),
          if (sectionId != 'dailyStory')
            IconButton(
              tooltip: 'دیدن در اپ کاربران',
              icon: Icon(Icons.visibility_rounded, color: st.a),
              onPressed: () => Navigator.of(context).pushNamed('/section', arguments: sectionId),
            ),
          ElevatedButton.icon(
            onPressed: () => _openForm(context, app, section, null),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('افزودن', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(backgroundColor: st.b, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]),
      ),
      if (sectionId == 'language')
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: st.a.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: st.a.withValues(alpha: 0.3))),
          child: Text('به‌علاوه‌ی $kHazaragiGlossaryCount واژه‌ی واژه‌نامه‌ی محمد عوض نبی‌زاده که داخل خودِ اپ است و از این‌جا ویرایش نمی‌شود. واژه‌هایی که این‌جا می‌افزایید با دسته، آوانویسی و نمونه‌ی کاربرد در بالای واژه‌نامه نمایش داده می‌شوند.',
              style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.7)),
        ),
      if (all.length > 8)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: TextField(
            controller: _q,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: theme.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'جست‌وجو در موارد این بخش…',
              hintStyle: TextStyle(color: theme.textFaint, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: theme.textFaint, size: 19),
              isDense: true,
              filled: true,
              fillColor: theme.bgCard.withValues(alpha: 0.6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.glassBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.glassBorder)),
            ),
          ),
        ),
      const SizedBox(height: 6),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final item = items[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.glassBorder)),
              child: Row(children: [
                if ((item.imageUrl != null && item.imageUrl!.isNotEmpty) || (item.videoUrl != null && item.videoUrl!.isNotEmpty)) ...[
                  ContentMediaCover(item: item, height: 40, width: 40, radius: 10, fallback: const SizedBox.shrink()),
                  const SizedBox(width: 10),
                ],
                Container(width: 4, height: 34, decoration: BoxDecoration(color: st.a, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(primaryKey != null ? '${item[primaryKey] ?? ""}' : '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800)),
                    if (secondaryKey != null)
                      Text('${item[secondaryKey] ?? ""}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 12)),
                  ]),
                ),
                IconButton(icon: Icon(Icons.edit_rounded, size: 17, color: theme.blue), onPressed: () => _openForm(context, app, section, item)),
                IconButton(icon: Icon(Icons.delete_outline_rounded, size: 17, color: theme.danger), onPressed: () => _confirmDelete(context, app, section, item)),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  void _confirmDelete(BuildContext context, AppState app, ContentSection section, ContentItem item) {
    showDialog(context: context, builder: (ctx) {
      final theme = app.colors;
      return AlertDialog(
        backgroundColor: theme.bgElevated,
        title: Text('حذف شود؟', style: TextStyle(color: theme.textPrimary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('انصراف')),
          TextButton(
            onPressed: () { app.deleteContentItem(section.id, item.id); Navigator.of(ctx).pop(); showHzToast(context, 'مورد حذف شد'); },
            child: Text('حذف', style: TextStyle(color: theme.danger)),
          ),
        ],
      );
    });
  }

  void _openForm(BuildContext context, AppState app, ContentSection section, ContentItem? existing) {
    final controllers = {for (final f in section.fields) f.key: TextEditingController(text: existing != null ? '${existing[f.key] ?? ""}' : '')};
    final imageUrlController = TextEditingController(text: existing?.imageUrl ?? '');
    final videoUrlController = TextEditingController(text: existing?.videoUrl ?? '');
    final creditController = TextEditingController(text: existing?.imageCredit ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: app.colors.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        final theme = app.colors;
        bool uploading = false;
        return StatefulBuilder(builder: (ctx, setSheetState) {
          Future<void> pickAndUpload() async {
            final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
            if (picked == null) return;
            setSheetState(() => uploading = true);
            try {
              final url = await app.uploadContentImage(picked);
              imageUrlController.text = url;
              setSheetState(() {});
            } catch (_) {
              if (context.mounted) showHzToast(context, 'آپلود عکس ناموفق بود؛ دوباره تلاش کنید.');
            } finally {
              setSheetState(() => uploading = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(existing != null ? 'ویرایش' : 'افزودن مورد جدید', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const FlagStripe(width: 46),
                const SizedBox(height: 16),
                for (final f in section.fields) ...[
                  Text(f.label, style: TextStyle(color: theme.textFaint, fontSize: 12)),
                  const SizedBox(height: 5),
                  TextField(
                    controller: controllers[f.key],
                    maxLines: f.multiline ? 4 : 1,
                    style: TextStyle(color: theme.textPrimary, fontSize: 12.5),
                    decoration: InputDecoration(
                      filled: true, fillColor: theme.bgCard,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.border)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (section.id == 'library') ...[
                  OutlinedButton.icon(
                    onPressed: uploading
                        ? null
                        : () async {
                            final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'epub'], withData: kIsWeb);
                            final f = res?.files.single;
                            if (f == null) return;
                            final isEpub = (f.extension ?? '').toLowerCase() == 'epub';
                            final mime = isEpub ? 'application/epub+zip' : 'application/pdf';
                            final x = kIsWeb ? XFile.fromData(f.bytes!, name: f.name, mimeType: mime) : XFile(f.path!, name: f.name, mimeType: mime);
                            setSheetState(() => uploading = true);
                            try {
                              final url = await app.uploadContentFile(x, contentType: mime);
                              controllers['file_url']!.text = url;
                              if (context.mounted) showHzToast(context, 'فایل کتاب آپلود شد ✓');
                            } catch (_) {
                              if (context.mounted) showHzToast(context, 'آپلود فایل ناموفق بود؛ دوباره تلاش کنید.');
                            } finally {
                              setSheetState(() => uploading = false);
                            }
                          },
                    icon: Icon(Icons.upload_file_rounded, size: 16, color: theme.success),
                    label: Text(uploading ? 'در حال آپلود…' : 'آپلود فایل کتاب (PDF یا EPUB)', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(foregroundColor: theme.success, side: BorderSide(color: theme.success.withValues(alpha: 0.5)), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 6),
                  Text('فقط آثاری را آپلود کنید که آزاد (مالکیت عمومی) هستند یا اجازه‌ی نویسنده/ناشر را دارید.', style: TextStyle(color: theme.textFaint, fontSize: 11, height: 1.7)),
                  const SizedBox(height: 14),
                ],
                Text('عکس (اختیاری)', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                const SizedBox(height: 8),
                if (imageUrlController.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(imageUrlController.text.trim(), height: 110, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(height: 110, color: theme.bgCard, alignment: Alignment.center, child: Icon(Icons.broken_image_rounded, color: theme.textFaint)),
                      ),
                    ),
                  ),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: uploading ? null : pickAndUpload,
                      icon: uploading
                          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.blue))
                          : Icon(Icons.image_rounded, size: 16, color: theme.blue),
                      label: Text(uploading ? 'در حال آپلود…' : 'انتخاب عکس از گالری', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(foregroundColor: theme.blue, side: BorderSide(color: theme.border), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  if (imageUrlController.text.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setSheetState(() => imageUrlController.text = ''),
                      icon: Icon(Icons.close_rounded, size: 18, color: theme.danger),
                      tooltip: 'حذف عکس',
                    ),
                  ],
                ]),
                const SizedBox(height: 6),
                TextField(
                  controller: imageUrlController,
                  onChanged: (_) => setSheetState(() {}),
                  style: TextStyle(color: theme.textPrimary, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'یا لینک مستقیم عکس را اینجا بچسبانید',
                    hintStyle: TextStyle(color: theme.textFaint, fontSize: 12),
                    filled: true, fillColor: theme.bgCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.border)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: creditController,
                  style: TextStyle(color: theme.textPrimary, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'اعتبار عکس: نام عکاس / منبع و مجوز (مثلاً CC BY-SA 4.0)',
                    hintStyle: TextStyle(color: theme.textFaint, fontSize: 12),
                    filled: true, fillColor: theme.bgCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.border)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('لینک ویدیو (اختیاری — یوتیوب، آپارات و…)', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: videoUrlController,
                  style: TextStyle(color: theme.textPrimary, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'https://…',
                    hintStyle: TextStyle(color: theme.textFaint, fontSize: 12),
                    filled: true, fillColor: theme.bgCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.border)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // فیلدهای دیگر آیتم (اعتبار عکس، منبع، مختصات نقشه…) دست‌نخورده می‌مانند
                        final values = <String, dynamic>{
                          ...?existing?.fields,
                          for (final f in section.fields) f.key: controllers[f.key]!.text,
                          'img_credit': creditController.text.trim(),
                        };
                        final imageUrl = imageUrlController.text.trim();
                        final videoUrl = videoUrlController.text.trim();
                        if (existing != null) {
                          app.updateContentItem(section.id, existing.id, values, imageUrl: imageUrl, videoUrl: videoUrl);
                        } else {
                          app.addContentItem(section.id, values, imageUrl: imageUrl, videoUrl: videoUrl);
                        }
                        Navigator.of(ctx).pop();
                        showHzToast(context, existing != null ? 'مورد ویرایش شد' : 'مورد جدید افزوده شد');
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: theme.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('ذخیره', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(foregroundColor: theme.textSecondary, side: BorderSide(color: theme.border), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('انصراف', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        });
      },
    );
  }
}
