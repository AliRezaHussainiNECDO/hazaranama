import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

/// پنل مدیریت «حافظه‌ی جمعی» — نظارت کامل: آمار زنده‌ی فید، فهرست همه‌ی پست‌ها
/// با پیش‌نمایش رسانه و واکنش‌ها، و نظارت/حذف نظرات و ریپلای‌های هر پست
/// به‌صورت آکاردئونی، بدون نیاز به خروج از صفحه.
class CommunityModerationPage extends StatefulWidget {
  const CommunityModerationPage({super.key});
  @override
  State<CommunityModerationPage> createState() => _CommunityModerationPageState();
}

class _CommunityModerationPageState extends State<CommunityModerationPage> {
  int _tab = 0; // 0 = آمار، 1 = همه‌ی پست‌ها، 2 = گزارش‌ها
  String _filter = 'all'; // all | media | text
  bool _loading = false;
  bool _loadingReports = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshReports();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      await context.read<AppState>().loadPosts();
    } catch (_) {
      // نادیده گرفتن خطای شبکه؛ فهرست موجود همچنان نمایش داده می‌شود
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshReports() async {
    setState(() => _loadingReports = true);
    try {
      await context.read<AppState>().loadContentReports();
    } catch (_) {
      // نادیده گرفتن خطای شبکه؛ فهرست موجود همچنان نمایش داده می‌شود
    } finally {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(children: [
          Expanded(child: _TabChip(theme: theme, label: 'آمار حافظه‌ی جمعی', selected: _tab == 0, onTap: () => setState(() => _tab = 0))),
          const SizedBox(width: 6),
          Expanded(child: _TabChip(theme: theme, label: 'همه‌ی پست‌ها', selected: _tab == 1, onTap: () => setState(() => _tab = 1))),
          const SizedBox(width: 6),
          Expanded(
            child: _TabChip(
              theme: theme,
              label: app.contentReports.where((r) => r.status == 'pending').isEmpty ? 'گزارش‌ها' : 'گزارش‌ها (${app.contentReports.where((r) => r.status == 'pending').length})',
              selected: _tab == 2,
              onTap: () => setState(() => _tab = 2),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _tab == 2
            ? (_loadingReports && app.contentReports.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _ReportsTab(theme: theme, app: app, onRefresh: _refreshReports))
            : (_loading && app.posts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _tab == 0
                    ? _StatsTab(theme: theme, posts: app.posts)
                    : _PostsTab(theme: theme, app: app, filter: _filter, onFilterChanged: (f) => setState(() => _filter = f), onRefresh: _refresh)),
      ),
    ]);
  }
}

class _TabChip extends StatelessWidget {
  final AppColors theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({required this.theme, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? theme.success : theme.bgCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? theme.success : theme.glassBorder),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : theme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// =============================================================================
// تب آمار
// =============================================================================

class _StatsTab extends StatelessWidget {
  final AppColors theme;
  final List<Post> posts;
  const _StatsTab({required this.theme, required this.posts});

  @override
  Widget build(BuildContext context) {
    final totalPosts = posts.length;
    final totalComments = posts.fold<int>(0, (s, p) => s + p.commentsCount);
    final totalReactions = posts.fold<int>(0, (s, p) => s + p.totalReactions);
    final mediaPosts = posts.where((p) => p.hasMedia).length;
    final videoPosts = posts.where((p) => p.hasVideo).length;
    final imagePosts = posts.where((p) => p.hasImages).length;

    Post? topReacted;
    Post? topCommented;
    for (final p in posts) {
      if (topReacted == null || p.totalReactions > topReacted.totalReactions) topReacted = p;
      if (topCommented == null || p.commentsCount > topCommented.commentsCount) topCommented = p;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.1,
          padding: EdgeInsets.zero,
          children: [
            _StatCard(theme: theme, icon: Icons.dynamic_feed_rounded, color: theme.blue, label: 'کل پست‌ها', value: '$totalPosts'),
            _StatCard(theme: theme, icon: Icons.mode_comment_rounded, color: theme.success, label: 'کل نظرات', value: '$totalComments'),
            _StatCard(theme: theme, icon: Icons.emoji_emotions_rounded, color: theme.yellow, label: 'کل واکنش‌ها', value: '$totalReactions'),
            _StatCard(theme: theme, icon: Icons.perm_media_rounded, color: theme.danger, label: 'پست‌های رسانه‌دار', value: '$mediaPosts'),
            _StatCard(theme: theme, icon: Icons.image_rounded, color: theme.blue, label: 'با عکس', value: '$imagePosts'),
            _StatCard(theme: theme, icon: Icons.videocam_rounded, color: theme.success, label: 'با ویدیو', value: '$videoPosts'),
          ],
        ),
        if (topReacted != null && topReacted.totalReactions > 0) ...[
          const SizedBox(height: 18),
          Text('پرطرفدارترین پست', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _HighlightPostCard(theme: theme, post: topReacted, trailingLabel: '${topReacted.totalReactions} واکنش', trailingIcon: Icons.favorite_rounded, trailingColor: theme.danger),
        ],
        if (topCommented != null && topCommented.commentsCount > 0) ...[
          const SizedBox(height: 14),
          Text('پرنظرترین پست', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _HighlightPostCard(theme: theme, post: topCommented, trailingLabel: '${topCommented.commentsCount} نظر', trailingIcon: Icons.mode_comment_rounded, trailingColor: theme.blue),
        ],
        if (posts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('هنوز پستی در حافظه‌ی جمعی ثبت نشده است.', style: TextStyle(color: theme.textFaint, fontSize: 12.5))),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final AppColors theme;
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatCard({required this.theme, required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => HzStatTile(theme: theme, icon: icon, color: color, value: value, label: label);
}

class _HighlightPostCard extends StatelessWidget {
  final AppColors theme;
  final Post post;
  final String trailingLabel;
  final IconData trailingIcon;
  final Color trailingColor;
  const _HighlightPostCard({required this.theme, required this.post, required this.trailingLabel, required this.trailingIcon, required this.trailingColor});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
      child: Row(children: [
        DonorRing(
          theme: theme, size: 40, childSize: 34, tier: app.donorTierForUserId(post.authorId),
          child: HzBadge(theme: theme, size: 34, filled: true, avatarPath: post.authorAvatar, child: Text(post.authorInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post.authorName, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(post.text.isEmpty ? '(بدون متن — فقط رسانه)' : post.text, style: TextStyle(color: theme.textFaint, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 8),
        Row(children: [
          Icon(trailingIcon, size: 13, color: trailingColor),
          const SizedBox(width: 4),
          Text(trailingLabel, style: TextStyle(color: trailingColor, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

// =============================================================================
// تب همه‌ی پست‌ها
// =============================================================================

class _PostsTab extends StatelessWidget {
  final AppColors theme;
  final AppState app;
  final String filter;
  final void Function(String) onFilterChanged;
  final Future<void> Function() onRefresh;
  const _PostsTab({required this.theme, required this.app, required this.filter, required this.onFilterChanged, required this.onRefresh});

  static const _filters = {'all': 'همه', 'media': 'رسانه‌دار', 'text': 'فقط متن'};

  @override
  Widget build(BuildContext context) {
    var items = app.posts;
    if (filter == 'media') items = items.where((p) => p.hasMedia).toList();
    if (filter == 'text') items = items.where((p) => !p.hasMedia).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final key = _filters.keys.elementAt(i);
                final selected = filter == key;
                return InkWell(
                  onTap: () => onFilterChanged(key),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? theme.success.withValues(alpha: 0.16) : theme.bgCard.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: selected ? theme.success : theme.glassBorder),
                    ),
                    child: Text(_filters[key]!, style: TextStyle(color: selected ? theme.success : theme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('پستی با این فیلتر یافت نشد.', style: TextStyle(color: theme.textFaint, fontSize: 12.5))),
            )
          else
            for (final (i, p) in items.indexed) ...[
              _PostAdminCard(theme: theme, app: app, post: p).staggered(i),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _PostAdminCard extends StatefulWidget {
  final AppColors theme;
  final AppState app;
  final Post post;
  const _PostAdminCard({required this.theme, required this.app, required this.post});

  @override
  State<_PostAdminCard> createState() => _PostAdminCardState();
}

class _PostAdminCardState extends State<_PostAdminCard> {
  bool _expanded = false;
  bool _loadingComments = false;
  List<PostComment>? _comments;

  Future<void> _toggleExpand() async {
    setState(() => _expanded = !_expanded);
    if (_expanded && _comments == null) {
      setState(() => _loadingComments = true);
      try {
        final list = await widget.app.fetchPostComments(widget.post.id);
        if (mounted) setState(() => _comments = list);
      } catch (_) {
        if (mounted) setState(() => _comments = []);
      } finally {
        if (mounted) setState(() => _loadingComments = false);
      }
    }
  }

  Future<void> _deleteComment(PostComment c) async {
    final confirmed = await _confirmDialog(context, widget.theme, 'این نظر حذف شود؟');
    if (confirmed != true) return;
    await widget.app.deletePostComment(c.id, widget.post.id);
    if (!mounted) return;
    setState(() {
      _comments?.removeWhere((x) => x.id == c.id);
      _comments?.forEach((top) => top.replies.removeWhere((r) => r.id == c.id));
    });
    if (mounted) showHzToast(context, 'نظر حذف شد');
  }

  Future<void> _deletePost() async {
    final confirmed = await _confirmDialog(context, widget.theme, 'این پست به‌همراه همه‌ی نظرات آن حذف شود؟');
    if (confirmed != true) return;
    await widget.app.deletePost(widget.post.id);
    if (mounted) showHzToast(context, 'پست حذف شد');
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final p = widget.post;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.glassBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DonorRing(
            theme: theme, size: 42, childSize: 36, tier: widget.app.donorTierForUserId(p.authorId),
            child: HzBadge(theme: theme, size: 36, filled: true, avatarPath: p.authorAvatar, child: Text(p.authorInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(p.authorName, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(p.createdAtLabel, style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
              ]),
              if (p.text.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(p.text, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.8)),
              ],
            ]),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 18, color: theme.textFaint),
            onSelected: (v) {
              if (v == 'delete') _deletePost();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: theme.danger), const SizedBox(width: 8), const Text('حذف پست')])),
            ],
          ),
        ]),
        if (p.hasMedia) ...[
          const SizedBox(height: 10),
          _MediaPreviewRow(theme: theme, post: p),
        ],
        const SizedBox(height: 10),
        Row(children: [
          if (p.totalReactions > 0) ...[
            for (final entry in p.reactions.entries.take(4))
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: theme.bgCardAlt, borderRadius: BorderRadius.circular(999)),
                  child: Text('${entry.key} ${entry.value}', style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                ),
              ),
            const Spacer(),
          ] else
            const Spacer(),
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.mode_comment_rounded, size: 14, color: theme.blue),
                const SizedBox(width: 4),
                Text('${p.commentsCount} نظر', style: TextStyle(color: theme.blue, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 3),
                Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 16, color: theme.blue),
              ]),
            ),
          ),
        ]),
        if (_expanded) ...[
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          if (_loadingComments)
            const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
          else if ((_comments ?? []).isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('نظری برای این پست ثبت نشده است.', style: TextStyle(color: theme.textFaint, fontSize: 12)))
          else
            for (final c in _comments!) ...[
              _AdminCommentTile(theme: theme, comment: c, onDelete: () => _deleteComment(c)),
              for (final r in c.replies) Padding(padding: const EdgeInsets.only(right: 24), child: _AdminCommentTile(theme: theme, comment: r, onDelete: () => _deleteComment(r))),
            ],
        ],
      ]),
    );
  }
}

class _AdminCommentTile extends StatelessWidget {
  final AppColors theme;
  final PostComment comment;
  final VoidCallback onDelete;
  const _AdminCommentTile({required this.theme, required this.comment, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DonorRing(
          theme: theme, size: 28, childSize: 24, tier: app.donorTierForUserId(comment.authorId),
          child: HzBadge(theme: theme, size: 24, filled: true, avatarPath: comment.authorAvatar, child: const Icon(Icons.person_rounded, color: Colors.white, size: 11)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(comment.authorName, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text(comment.createdAtLabel, style: TextStyle(color: theme.textFaint, fontSize: 11)),
              if (comment.likeCount > 0) ...[
                const SizedBox(width: 6),
                Icon(Icons.favorite_rounded, size: 10, color: theme.danger),
                const SizedBox(width: 2),
                Text('${comment.likeCount}', style: TextStyle(color: theme.textFaint, fontSize: 11)),
              ],
            ]),
            const SizedBox(height: 2),
            Text(comment.text, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.6)),
          ]),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          icon: Icon(Icons.close_rounded, size: 15, color: theme.danger),
          onPressed: onDelete,
        ),
      ]),
    );
  }
}

