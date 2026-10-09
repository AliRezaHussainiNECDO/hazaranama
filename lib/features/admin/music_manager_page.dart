import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

/// پنل مدیریت «موسیقی و شعر» — مدیر می‌تواند هنرمند بسازد/ویرایش/حذف کند،
/// و برای هر هنرمند ویدیو آپلود/ویرایش/حذف کند (فایل ویدیو + تامبنیل اختیاری).
class MusicManagerPage extends StatefulWidget {
  const MusicManagerPage({super.key});
  @override
  State<MusicManagerPage> createState() => _MusicManagerPageState();
}

class _MusicManagerPageState extends State<MusicManagerPage> {
  String? _activeArtistId;
  List<ArtistVideo> _videos = [];
  bool _loadingVideos = false;

  Future<void> _openArtist(String artistId) async {
    setState(() { _activeArtistId = artistId; _loadingVideos = true; _videos = []; });
    final videos = await context.read<AppState>().fetchArtistVideos(artistId);
    if (!mounted) return;
    setState(() { _videos = videos; _loadingVideos = false; });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;

    if (_activeArtistId != null) {
      final artist = app.artists.where((a) => a.id == _activeArtistId).cast<Artist?>().firstWhere((_) => true, orElse: () => null);
      if (artist == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _activeArtistId = null));
        return const SizedBox.shrink();
      }
      return _VideosManager(
        theme: theme,
        artist: artist,
        videos: _videos,
        loading: _loadingVideos,
        onBack: () => setState(() => _activeArtistId = null),
        onReload: () => _openArtist(artist.id),
      );
    }

    return _ArtistsManager(theme: theme, artists: app.artists, onOpenArtist: _openArtist);
  }
}

// =============================================================================
// مدیریت هنرمندان
// =============================================================================

