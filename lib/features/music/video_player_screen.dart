import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../core/youtube.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../community/post_widgets.dart' show showReportDialog;
import 'hz_video_player.dart';

/// صفحه‌ی پخش یک ویدیو — دقیقاً مثل یوتیوب: پلیر بالا، شمارنده‌ی بازدید،
/// نوار واکنش ایموجی، و پایین آن کامنت‌ها با قابلیت ریپلای.
class VideoPlayerScreen extends StatefulWidget {
  final ArtistVideo video;
  final String artistName;
  const VideoPlayerScreen({super.key, required this.video, required this.artistName});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late int _views;
  Map<String, int> _reactionCounts = {};
  Map<String, bool> _myReactions = {};
  List<VideoComment> _comments = [];
  bool _loadingComments = true;
  bool _loadingReactions = true;

  final _commentCtrl = TextEditingController();
  final Map<String, TextEditingController> _replyCtrls = {};
  String? _replyingTo;

  @override
  void initState() {
    super.initState();
    _views = widget.video.viewsCount;
    _loadReactions();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    for (final c in _replyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadReactions() async {
    setState(() => _loadingReactions = true);
    try {
      final data = await context.read<AppState>().fetchVideoReactions(widget.video.id);
      if (!mounted) return;
      setState(() {
        _reactionCounts = Map<String, int>.from(data['counts'] as Map);
        _myReactions = Map<String, bool>.from(data['mine'] as Map);
        _loadingReactions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingReactions = false);
    }
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final comments = await context.read<AppState>().fetchVideoComments(widget.video.id);
      if (!mounted) return;
      setState(() { _comments = comments; _loadingComments = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  void _onFirstPlay() {
    final app = context.read<AppState>();
    app.incrementVideoViews(widget.video.id);
    app.trackActivity('video', widget.video.id);
    setState(() => _views += 1);
  }

  Future<void> _toggleReaction(String emoji) async {
    final app = context.read<AppState>();
    if (app.currentUser == null) return;
    final mine = _myReactions[emoji] ?? false;
    setState(() {
      final current = _reactionCounts[emoji] ?? 0;
      final next = current + (mine ? -1 : 1);
      if (next <= 0) {
        _reactionCounts.remove(emoji);
      } else {
        _reactionCounts[emoji] = next;
      }
      _myReactions[emoji] = !mine;
    });
    await app.toggleVideoReaction(widget.video.id, emoji, mine);
  }

  Future<void> _submitComment({String? parentId}) async {
    final ctrl = parentId == null ? _commentCtrl : _replyCtrls[parentId]!;
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    final app = context.read<AppState>();
    if (app.currentUser == null) {
      showHzToast(context, 'برای ارسال نظر باید وارد حساب شوید.');
      return;
    }
    ctrl.clear();
    setState(() => _replyingTo = null);
    await app.addVideoComment(widget.video.id, text, parentId: parentId);
    if (app.myRankTier.index == kDonorTiers.last.index) {
      HapticFeedback.heavyImpact();
      if (mounted) showHzToast(context, '👑 کامنت شاهانه‌ات ارسال شد!');
    }
    _loadComments();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final video = widget.video;
    final totalComments = _comments.fold<int>(0, (s, c) => s + 1 + c.replies.length);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: AppBar(
                backgroundColor: theme.bgElevated.withValues(alpha: 0.5),
                elevation: 0,
                leading: IconButton(icon: Icon(Icons.arrow_forward, color: theme.textPrimary, size: 20), onPressed: () => Navigator.of(context).pop()),
                title: Text(widget.artistName, style: TextStyle(color: theme.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.5)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: youtubeId(video.videoUrl) != null
                      ? _YoutubeCard(theme: theme, url: video.videoUrl, id: youtubeId(video.videoUrl)!, thumbnailUrl: video.thumbnailUrl, onOpen: _onFirstPlay)
                      : HzVideoPlayer(videoUrl: video.videoUrl, thumbnailUrl: video.thumbnailUrl, theme: theme, onFirstPlay: _onFirstPlay),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(video.title, style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800, height: 1.5)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.visibility_outlined, size: 13, color: theme.textFaint),
                      const SizedBox(width: 4),
                      Text('$_views بازدید', style: TextStyle(color: theme.textFaint, fontSize: 12.5)),
                      const SizedBox(width: 8),
                      Text('·', style: TextStyle(color: theme.textFaint, fontSize: 12.5)),
                      const SizedBox(width: 8),
                      Text(video.createdAtLabel, style: TextStyle(color: theme.textFaint, fontSize: 12.5)),
                    ]),
                    if (video.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      HzGlassCard(
                        theme: theme,
                        radius: 14,
                        padding: const EdgeInsets.all(12),
                        child: Text(video.description, style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.8)),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (_loadingReactions)
                      const SizedBox(height: 34, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))))
                    else
                      Wrap(spacing: 8, runSpacing: 8, children: AppConstants.emojiChoices.map((e) {
                        final count = _reactionCounts[e] ?? 0;
                        final mine = _myReactions[e] ?? false;
                        return GestureDetector(
                          onTap: () => _toggleReaction(e),
                          child: AnimatedScale(
                            scale: mine ? 1.08 : 1.0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutBack,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                              decoration: BoxDecoration(
                                color: mine ? theme.blue.withValues(alpha: 0.14) : theme.bgCard.withValues(alpha: 0.45),
                                border: Border.all(color: mine ? theme.blue : theme.glassBorder),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(e, style: const TextStyle(fontSize: 14)),
                                if (count > 0) ...[
                                  const SizedBox(width: 5),
                                  Text('$count', style: TextStyle(fontSize: 12.5, color: mine ? theme.blue : theme.textSecondary, fontWeight: mine ? FontWeight.w700 : FontWeight.w500)),
                                ],
                              ]),
                            ),
                          ),
                        );
                      }).toList()),
                    const SizedBox(height: 20),
                    const FlagStripe(width: 44),
                    const SizedBox(height: 14),
                    Row(children: [
                      Icon(Icons.mode_comment_outlined, size: 15, color: theme.textSecondary),
                      const SizedBox(width: 6),
                      Text('$totalComments نظر', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 10),
                    _CommentComposer(
                      theme: theme, controller: _commentCtrl, onSend: () => _submitComment(),
                      myTier: app.myRankTier,
                    ),
                    const SizedBox(height: 16),
                    if (_loadingComments)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()))
                    else if (_comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text('اولین نفری باش که نظر می‌دهد', style: TextStyle(color: theme.textFaint, fontSize: 12.5))),
                      )
                    else
                      for (final c in pinTopTierComments<VideoComment>(_comments, (c) => app.donorTierForUserId(c.authorId))) ...[
                        _CommentTile(
                          theme: theme,
                          comment: c,
                          isReply: false,
                          replying: _replyingTo == c.id,
                          onReplyTap: () => setState(() => _replyingTo = _replyingTo == c.id ? null : c.id),
                          replyController: _replyCtrls.putIfAbsent(c.id, () => TextEditingController()),
                          onSendReply: () => _submitComment(parentId: c.id),
                        ),
                        for (final r in c.replies)
                          _CommentTile(theme: theme, comment: r, isReply: true),
                        const SizedBox(height: 12),
                      ],
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  final AppColors theme;
  final TextEditingController controller;
  final VoidCallback onSend;
  final DonorTier? myTier;
  const _CommentComposer({required this.theme, required this.controller, required this.onSend, this.myTier});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 3,
          style: TextStyle(color: theme.textPrimary, fontSize: 12.5),
          decoration: InputDecoration(
            hintText: 'نظرت را بنویس…',
            hintStyle: TextStyle(color: theme.textFaint, fontSize: 12),
            filled: true, fillColor: theme.bgCard.withValues(alpha: 0.4),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: theme.glassBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: theme.glassBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: theme.blue)),
          ),
        ),
      ),
      const SizedBox(width: 6),
      InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => showVipStickerPicker(
          context: context, theme: theme, myTier: myTier,
          baseChoices: AppConstants.emojiChoices,
          onPick: (e) => controller.text = '${controller.text}$e',
        ),
        child: Padding(padding: const EdgeInsets.all(9), child: Icon(Icons.emoji_emotions_outlined, size: 19, color: theme.textFaint)),
      ),
      const SizedBox(width: 4),
      InkWell(
        onTap: onSend,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(shape: BoxShape.circle, color: theme.blue),
          child: const Icon(Icons.send, size: 15, color: Colors.white),
        ),
      ),
    ]);
  }
}