class _MediaPreviewRow extends StatelessWidget {
  final AppColors theme;
  final Post post;
  const _MediaPreviewRow({required this.theme, required this.post});

  @override
  Widget build(BuildContext context) {
    if (post.hasVideo) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: theme.bgCardAlt, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.videocam_rounded, size: 16, color: theme.success),
          const SizedBox(width: 6),
          Text('این پست شامل یک ویدیو است', style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: post.imageUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(post.imageUrls[i], width: 60, height: 60, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: theme.bgCardAlt)),
        ),
      ),
    );
  }
}

Future<bool?> _confirmDialog(BuildContext context, AppColors theme, String message) {
  return showDialog<bool>(context: context, builder: (ctx) {
    return AlertDialog(
      backgroundColor: theme.bgElevated,
      title: Text(message, style: TextStyle(color: theme.textPrimary, fontSize: 14)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('انصراف')),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('حذف', style: TextStyle(color: theme.danger))),
      ],
    );
  });
}

// =============================================================================
// تب گزارش‌ها
// =============================================================================

class _ReportsTab extends StatelessWidget {
  final AppColors theme;
  final AppState app;
  final Future<void> Function() onRefresh;
  const _ReportsTab({required this.theme, required this.app, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final reports = [...app.contentReports]
      ..sort((a, b) {
        if (a.status == b.status) return 0;
        if (a.status == 'pending') return -1;
        if (b.status == 'pending') return 1;
        return 0;
      });

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: reports.isEmpty
          ? ListView(
              padding: const EdgeInsets.symmetric(vertical: 60),
              children: [
                Center(
                  child: Column(children: [
                    Icon(Icons.flag_rounded, size: 30, color: theme.textFaint),
                    const SizedBox(height: 10),
                    Text('هیچ گزارشی ثبت نشده است.', style: TextStyle(color: theme.textFaint, fontSize: 12.5)),
                  ]),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                for (final r in reports) ...[
                  _ReportCard(theme: theme, app: app, report: r),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final AppColors theme;
  final AppState app;
  final ContentReport report;
  const _ReportCard({required this.theme, required this.app, required this.report});

  static const _typeLabels = {'post': 'پست', 'comment': 'کامنت', 'user': 'کاربر'};
  static const _statusLabels = {'pending': 'در انتظار بررسی', 'reviewed': 'بررسی‌شد', 'dismissed': 'رد شد'};

  Color _statusColor() {
    switch (report.status) {
      case 'reviewed':
        return theme.success;
      case 'dismissed':
        return theme.textFaint;
      default:
        return theme.danger;
    }
  }

  Future<void> _act(BuildContext context, String status) async {
    await app.resolveReport(report.id, status);
    if (context.mounted) showHzToast(context, status == 'reviewed' ? 'گزارش به‌عنوان بررسی‌شده ثبت شد' : 'گزارش رد شد');
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: theme.bgCardAlt, borderRadius: BorderRadius.circular(999)),
            child: Text(_typeLabels[report.targetType] ?? report.targetType, style: TextStyle(color: theme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(report.reason, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(_statusLabels[report.status] ?? report.status, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ]),
        if ((report.targetPreview ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: theme.bgCardAlt, borderRadius: BorderRadius.circular(10)),
            child: Text(report.targetPreview!, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.6), maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
        ],
        if ((report.note ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('یادداشت گزارش‌دهنده: ${report.note}', style: TextStyle(color: theme.textFaint, fontSize: 12, height: 1.6)),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Text('گزارش‌دهنده: ${report.reporterName}', style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
          const Spacer(),
          Text(report.createdAtLabel, style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
        ]),
        if (report.status == 'pending') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _act(context, 'dismissed'),
                style: OutlinedButton.styleFrom(foregroundColor: theme.textFaint, side: BorderSide(color: theme.glassBorder), padding: const EdgeInsets.symmetric(vertical: 9)),
                child: const Text('رد گزارش', style: TextStyle(fontSize: 12.5)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => _act(context, 'reviewed'),
                style: FilledButton.styleFrom(backgroundColor: theme.success, padding: const EdgeInsets.symmetric(vertical: 9)),
                child: const Text('بررسی‌شد', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}