class _ArtistsManager extends StatelessWidget {
  final AppColors theme;
  final List<Artist> artists;
  final void Function(String artistId) onOpenArtist;
  const _ArtistsManager({required this.theme, required this.artists, required this.onOpenArtist});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Row(children: [
          StatIconBox(icon: Icons.mic_external_on, color: theme.blue, size: 36),
          const SizedBox(width: 10),
          Expanded(child: Text('${artists.length} هنرمند', style: TextStyle(color: theme.textFaint, fontSize: 10.5))),
          ElevatedButton.icon(
            onPressed: () => _openArtistForm(context, app, null),
            icon: const Icon(Icons.add, size: 15),
            label: const Text('هنرمند تازه', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: theme.blue, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: artists.isEmpty
            ? Center(child: Text('هنوز هنرمندی افزوده نشده', style: TextStyle(color: theme.textFaint, fontSize: 12)))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount: artists.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final a = artists[i];
                  final hasAvatar = a.avatarUrl != null && a.avatarUrl!.isNotEmpty;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.glassBorder)),
                    child: Row(children: [
                      HzBadge(theme: theme, size: 40, filled: true, avatarPath: hasAvatar ? a.avatarUrl : null,
                        child: Text(a.name.isNotEmpty ? a.name[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => onOpenArtist(a.id),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                            Text('${a.videoCount} ویدیو — مدیریت ویدیوها', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.blue, fontSize: 10)),
                          ]),
                        ),
                      ),
                      IconButton(icon: Icon(Icons.edit_outlined, size: 17, color: theme.blue), onPressed: () => _openArtistForm(context, app, a)),
                      IconButton(icon: Icon(Icons.delete_outline, size: 17, color: theme.danger), onPressed: () => _confirmDeleteArtist(context, app, a)),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }

  void _confirmDeleteArtist(BuildContext context, AppState app, Artist a) {
    showDialog(context: context, builder: (ctx) {
      return AlertDialog(
        backgroundColor: theme.bgElevated,
        title: Text('حذف «${a.name}» و همه‌ی ویدیوهایش؟', style: TextStyle(color: theme.textPrimary, fontSize: 13.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('انصراف')),
          TextButton(
            onPressed: () { app.deleteArtist(a.id); Navigator.of(ctx).pop(); showHzToast(context, 'هنرمند حذف شد'); },
            child: Text('حذف', style: TextStyle(color: theme.danger)),
          ),
        ],
      );
    });
  }

  void _openArtistForm(BuildContext context, AppState app, Artist? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final bioCtrl = TextEditingController(text: existing?.bio ?? '');
    final avatarUrlCtrl = TextEditingController(text: existing?.avatarUrl ?? '');
    final coverUrlCtrl = TextEditingController(text: existing?.coverUrl ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        bool uploading = false;
        return StatefulBuilder(builder: (ctx, setSheetState) {
          Future<void> pickAvatar() async {
            final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
            if (picked == null) return;
            setSheetState(() => uploading = true);
            try {
              final url = await app.uploadArtistImage(picked);
              avatarUrlCtrl.text = url;
            } catch (_) {
              if (context.mounted) showHzToast(context, 'آپلود ناموفق بود.');
            } finally {
              setSheetState(() => uploading = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(existing != null ? 'ویرایش هنرمند' : 'هنرمند تازه', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const FlagStripe(width: 46),
                const SizedBox(height: 16),
                if (avatarUrlCtrl.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Center(
                      child: ClipOval(child: Image.network(avatarUrlCtrl.text.trim(), width: 74, height: 74, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 74, height: 74, color: theme.bgCard))),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: uploading ? null : pickAvatar,
                  icon: uploading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.image_outlined, size: 16),
                  label: Text(uploading ? 'در حال آپلود…' : 'انتخاب آواتار از گالری', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(foregroundColor: theme.blue, side: BorderSide(color: theme.border), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                _label(theme, 'نام هنرمند'),
                _field(theme, nameCtrl, hint: 'مثلاً: داوود سرخوش'),
                const SizedBox(height: 12),
                _label(theme, 'بیوگرافی کوتاه (اختیاری)'),
                _field(theme, bioCtrl, hint: 'چند خط درباره‌ی هنرمند…', maxLines: 3),
                const SizedBox(height: 12),
                _label(theme, 'لینک عکس کاور (اختیاری)'),
                _field(theme, coverUrlCtrl, hint: 'https://…'),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) {
                          showHzToast(context, 'نام هنرمند را وارد کنید.');
                          return;
                        }
                        if (existing != null) {
                          app.updateArtist(existing.id, name: nameCtrl.text.trim(), bio: bioCtrl.text.trim(), avatarUrl: avatarUrlCtrl.text.trim(), coverUrl: coverUrlCtrl.text.trim());
                        } else {
                          app.addArtist(nameCtrl.text.trim(), bio: bioCtrl.text.trim(), avatarUrl: avatarUrlCtrl.text.trim(), coverUrl: coverUrlCtrl.text.trim());
                        }
                        Navigator.of(ctx).pop();
                        showHzToast(context, existing != null ? 'هنرمند ویرایش شد' : 'هنرمند افزوده شد');
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

// =============================================================================
// مدیریت ویدیوهای یک هنرمند
// =============================================================================

class _VideosManager extends StatelessWidget {
  final AppColors theme;
  final Artist artist;
  final List<ArtistVideo> videos;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onReload;
  const _VideosManager({required this.theme, required this.artist, required this.videos, required this.loading, required this.onBack, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 16, 4),
        child: Row(children: [
          IconButton(icon: Icon(Icons.arrow_forward, color: theme.textPrimary, size: 18), onPressed: onBack),
          HzBadge(theme: theme, size: 34, filled: true, avatarPath: artist.avatarUrl,
            child: Text(artist.name.isNotEmpty ? artist.name[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(child: Text('ویدیوهای ${artist.name}', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ElevatedButton.icon(
            onPressed: () => _openVideoForm(context, app, artist.id, null),
            icon: const Icon(Icons.upload_outlined, size: 14),
            label: const Text('ویدیو تازه', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: theme.blue, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : videos.isEmpty
                ? Center(child: Text('هنوز ویدیویی افزوده نشده', style: TextStyle(color: theme.textFaint, fontSize: 12)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: videos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final v = videos[i];
                      final hasThumb = v.thumbnailUrl != null && v.thumbnailUrl!.isNotEmpty;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.glassBorder)),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: hasThumb
                                ? Image.network(v.thumbnailUrl!, width: 54, height: 40, fit: BoxFit.cover)
                                : Container(width: 54, height: 40, color: theme.bgCardAlt, child: Icon(Icons.music_note, size: 16, color: theme.textFaint)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                              Text('${v.viewsCount} بازدید', style: TextStyle(color: theme.textFaint, fontSize: 10)),
                            ]),
                          ),
                          IconButton(icon: Icon(Icons.edit_outlined, size: 16, color: theme.blue), onPressed: () => _openVideoForm(context, app, artist.id, v)),
                          IconButton(icon: Icon(Icons.delete_outline, size: 16, color: theme.danger), onPressed: () => _confirmDeleteVideo(context, app, v)),
                        ]),
                      );
                    },
                  ),
      ),
    ]);
  }

  void _confirmDeleteVideo(BuildContext context, AppState app, ArtistVideo v) {
    showDialog(context: context, builder: (ctx) {
      return AlertDialog(
        backgroundColor: theme.bgElevated,
        title: Text('حذف «${v.title}»؟', style: TextStyle(color: theme.textPrimary, fontSize: 13.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('انصراف')),
          TextButton(
            onPressed: () async { await app.deleteVideo(v.id, artist.id); if (ctx.mounted) Navigator.of(ctx).pop(); onReload(); if (context.mounted) showHzToast(context, 'ویدیو حذف شد'); },
            child: Text('حذف', style: TextStyle(color: theme.danger)),
          ),
        ],
      );
    });
  }

  void _openVideoForm(BuildContext context, AppState app, String artistId, ArtistVideo? existing) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final videoUrlCtrl = TextEditingController(text: existing?.videoUrl ?? '');
    final thumbUrlCtrl = TextEditingController(text: existing?.thumbnailUrl ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        bool uploadingVideo = false;
        bool uploadingThumb = false;
        return StatefulBuilder(builder: (ctx, setSheetState) {
          Future<void> pickVideo() async {
            final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
            if (picked == null) return;
            setSheetState(() => uploadingVideo = true);
            try {
              final url = await app.uploadArtistVideoFile(picked);
              videoUrlCtrl.text = url;
            } catch (_) {
              if (context.mounted) showHzToast(context, 'آپلود ویدیو ناموفق بود؛ حجم فایل را بررسی کنید.');
            } finally {
              setSheetState(() => uploadingVideo = false);
            }
          }

          Future<void> pickThumb() async {
            final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
            if (picked == null) return;
            setSheetState(() => uploadingThumb = true);
            try {
              final url = await app.uploadArtistImage(picked);
              thumbUrlCtrl.text = url;
            } catch (_) {
              if (context.mounted) showHzToast(context, 'آپلود تامبنیل ناموفق بود.');
            } finally {
              setSheetState(() => uploadingThumb = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(existing != null ? 'ویرایش ویدیو' : 'ویدیوی تازه', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const FlagStripe(width: 46),
                const SizedBox(height: 16),
                _label(theme, 'عنوان'),
                _field(theme, titleCtrl, hint: 'عنوان ویدیو یا آهنگ'),
                const SizedBox(height: 12),
                _label(theme, 'توضیح (اختیاری)'),
                _field(theme, descCtrl, hint: 'توضیح کوتاه…', maxLines: 3),
                const SizedBox(height: 14),
                _label(theme, 'فایل ویدیو'),
                const SizedBox(height: 6),
                if (videoUrlCtrl.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Icon(Icons.check_circle, size: 14, color: theme.success),
                      const SizedBox(width: 6),
                      Expanded(child: Text('فایل ویدیو انتخاب شد', style: TextStyle(color: theme.success, fontSize: 11))),
                    ]),
                  ),
                OutlinedButton.icon(
                  onPressed: uploadingVideo ? null : pickVideo,
                  icon: uploadingVideo ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.video_file_outlined, size: 16),
                  label: Text(uploadingVideo ? 'در حال آپلود ویدیو…' : 'انتخاب فایل ویدیو از گالری', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(foregroundColor: theme.blue, side: BorderSide(color: theme.border), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 14),
                _label(theme, 'تامبنیل (اختیاری)'),
                const SizedBox(height: 6),
                if (thumbUrlCtrl.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(thumbUrlCtrl.text.trim(), height: 90, width: double.infinity, fit: BoxFit.cover)),
                  ),
                OutlinedButton.icon(
                  onPressed: uploadingThumb ? null : pickThumb,
                  icon: uploadingThumb ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.image_outlined, size: 16),
                  label: Text(uploadingThumb ? 'در حال آپلود…' : 'انتخاب تامبنیل از گالری', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(foregroundColor: theme.blue, side: BorderSide(color: theme.border), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleCtrl.text.trim().isEmpty) {
                          showHzToast(context, 'عنوان را وارد کنید.');
                          return;
                        }
                        if (videoUrlCtrl.text.trim().isEmpty) {
                          showHzToast(context, 'ابتدا فایل ویدیو را آپلود کنید.');
                          return;
                        }
                        if (existing != null) {
                          await app.updateVideo(existing.id, title: titleCtrl.text.trim(), description: descCtrl.text.trim(), thumbnailUrl: thumbUrlCtrl.text.trim());
                        } else {
                          await app.addVideo(artistId, title: titleCtrl.text.trim(), description: descCtrl.text.trim(), videoUrl: videoUrlCtrl.text.trim(), thumbnailUrl: thumbUrlCtrl.text.trim());
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        onReload();
                        if (context.mounted) showHzToast(context, existing != null ? 'ویدیو ویرایش شد' : 'ویدیو افزوده شد');
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

Widget _label(theme, String text) => Text(text, style: TextStyle(color: theme.textFaint, fontSize: 10.5));

Widget _field(theme, TextEditingController ctrl, {String hint = '', int maxLines = 1}) {
  return Padding(
    padding: const EdgeInsets.only(top: 5),
    child: TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(color: theme.textPrimary, fontSize: 12.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textFaint, fontSize: 11.5),
        filled: true, fillColor: theme.bgCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.border)),
      ),
    ),
  );
}
