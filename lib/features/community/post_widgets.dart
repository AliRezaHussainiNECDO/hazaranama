import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../music/hz_video_player.dart';

const _kLikeColor = Color(0xFFE0245E);

/// یک کارت پست در فید «حافظه‌ی جمعی» — دقیقاً به‌سبک اینستاگرام/فیسبوک: هدر
/// نویسنده با آواتار واقعی، متن، گالری عکس (چندتایی، قابل swipe) یا ویدیو،
/// دابل‌تپ برای لایک سریع با انیمیشن قلب، نوار واکنش کامل ایموجی، و شمارنده‌ی نظر.
class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback onTap;
  const PostCard({super.key, required this.post, required this.onTap});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _showBigHeart = false;

  void _quickLike(AppState app) {
    final post = widget.post;
    final wasLiked = post.likedByMe;
    app.toggleReaction(post.id, '❤️');
    if (!wasLiked) {
      setState(() => _showBigHeart = true);
      Future.delayed(const Duration(milliseconds: 750), () {
        if (mounted) setState(() => _showBigHeart = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final post = widget.post;
    final isMine = post.authorId == app.currentUser?.id;

    return Container(
      decoration: BoxDecoration(
        color: theme.bgCard.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
          child: Row(children: [
            DonorRing(
              theme: theme, size: 44, childSize: 38, tier: app.donorTierForUserId(post.authorId),
              child: HzBadge(
                theme: theme, size: 38, filled: true, avatarPath: post.authorAvatar,
                child: Text(post.authorInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(post.authorName, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700))),
                  if (app.donorTierForUserId(post.authorId)?.tickColor != null) ...[
                    const SizedBox(width: 4),
                    DonorVipTick(color: app.donorTierForUserId(post.authorId)!.tickColor!),
                  ],
                ]),
                Text(post.createdAtLabel, style: TextStyle(color: theme.textFaint, fontSize: 10)),
              ]),
            ),
            if (isMine)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: theme.textFaint, size: 19),
                color: theme.bgElevated,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (v) {
                  if (v == 'delete') _confirmDelete(context, app, post.id);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'delete', child: Text('حذف پست', style: TextStyle(color: theme.danger, fontSize: 12, fontWeight: FontWeight.w600))),
                ],
              ),
          ]),
        ),
        if (post.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(post.text, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.85)),
          ),
        if (post.hasMedia)
          GestureDetector(
            onDoubleTap: () => _quickLike(app),
            child: Stack(alignment: Alignment.center, children: [
              _PostMediaGallery(post: post, theme: theme),
              IgnorePointer(
                child: AnimatedScale(
                  scale: _showBigHeart ? 1 : 0,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.elasticOut,
                  child: const Icon(Icons.favorite, color: Colors.white, size: 86, shadows: [Shadow(blurRadius: 20, color: Colors.black45)]),
                ),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _LikeButton(theme: theme, liked: post.likedByMe, onTap: () => _quickLike(app)),
              const SizedBox(width: 2),
              _MoreReactionsButton(theme: theme, post: post, app: app),
              const Spacer(),
              InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.mode_comment_outlined, size: 16, color: theme.textFaint),
                    const SizedBox(width: 5),
                    Text('${post.commentsCount}', style: TextStyle(color: theme.textFaint, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
            if (post.totalReactions > 0) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4, runSpacing: 4,
                children: post.reactions.entries.where((e) => e.value > 0).map((e) {
                  final mine = post.myReactions[e.key] ?? false;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: mine ? theme.blue.withValues(alpha: 0.12) : theme.bgCardAlt,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: mine ? theme.blue : theme.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(e.key, style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 3),
                      Text('${e.value}', style: TextStyle(fontSize: 10, color: mine ? theme.blue : theme.textFaint, fontWeight: FontWeight.w600)),
                    ]),
                  );
                }).toList(),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  void _confirmDelete(BuildContext context, AppState app, String postId) {
    final theme = app.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.bgElevated,
        title: Text('این پست حذف شود؟', style: TextStyle(color: theme.textPrimary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('انصراف')),
          TextButton(
            onPressed: () {
              app.deletePost(postId);
              Navigator.of(ctx).pop();
              showHzToast(context, 'پست حذف شد');
            },
            child: Text('حذف', style: TextStyle(color: theme.danger)),
          ),
        ],
      ),
    );
  }
}

