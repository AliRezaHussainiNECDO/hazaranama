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
import '../community/post_widgets.dart' show showReportDialog;

/// صفحه‌ی یک مقاله‌ی برگزیده — متن کامل + نشان رتبه/جایزه، واکنش ایموجی،
/// و کامنت‌ها با قابلیت ریپلای (دقیقاً هم‌خانواده‌ی صفحه‌ی پخش ویدیو).
class FeaturedArticleScreen extends StatefulWidget {
  final FeaturedArticle article;
  const FeaturedArticleScreen({super.key, required this.article});

  @override
  State<FeaturedArticleScreen> createState() => _FeaturedArticleScreenState();
}

class _FeaturedArticleScreenState extends State<FeaturedArticleScreen> {
  Map<String, int> _reactionCounts = {};
  Map<String, bool> _myReactions = {};
  List<ArticleComment> _comments = [];
  bool _loadingComments = true;
  bool _loadingReactions = true;

  final _commentCtrl = TextEditingController();
  final Map<String, TextEditingController> _replyCtrls = {};
  String? _replyingTo;

  @override
  void initState() {
    super.initState();
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
      final data = await context.read<AppState>().fetchArticleReactions(widget.article.id);
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
      final comments = await context.read<AppState>().fetchArticleComments(widget.article.id);
      if (!mounted) return;
      setState(() { _comments = comments; _loadingComments = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
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
    await app.toggleArticleReaction(widget.article.id, emoji, mine);
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
    await app.addArticleComment(widget.article.id, text, parentId: parentId);
    if (app.myRankTier.index == kDonorTiers.last.index) {
      HapticFeedback.heavyImpact();
      if (mounted) showHzToast(context, '👑 کامنت شاهانه‌ات ارسال شد!');
    }
    _loadComments();
  }

  Color _placementColor(AppColors theme) {
    if (widget.article.placement == 1) return theme.yellow;
    if (widget.article.placement == 2) return theme.textSecondary;
    return theme.blue;
  }

  String get _placementEmoji {
    if (widget.article.placement == 1) return '🥇';
    if (widget.article.placement == 2) return '🥈';
    return '🥉';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final article = widget.article;
    final totalComments = _comments.fold<int>(0, (s, c) => s + 1 + c.replies.length);
    final hasAvatar = article.authorAvatar != null && article.authorAvatar!.isNotEmpty;

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
                title: Text('برگزیدگان مسابقه‌ی مقالات', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.5)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(color: _placementColor(theme).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_placementEmoji, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text('نفر ${article.placement}', style: TextStyle(color: _placementColor(theme), fontSize: 12, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text(article.monthLabel, style: TextStyle(color: theme.textFaint, fontSize: 12)),
                ]),
                const SizedBox(height: 12),
                Text(article.title, style: TextStyle(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.w800, height: 1.5)),
                const SizedBox(height: 10),
                Row(children: [
                  DonorRing(
                    theme: theme, size: 36, childSize: 30, tier: app.donorTierForUserId(article.authorId ?? ''),
                    child: HzBadge(theme: theme, size: 30, filled: true, avatarPath: hasAvatar ? article.authorAvatar : null,
                        child: Text(article.authorName.isNotEmpty ? article.authorName[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(article.authorName, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700))),
                  if (app.donorTierForUserId(article.authorId ?? '')?.tickColor != null) ...[
                    const SizedBox(width: 4),
                    DonorVipTick(color: app.donorTierForUserId(article.authorId ?? '')!.tickColor!, size: 12),
                  ],
                  const SizedBox(width: 6),
                  if (article.publishedAtLabel.isNotEmpty) Text(article.publishedAtLabel, style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
                ]),
                if (article.prize != null && article.prize!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: theme.yellow.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.yellow.withValues(alpha: 0.3))),
                    child: Row(children: [
                      Icon(Icons.card_giftcard, size: 16, color: theme.yellow),
                      const SizedBox(width: 8),
                      Expanded(child: Text(article.prize!, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700))),
                    ]),
                  ),
                ],
                const SizedBox(height: 16),
                HzGlassCard(
                  theme: theme,
                  radius: 18,
                  child: Text(article.body, style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 2.1)),
                ),
                const SizedBox(height: 18),
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
                _ArticleCommentComposer(
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
                  for (final c in pinTopTierComments<ArticleComment>(_comments, (c) => app.donorTierForUserId(c.authorId))) ...[
                    _ArticleCommentTile(
                      theme: theme,
                      comment: c,
                      isReply: false,
                      replying: _replyingTo == c.id,
                      onReplyTap: () => setState(() => _replyingTo = _replyingTo == c.id ? null : c.id),
                      replyController: _replyCtrls.putIfAbsent(c.id, () => TextEditingController()),
                      onSendReply: () => _submitComment(parentId: c.id),
                    ),
                    for (final r in c.replies)
                      _ArticleCommentTile(theme: theme, comment: r, isReply: true),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ArticleCommentComposer extends StatelessWidget {
  final AppColors theme;
  final TextEditingController controller;
  final VoidCallback onSend;
  final DonorTier? myTier;
  const _ArticleCommentComposer({required this.theme, required this.controller, required this.onSend, this.myTier});

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

class _ArticleCommentTile extends StatelessWidget {
  final AppColors theme;
  final ArticleComment comment;
  final bool isReply;
  final bool replying;
  final VoidCallback? onReplyTap;
  final TextEditingController? replyController;
  final VoidCallback? onSendReply;

  const _ArticleCommentTile({
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
                _ArticleCommentComposer(
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