class _CommentTile extends StatelessWidget {
  final AppColors theme;
  final VideoComment comment;
  final bool isReply;
  final bool replying;
  final VoidCallback? onReplyTap;
  final TextEditingController? replyController;
  final VoidCallback? onSendReply;

  const _CommentTile({
    required this.theme,
    required this.comment,
    required this.isReply,
    this.replying = false,
    this.onReplyTap,
    this.replyController,
    this.onSendReply,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tier = app.donorTierForUserId(comment.authorId);
    final isEmperor = tier?.index == kDonorTiers.last.index;
    Widget nameText = Text(comment.authorName,
        style: TextStyle(
          color: isEmperor ? tier!.colors.first : theme.textPrimary,
          fontSize: isEmperor ? 12.5 : 11.5,
          fontWeight: isEmperor ? FontWeight.w800 : FontWeight.w700,
        ));
    if (isEmperor) nameText = nameText.royalShimmer();
    return Padding(
      padding: EdgeInsets.only(right: isReply ? 34 : 0, top: isReply ? 10 : 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DonorRing(
          theme: theme, size: isReply ? 30 : 37, childSize: isReply ? 26 : 32,
          tier: tier,
          child: HzBadge(
            theme: theme, size: isReply ? 26 : 32, filled: true,
            avatarPath: comment.authorAvatar,
            child: Text(comment.authorName.isNotEmpty ? comment.authorName[0] : '؟', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: isReply ? 10.5 : 12)),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              nameText,
              if (tier?.tickColor != null) ...[
                const SizedBox(width: 4),
                DonorVipTick(color: tier!.tickColor!, size: 12),
              ],
              const SizedBox(width: 6),
              Text(comment.createdAtLabel, style: TextStyle(color: theme.textFaint, fontSize: 11)),
            ]),
            const SizedBox(height: 3),
            Text(comment.text, style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.7)),
            if (app.currentUser != null && comment.authorId != app.currentUser?.id)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: InkWell(
                  onTap: () => showReportDialog(context,
                      targetType: 'comment', targetId: comment.id,
                      targetOwnerId: comment.authorId, targetPreview: comment.text),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.flag_outlined, size: 13, color: theme.textFaint),
                      const SizedBox(width: 3),
                      Text('گزارش', style: TextStyle(color: theme.textFaint, fontSize: 11)),
                    ]),
                  ),
                ),
              ),
            if (!isReply) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: onReplyTap,
                child: Text('پاسخ', style: TextStyle(color: theme.blue, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              if (replying && replyController != null) ...[
                const SizedBox(height: 8),
                _CommentComposer(
                  theme: theme, controller: replyController!, onSend: onSendReply ?? () {},
                  myTier: app.myRankTier,
                ),
              ],
            ],
          ]),
        ),
      ]),
    );
  }
}