/// دکمه‌ی «لایک» سریع (قلب) — دقیقاً معادل دکمه‌ی لایک اینستاگرام/فیسبوک؛
/// از نظر داده همان واکنش ایموجی ❤️ روی پست است.
class _LikeButton extends StatelessWidget {
  final AppColors theme;
  final bool liked;
  final VoidCallback onTap;
  const _LikeButton({required this.theme, required this.liked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: AnimatedScale(
          scale: liked ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(liked ? Icons.favorite : Icons.favorite_border, size: 19, color: liked ? _kLikeColor : theme.textFaint),
            const SizedBox(width: 5),
            Text('لایک', style: TextStyle(fontSize: 11.5, color: liked ? _kLikeColor : theme.textFaint, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

/// دکمه‌ی «واکنش‌های بیشتر» — نوار کامل ایموجی‌ها را در یک شیت پایین باز می‌کند.
class _MoreReactionsButton extends StatelessWidget {
  final AppColors theme;
  final Post post;
  final AppState app;
  const _MoreReactionsButton({required this.theme, required this.post, required this.app});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _openPicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(Icons.add_reaction_outlined, size: 18, color: theme.textFaint),
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showVipStickerPicker(
      context: context,
      theme: theme,
      myTier: donorTierForUser(app.currentUser, app.myDonationTotalUsd),
      baseChoices: AppConstants.emojiChoices,
      onPick: (e) => app.toggleReaction(post.id, e),
    );
  }
}

/// گالری رسانه‌ی یک پست — چند عکس با swipe و نقطه‌های شمارنده، یا یک ویدیوی
/// قابل‌پخش (با پلیر سفارشی اپ).
class _PostMediaGallery extends StatefulWidget {
  final Post post;
  final AppColors theme;
  const _PostMediaGallery({required this.post, required this.theme});

  @override
  State<_PostMediaGallery> createState() => _PostMediaGalleryState();
}

class _PostMediaGalleryState extends State<_PostMediaGallery> {
  final _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final theme = widget.theme;

    if (post.hasVideo) {
      return HzVideoPlayer(videoUrl: post.videoUrl!, thumbnailUrl: post.videoThumbnailUrl, theme: theme);
    }

    if (post.imageUrls.length == 1) {
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: Image.network(post.imageUrls.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: theme.bgCardAlt)),
      );
    }

    return Stack(alignment: Alignment.bottomCenter, children: [
      AspectRatio(
        aspectRatio: 4 / 5,
        child: PageView.builder(
          controller: _pageCtrl,
          onPageChanged: (i) => setState(() => _page = i),
          itemCount: post.imageUrls.length,
          itemBuilder: (_, i) => Image.network(post.imageUrls[i], fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: theme.bgCardAlt)),
        ),
      ),
      Positioned(
        top: 10, left: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(999)),
          child: Text('${_page + 1}/${post.imageUrls.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(post.imageUrls.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: active ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(color: active ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(999)),
            );
          }),
        ),
      ),
    ]);
  }
}

