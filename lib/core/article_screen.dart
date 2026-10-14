import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'app_colors.dart';
import 'widgets.dart';

/// صفحه‌ی نمایش یک مقاله‌ی کامل — برای فصل‌های «هویت و تاریخچه»،
/// زندگی‌نامه‌ی «شخصیت‌های برجسته»، و متن کامل «روایت امروز».
/// از این‌طریق باز می‌شود: Navigator.push(context, ArticleScreen.route(...))
class ArticleScreen extends StatelessWidget {
  final AppColors theme;
  final Widget badge;
  final String title;
  final String? subtitle;
  final String body;
  final String? imageUrl;
  final String? videoUrl;
  final String imageCredit;
  final String imagePage;
  final List<(String, String)> links;

  const ArticleScreen({
    super.key,
    required this.theme,
    required this.badge,
    required this.title,
    required this.body,
    this.subtitle,
    this.imageUrl,
    this.videoUrl,
    this.imageCredit = '',
    this.imagePage = '',
    this.links = const [],
  });

  static Route<void> route({
    required AppColors theme,
    required Widget badge,
    required String title,
    required String body,
    String? subtitle,
    String? imageUrl,
    String? videoUrl,
    ContentItem? item,
  }) {
    var tracked = false;
    return MaterialPageRoute(
      builder: (ctx) {
        // امتیاز فعالیت: خواندن هر روایت/مقاله/شخصیت فقط یک بار امتیاز دارد
        if (!tracked && item != null) {
          tracked = true;
          final app = ctx.read<AppState>();
          Future.microtask(() => app.trackActivity('read', item.id));
        }
        return ArticleScreen(
        theme: theme,
        badge: badge,
        title: title,
        body: body,
        subtitle: subtitle,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        imageCredit: item?.imageCredit ?? '',
        imagePage: item?.imagePage ?? '',
        links: item?.links ?? const [],
      );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final paragraphs = body.split('\n\n');
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bg,
        appBar: AppBar(
          backgroundColor: theme.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_forward, color: theme.textPrimary, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Row(children: [
            badge,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(color: theme.textFaint, fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
            children: [
              if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: Stack(fit: StackFit.expand, children: [
                      HzFullImage(url: imageUrl!, error: Container(color: theme.bgCard)),
                      if (videoUrl != null && videoUrl!.isNotEmpty)
                        Center(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => openContentUrl(context, videoUrl!),
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0x73000000),
                                  border: Border.all(color: Colors.white70, width: 1.5),
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ).animate().fadeIn(duration: 420.ms).scale(begin: const Offset(0.97, 0.97)),
                if (imageCredit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: InkWell(
                      onTap: imagePage.isEmpty ? null : () => openContentUrl(context, imagePage),
                      child: Row(children: [
                        Icon(Icons.photo_camera_outlined, size: 13, color: theme.textFaint),
                        const SizedBox(width: 5),
                        Expanded(child: Text(imageCredit, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 10.5, height: 1.5))),
                      ]),
                    ),
                  ),
                const SizedBox(height: 18),
              ] else if (videoUrl != null && videoUrl!.isNotEmpty) ...[
                Material(
                  color: theme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => openContentUrl(context, videoUrl!),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Icon(Icons.play_circle_fill_rounded, color: theme.blue, size: 26),
                        const SizedBox(width: 10),
                        Text('مشاهده ویدیوی مرتبط', style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              const FlagStripe(width: 50),
              const SizedBox(height: 16),
              for (final p in paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(p, style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 2.0)),
                ),
              for (final (label, url) in links)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: theme.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => openContentUrl(context, url),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          Icon(Icons.open_in_new_rounded, size: 18, color: theme.blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(label, style: TextStyle(color: theme.blue, fontSize: 12.5, fontWeight: FontWeight.w800)),
                              Text(Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url, textDirection: TextDirection.ltr, style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