/// ویدیوی یوتیوب (از کانال رسمی هنرمند): تامبنیل با دکمه‌ی پخش که ویدیو را در یوتیوب باز می‌کند؛
/// بازدید و درآمد آن برای خود هنرمند ثبت می‌شود.
class _YoutubeCard extends StatelessWidget {
  final AppColors theme;
  final String url;
  final String id;
  final String? thumbnailUrl;
  final VoidCallback onOpen;
  const _YoutubeCard({required this.theme, required this.url, required this.id, required this.thumbnailUrl, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final thumb = (thumbnailUrl ?? '').isNotEmpty ? thumbnailUrl! : youtubeThumb(id);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Material(
          color: Colors.black,
          child: InkWell(
            onTap: () {
              onOpen();
              openContentUrl(context, url);
            },
            child: Stack(fit: StackFit.expand, children: [
              Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: theme.bgCard)),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xB3000000)]))),
              Center(
                child: Container(
                  width: 64,
                  height: 46,
                  decoration: BoxDecoration(color: const Color(0xFFFF0033), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                ),
              ),
              const PositionedDirectional(
                start: 12,
                bottom: 10,
                child: Row(children: [
                  Icon(Icons.open_in_new_rounded, size: 14, color: Colors.white70),
                  SizedBox(width: 5),
                  Text('پخش در یوتیوب', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