/// صفحه‌ی جزئیات یک پست — کارت پست + نظرهای تودرتو (ریپلای یک‌سطحی) با
/// لایک روی هر نظر، دقیقاً هم‌خانواده‌ی صفحه‌ی نظرهای ویدیو/مقاله‌ی برگزیده.
class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  List<PostComment> _comments = [];
  bool _loading = true;
  final _commentCtrl = TextEditingController();
  final Map<String, TextEditingController> _replyCtrls = {};
  String? _replyingTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    for (final c in _replyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final comments = await context.read<AppState>().fetchPostComments(widget.postId);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit({String? parentId}) async {
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
    await app.addPostComment(widget.postId, text, parentId: parentId);
    if (donorTierForUser(app.currentUser, app.myDonationTotalUsd)?.index == kDonorTiers.last.index) {
      HapticFeedback.heavyImpact();
      if (mounted) showHzToast(context, '👑 کامنت شاهانه‌ات ارسال شد!');
    }
    _load();
  }

  Future<void> _toggleLike(PostComment c) async {
    final app = context.read<AppState>();
    if (app.currentUser == null) return;
    final wasLiked = c.likedByMe;
    setState(() {
      c.likeCount += wasLiked ? -1 : 1;
      c.likedByMe = !wasLiked;
    });
    await app.togglePostCommentLike(c.id, wasLiked);
  }

  void _confirmDeleteComment(BuildContext context, AppState app, String commentId) {
    final theme = app.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.bgElevated,
        title: Text('این نظر حذف شود؟', style: TextStyle(color: theme.textPrimary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('انصراف')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await app.deletePostComment(commentId, widget.postId);
              _load();
            },
            child: Text('حذف', style: TextStyle(color: theme.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final post = app.posts.where((p) => p.id == widget.postId).cast<Post?>().firstWhere((_) => true, orElse: () => null);

    if (post == null) {
      return Directionality(textDirection: TextDirection.rtl, child: Scaffold(backgroundColor: theme.bg, body: const SizedBox()));
    }

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
                backgroundColor: theme.bgElevated.withValues(alpha: 0.5), elevation: 0,
                leading: IconButton(icon: Icon(Icons.arrow_forward, color: theme.textPrimary, size: 20), onPressed: () => Navigator.of(context).pop()),
                title: Text('پست', style: TextStyle(color: theme.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.6)),
          SafeArea(
            child: Column(children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: [
                      PostCard(post: post, onTap: () {}),
                      const SizedBox(height: 18),
                      Text('نظرها (${post.commentsCount})', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      if (_loading)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
                      else if (_comments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text('اولین نفری باش که نظر می‌دهد', style: TextStyle(color: theme.textFaint, fontSize: 11.5))),
                        )
                      else
                        for (final c in pinTopTierComments<PostComment>(_comments, (c) => app.donorTierForUserId(c.authorId))) ...[
                          _CommentTile(
                            theme: theme,
                            comment: c,
                            isReply: false,
                            replying: _replyingTo == c.id,
                            onReplyTap: () => setState(() => _replyingTo = _replyingTo == c.id ? null : c.id),
                            replyController: _replyCtrls.putIfAbsent(c.id, () => TextEditingController()),
                            onSendReply: () => _submit(parentId: c.id),
                            onLikeTap: () => _toggleLike(c),
                            onDeleteTap: (c.authorId == app.currentUser?.id || app.currentUser?.role == UserRole.admin)
                                ? () => _confirmDeleteComment(context, app, c.id)
                                : null,
                          ),
                          for (final r in c.replies)
                            _CommentTile(
                              theme: theme,
                              comment: r,
                              isReply: true,
                              onLikeTap: () => _toggleLike(r),
                              onDeleteTap: (r.authorId == app.currentUser?.id || app.currentUser?.role == UserRole.admin)
                                  ? () => _confirmDeleteComment(context, app, r.id)
                                  : null,
                            ),
                          const SizedBox(height: 14),
                        ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: _CommentComposer(
                  theme: theme, controller: _commentCtrl, onSend: () => _submit(),
                  myTier: donorTierForUser(app.currentUser, app.myDonationTotalUsd),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// فیلد نوشتن یک نظر/ریپلای — گرد و شیشه‌ای، با دکمه‌ی استیکر و ارسال دایره‌ای.
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
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(Icons.emoji_emotions_outlined, size: 19, color: theme.textFaint),
        ),
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

/// یک نظر (یا ریپلای) — با آواتار، متن، لایک، پاسخ (فقط سطح اول)، و حذف.
class _CommentTile extends StatelessWidget {
  final AppColors theme;
  final PostComment comment;
  final bool isReply;
  final bool replying;
  final VoidCallback? onReplyTap;
  final TextEditingController? replyController;
  final VoidCallback? onSendReply;
  final VoidCallback onLikeTap;
  final VoidCallback? onDeleteTap;

  const _CommentTile({
    required this.theme,
    required this.comment,
    required this.isReply,
    this.replying = false,
    this.onReplyTap,
    this.replyController,
    this.onSendReply,
    required this.onLikeTap,
    this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ringSize = isReply ? 30.0 : 37.0;
    final badgeSize = isReply ? 26.0 : 32.0;
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
          theme: theme, size: ringSize, childSize: badgeSize, tier: tier,
          child: HzBadge(
            theme: theme, size: badgeSize, filled: true, avatarPath: comment.authorAvatar,
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
              Text(comment.createdAtLabel, style: TextStyle(color: theme.textFaint, fontSize: 9.5)),
            ]),
            const SizedBox(height: 3),
            Text(comment.text, style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.7)),
            const SizedBox(height: 5),
            Row(children: [
              InkWell(
                onTap: onLikeTap,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(comment.likedByMe ? Icons.favorite : Icons.favorite_border, size: 13, color: comment.likedByMe ? _kLikeColor : theme.textFaint),
                  if (comment.likeCount > 0) ...[
                    const SizedBox(width: 3),
                    Text('${comment.likeCount}', style: TextStyle(fontSize: 10, color: comment.likedByMe ? _kLikeColor : theme.textFaint, fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
              if (!isReply) ...[
                const SizedBox(width: 14),
                InkWell(onTap: onReplyTap, child: Text('پاسخ', style: TextStyle(color: theme.blue, fontSize: 10.5, fontWeight: FontWeight.w700))),
              ],
              if (onDeleteTap != null) ...[
                const SizedBox(width: 14),
                InkWell(onTap: onDeleteTap, child: Text('حذف', style: TextStyle(color: theme.danger, fontSize: 10.5, fontWeight: FontWeight.w700))),
              ],
            ]),
            if (replying && replyController != null) ...[
              const SizedBox(height: 8),
              _CommentComposer(
                theme: theme, controller: replyController!, onSend: onSendReply ?? () {},
                myTier: donorTierForUser(app.currentUser, app.myDonationTotalUsd),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
