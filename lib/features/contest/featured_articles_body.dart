import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import 'featured_article_screen.dart';

/// بخش «برگزیدگان مسابقه‌ی مقالات» — سه مقاله‌ی برتر هر دوره که مدیر
/// منتشر کرده؛ با زدن روی هرکدام، متن کامل + نظرها باز می‌شود.
class FeaturedArticlesBody extends StatefulWidget {
  final AppColors theme;
  const FeaturedArticlesBody({super.key, required this.theme});

  @override
  State<FeaturedArticlesBody> createState() => _FeaturedArticlesBodyState();
}

class _FeaturedArticlesBodyState extends State<FeaturedArticlesBody> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    if (app.featuredArticles.isEmpty) _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      await context.read<AppState>().loadFeaturedArticles();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final articles = context.watch<AppState>().featuredArticles;

    if (_loading && articles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (articles.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
          children: [
            Icon(Icons.emoji_events_outlined, size: 40, color: theme.textFaint),
            const SizedBox(height: 12),
            Text('هنوز برگزیده‌ای منتشر نشده', textAlign: TextAlign.center, style: TextStyle(color: theme.textFaint, fontSize: 12.5)),
            const SizedBox(height: 6),
            Text('مدیر پس از پایان هر دوره‌ی مسابقه، سه مقاله‌ی برتر را اینجا منتشر می‌کند.', textAlign: TextAlign.center, style: TextStyle(color: theme.textFaint, fontSize: 10.5, height: 1.8)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        itemCount: articles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _FeaturedArticleCard(theme: theme, article: articles[i]).staggered(i),
      ),
    );
  }
}

class _FeaturedArticleCard extends StatelessWidget {
  final AppColors theme;
  final FeaturedArticle article;
  const _FeaturedArticleCard({required this.theme, required this.article});

  Color get _placementColor {
    if (article.placement == 1) return theme.yellow;
    if (article.placement == 2) return theme.textSecondary;
    return theme.blue;
  }

  String get _placementEmoji {
    if (article.placement == 1) return '🥇';
    if (article.placement == 2) return '🥈';
    return '🥉';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final hasAvatar = article.authorAvatar != null && article.authorAvatar!.isNotEmpty;
    return HzGlassCard(
      theme: theme,
      radius: 20,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FeaturedArticleScreen(article: article))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _placementColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_placementEmoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text('نفر ${article.placement}', style: TextStyle(color: _placementColor, fontSize: 10, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(article.monthLabel, style: TextStyle(color: theme.textFaint, fontSize: 10)),
        ]),
        const SizedBox(height: 10),
        Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800, height: 1.5)),
        const SizedBox(height: 6),
        Text(article.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 11.5, height: 1.8)),
        const SizedBox(height: 12),
        Row(children: [
          DonorRing(
            theme: theme, size: 32, childSize: 26, tier: app.donorTierForUserId(article.authorId ?? ''),
            child: HzBadge(theme: theme, size: 26, filled: true, avatarPath: hasAvatar ? article.authorAvatar : null,
                child: Text(article.authorName.isNotEmpty ? article.authorName[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(article.authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
          if (app.donorTierForUserId(article.authorId ?? '')?.tickColor != null) ...[
            const SizedBox(width: 4),
            DonorVipTick(color: app.donorTierForUserId(article.authorId ?? '')!.tickColor!, size: 12),
            const SizedBox(width: 6),
          ],
          Icon(Icons.arrow_back, size: 13, color: theme.blue),
        ]),
      ]),
    );
  }
}
