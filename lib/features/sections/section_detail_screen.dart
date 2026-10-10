import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/widgets.dart';
import '../../data/sections.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../home/section_card.dart';
import '../contest/featured_articles_body.dart';
import '../music/artists_gallery_body.dart';
import 'section_bodies.dart';
import 'dictionary_body.dart';

class SectionDetailScreen extends StatelessWidget {
  final String sectionId;
  const SectionDetailScreen({super.key, required this.sectionId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final section = sectionById(sectionId);
    final items = app.content[sectionId] ?? [];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bg,
        extendBodyBehindAppBar: false,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: AppBar(
                backgroundColor: theme.bgElevated.withValues(alpha: 0.5),
                elevation: 0,
                leading: IconButton(icon: Icon(Icons.arrow_forward, color: theme.textPrimary, size: 20), onPressed: () => Navigator.of(context).pop()),
                title: Row(children: [
                  StatIconBox(icon: iconForSection(section.id), color: theme.blue, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(section.title, style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(section.description, style: TextStyle(color: theme.textFaint, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ]),
                actions: [
                  IconButton(
                    icon: Icon(Icons.ios_share, size: 18, color: theme.textSecondary),
                    onPressed: () => showHzToast(context, 'پیوند کپی شد'),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.6)),
          SafeArea(child: _body(theme, section, items)),
        ]),
      ),
    );
  }

  Widget _body(theme, ContentSection section, List<ContentItem> items) {
    switch (section.kind) {
      case SectionKind.timeline:
        return TimelineBody(theme: theme, items: items);
      case SectionKind.people:
        return PeopleBody(theme: theme, items: items);
      case SectionKind.incidents:
        return IncidentsBody(theme: theme, items: items);
      case SectionKind.grid:
        return GridBody(theme: theme, items: items);
      case SectionKind.tracks:
        return TracksBody(theme: theme, items: items);
      case SectionKind.artists:
        return ArtistsGalleryBody(theme: theme);
      case SectionKind.dictionary:
        return DictionaryBody(theme: theme, items: items);
      case SectionKind.regions:
        return RegionsBody(theme: theme, items: items);
      case SectionKind.photos:
        return PhotosBody(theme: theme, items: items);
      case SectionKind.news:
        return NewsBody(theme: theme, items: items);
      case SectionKind.books:
        return BooksBody(theme: theme, items: items);
      case SectionKind.contestWinners:
        return FeaturedArticlesBody(theme: theme);
      case SectionKind.stories:
      case SectionKind.social:
        return const SizedBox.shrink();
    }
  }
}
