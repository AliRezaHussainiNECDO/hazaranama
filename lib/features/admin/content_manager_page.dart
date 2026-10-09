import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/widgets.dart';
import '../../data/sections.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import 'admin_shell.dart';

class ContentManagerPage extends StatelessWidget {
  final String sectionId;
  const ContentManagerPage({super.key, required this.sectionId});

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
    final items = app.content[sectionId] ?? [];
    final primaryKey = section.fields.isNotEmpty ? section.fields[0].key : null;
    final secondaryKey = section.fields.length > 1 ? section.fields[1].key : null;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Row(children: [
          StatIconBox(icon: sectionId == 'dailyStory' ? Icons.auto_awesome : iconForSectionId(sectionId), color: theme.blue, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${items.length} مورد', style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: () => _openForm(context, app, section, null),
            icon: const Icon(Icons.add, size: 15),
            label: const Text('افزودن مورد جدید', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: theme.blue, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]),
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
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(primaryKey != null ? '${item[primaryKey] ?? ""}' : '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                    if (secondaryKey != null)
                      Text('${item[secondaryKey] ?? ""}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
                  ]),
                ),
                IconButton(icon: Icon(Icons.edit_outlined, size: 17, color: theme.blue), onPressed: () => _openForm(context, app, section, item)),
                IconButton(icon: Icon(Icons.delete_outline, size: 17, color: theme.danger), onPressed: () => _confirmDelete(context, app, section, item)),
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
                  Text(f.label, style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
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
                Text('عکس (اختیاری)', style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
                const SizedBox(height: 8),
                if (imageUrlController.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(imageUrlController.text.trim(), height: 110, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(height: 110, color: theme.bgCard, alignment: Alignment.center, child: Icon(Icons.broken_image_outlined, color: theme.textFaint)),
                      ),
                    ),
                  ),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: uploading ? null : pickAndUpload,
                      icon: uploading
                          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.blue))
                          : Icon(Icons.image_outlined, size: 16, color: theme.blue),
                      label: Text(uploading ? 'در حال آپلود…' : 'انتخاب عکس از گالری', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(foregroundColor: theme.blue, side: BorderSide(color: theme.border), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  if (imageUrlController.text.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setSheetState(() => imageUrlController.text = ''),
                      icon: Icon(Icons.close, size: 18, color: theme.danger),
                      tooltip: 'حذف عکس',
                    ),
                  ],
                ]),
                const SizedBox(height: 6),
                TextField(
                  controller: imageUrlController,
                  onChanged: (_) => setSheetState(() {}),
                  style: TextStyle(color: theme.textPrimary, fontSize: 11.5),
                  decoration: InputDecoration(
                    hintText: 'یا لینک مستقیم عکس را اینجا بچسبانید',
                    hintStyle: TextStyle(color: theme.textFaint, fontSize: 10.5),
                    filled: true, fillColor: theme.bgCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.border)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('لینک ویدیو (اختیاری — یوتیوب، آپارات و…)', style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
                const SizedBox(height: 8),
                TextField(
                  controller: videoUrlController,
                  style: TextStyle(color: theme.textPrimary, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'https://…',
                    hintStyle: TextStyle(color: theme.textFaint, fontSize: 10.5),
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
                        final values = {for (final f in section.fields) f.key: controllers[f.key]!.text};
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
