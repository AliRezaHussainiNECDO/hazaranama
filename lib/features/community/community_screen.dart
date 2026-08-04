import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../state/app_state.dart';
import 'post_widgets.dart';

/// فید «حافظه‌ی جمعی» — به‌سبک اینستاگرام/فیسبوک: پست متنی/عکسی/ویدیویی،
/// اسکرول بی‌نهایت، پول‌تودریفرش، لایک، ایموجی، و نظر/ریپلای.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _text = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<String> _imageUrls = [];
  String? _videoUrl;
  bool _uploadingImages = false;
  bool _uploadingVideo = false;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _text.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels > _scrollCtrl.position.maxScrollExtent - 500) {
      context.read<AppState>().loadMorePosts();
    }
  }

  Future<void> _pickImages(AppState app) async {
    if (_videoUrl != null) {
      showHzToast(context, 'یا عکس بگذار یا ویدیو — هر پست فقط یکی از این‌دو.');
      return;
    }
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() => _uploadingImages = true);
    try {
      for (final f in picked) {
        if (_imageUrls.length >= 6) break;
        final url = await app.uploadPostImage(File(f.path));
        _imageUrls.add(url);
      }
    } catch (_) {
      if (mounted) showHzToast(context, 'آپلود عکس ناموفق بود.');
    } finally {
      if (mounted) setState(() => _uploadingImages = false);
    }
  }

  Future<void> _pickVideo(AppState app) async {
    if (_imageUrls.isNotEmpty) {
      showHzToast(context, 'یا عکس بگذار یا ویدیو — هر پست فقط یکی از این‌دو.');
      return;
    }
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _uploadingVideo = true);
    try {
      final url = await app.uploadPostVideo(File(picked.path));
      setState(() => _videoUrl = url);
    } catch (_) {
      if (mounted) showHzToast(context, 'آپلود ویدیو ناموفق بود.');
    } finally {
      if (mounted) setState(() => _uploadingVideo = false);
    }
  }

  Future<void> _publish(AppState app) async {
    final text = _text.text.trim();
    if (text.isEmpty && _imageUrls.isEmpty && _videoUrl == null) return;
    setState(() => _publishing = true);
    try {
      await app.publishPost(text: text, imageUrls: List.of(_imageUrls), videoUrl: _videoUrl);
      _text.clear();
      setState(() {
        _imageUrls.clear();
        _videoUrl = null;
      });
      if (mounted) showHzToast(context, 'پست شما منتشر شد');
    } catch (_) {
      if (mounted) showHzToast(context, 'انتشار پست ناموفق بود.');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;

    return RefreshIndicator(
      onRefresh: app.loadPosts,
      child: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          Text('حافظه‌ی جمعی', style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'روایت‌ها، خاطره‌ها و لحظه‌های تصویری‌ای که نسل‌ها را به‌هم پیوند می‌زنند — عکس و ویدیو بگذار، لایک کن، نظر بده.',
            style: TextStyle(color: theme.textFaint, fontSize: 11.5, height: 1.8),
          ),
          const SizedBox(height: 14),
          _buildComposer(app, theme),
          const SizedBox(height: 20),
          if (app.posts.isEmpty)
            _EmptyFeed(theme: theme)
          else
            for (final (i, post) in app.posts.indexed) ...[
              PostCard(post: post, onTap: () => Navigator.of(context).pushNamed('/post', arguments: post.id)).staggered(i),
              const SizedBox(height: 14),
            ],
          if (app.postsLoadingMore)
            const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4))),
        ],
      ),
    );
  }

  Widget _buildComposer(AppState app, AppColors theme) {
    final canPublish = !_publishing && !_uploadingImages && !_uploadingVideo &&
        (_text.text.trim().isNotEmpty || _imageUrls.isNotEmpty || _videoUrl != null);

    return HzGlassCard(
      theme: theme,
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DonorRing(
            theme: theme, size: 44, childSize: 38,
            tier: donorTierForUser(app.currentUser, app.myDonationTotalUsd),
            child: HzBadge(theme: theme, size: 38, filled: true, avatarPath: app.avatarPath,
              child: const Icon(Icons.person, color: Colors.white, size: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _text,
              maxLines: 4,
              minLines: 1,
              style: TextStyle(color: theme.textPrimary, fontSize: 12.5),
              decoration: InputDecoration.collapsed(
                hintText: 'خاطره یا روایتی از خانواده، بزرگان یا زادگاهت بنویس…',
                hintStyle: TextStyle(color: theme.textFaint, fontSize: 12.5),
              ),
            ),
          ),
        ]),
        if (_imageUrls.isNotEmpty || _uploadingImages) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 74,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final url in _imageUrls)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(url, width: 74, height: 74, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 74, height: 74, color: theme.bgCardAlt)),
                      ),
                      Positioned(
                        top: 3, left: 3,
                        child: GestureDetector(
                          onTap: () => setState(() => _imageUrls.remove(url)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(color: theme.danger, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ]),
                  ),
                if (_uploadingImages)
                  Container(
                    width: 74, height: 74,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: theme.bgCardAlt, borderRadius: BorderRadius.circular(12)),
                    child: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
              ],
            ),
          ),
        ],
        if (_videoUrl != null || _uploadingVideo) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: theme.bgCardAlt, borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.border)),
            child: Row(children: [
              if (_uploadingVideo)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Icons.videocam_rounded, size: 18, color: theme.success),
              const SizedBox(width: 8),
              Expanded(child: Text(_uploadingVideo ? 'در حال آپلود ویدیو…' : 'یک ویدیو افزوده شد', style: TextStyle(color: theme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600))),
              if (_videoUrl != null)
                GestureDetector(
                  onTap: () => setState(() => _videoUrl = null),
                  child: Icon(Icons.close, size: 16, color: theme.danger),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        const FlagStripe(height: 2),
        const SizedBox(height: 10),
        Row(children: [
          IconButton(
            onPressed: _uploadingImages ? null : () => _pickImages(app),
            icon: Icon(Icons.add_photo_alternate_outlined, color: theme.success, size: 21),
            tooltip: 'افزودن عکس',
          ),
          IconButton(
            onPressed: _uploadingVideo ? null : () => _pickVideo(app),
            icon: Icon(Icons.videocam_outlined, color: theme.success, size: 21),
            tooltip: 'افزودن ویدیو',
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: canPublish ? () => _publish(app) : null,
            icon: _publishing
                ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 14),
            label: Text(_publishing ? 'در حال انتشار…' : 'انتشار', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.blue, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              elevation: 0,
            ),
          ),
        ]),
      ]),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0);
  }
}

class _EmptyFeed extends StatelessWidget {
  final AppColors theme;
  const _EmptyFeed({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.glassBorder)),
      child: Column(children: [
        Icon(Icons.photo_camera_back_outlined, size: 34, color: theme.textFaint),
        const SizedBox(height: 10),
        Text('هنوز پستی نیست', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('اولین خاطره یا عکس را تو به اشتراک بگذار.', style: TextStyle(color: theme.textFaint, fontSize: 11, height: 1.7), textAlign: TextAlign.center),
      ]),
    ).animate().fadeIn(duration: 350.ms);
  }
}
