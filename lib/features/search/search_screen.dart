import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets.dart';
import '../../core/app_logo.dart';
import '../../core/app_colors.dart';
import '../../data/sections.dart';
import '../../state/app_state.dart';
import '../../services/ai_service.dart';
import '../home/section_card.dart';
import '../../core/section_style.dart';

class _SearchRow {
  final String label;
  final String sub;
  final String sectionId;
  final String sectionTitle;
  final String haystack; // همه‌ی متن‌های آیتم (نه فقط عنوان) برای جست‌وجو
  _SearchRow({required this.label, required this.sub, required this.sectionId, required this.sectionTitle, String? haystack})
      : haystack = (haystack ?? '$label $sub').toLowerCase();
}

const _kSuggestions = ['بامیان', 'عبدالعلی مزاری', 'افشار', 'نوروز', 'دمبوره', 'کاتب', 'یکاولنگ', 'آغیل'];

class SearchScreen extends StatefulWidget {
  final void Function(String sectionId) onOpenSection;
  const SearchScreen({super.key, required this.onOpenSection});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  final _ai = AiService();

  bool _aiLoading = false;
  AiSearchResult? _aiResult;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _query.addListener(() {
      setState(() {
        _aiResult = null;
        _aiError = null;
      });
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<_SearchRow> _buildIndex(AppState app) {
    final rows = <_SearchRow>[];
    for (final s in kSections) {
      if (s.id == 'oral') continue;
      rows.add(_SearchRow(label: s.title, sub: s.description, sectionId: s.id, sectionTitle: s.title));
      final items = app.content[s.id] ?? [];
      for (final it in items) {
        final label = (it['name'] ?? it['title'] ?? it['era'] ?? it['caption'] ?? it['hazaragi'])?.toString();
        final sub = (it['field'] ?? it['artist'] ?? it['author'] ?? it['fa'] ?? it['note'])?.toString() ?? '';
        final all = it.fields.values.whereType<String>().join(' ');
        if (label != null) rows.add(_SearchRow(label: label, sub: sub, sectionId: s.id, sectionTitle: s.title, haystack: all));
      }
    }
    return rows;
  }

  Future<void> _askAi(String query) async {
    setState(() {
      _aiLoading = true;
      _aiError = null;
    });
    try {
      final sections = kSections.where((s) => s.id != 'oral').map((s) => {'id': s.id, 'title': s.title, 'description': s.description}).toList();
      final result = await _ai.search(query: query, sections: sections);
      if (mounted) setState(() => _aiResult = result);
    } on AiServiceException catch (e) {
      if (mounted) setState(() => _aiError = e.message);
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final q = _query.text.trim().toLowerCase();
    final index = _buildIndex(app);
    final results = q.isEmpty
        ? <_SearchRow>[]
        : (index.where((r) => r.label.toLowerCase().contains(q)).toList()
              ..addAll(index.where((r) => !r.label.toLowerCase().contains(q) && r.haystack.contains(q))))
            .take(40)
            .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(children: [
        HzTextField(controller: _query, icon: Icons.search, hint: 'در تاریخ، فرهنگ، اشعار و بیشتر بگرد…', theme: theme),
        const SizedBox(height: 4),
        Expanded(
          child: q.isEmpty
              ? _SearchHome(
                  theme: theme,
                  onPick: (t) {
                    _query.text = t;
                    _query.selection = TextSelection.collapsed(offset: t.length);
                  },
                  onOpenSection: widget.onOpenSection,
                )
              : ListView(
                  padding: const EdgeInsets.only(top: 12, bottom: 20),
                  children: [
                    _AiSearchPanel(
                      theme: theme,
                      query: q,
                      loading: _aiLoading,
                      result: _aiResult,
                      error: _aiError,
                      onAsk: () => _askAi(q),
                      onOpenSection: widget.onOpenSection,
                    ),
                    const SizedBox(height: 14),
                    if (results.isEmpty)
                      _EmptyState(theme: theme, icon: Icons.search_off, label: 'در فهرست اپ چیزی پیدا نشد؛ می‌توانی از دستیار هوشمند بپرسی')
                    else
                      for (var i = 0; i < results.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => widget.onOpenSection(results[i].sectionId),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
                              child: Row(children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(gradient: sectionStyle(results[i].sectionId).gradient, borderRadius: BorderRadius.circular(13)),
                                  child: Icon(iconForSection(results[i].sectionId), color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(results[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Text('${results[i].sectionTitle}${results[i].sub.isNotEmpty ? " · ${results[i].sub}" : ""}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 12.5)),
                                  ]),
                                ),
                                Icon(Icons.arrow_back, size: 14, color: theme.textFaint),
                              ]),
                            ),
                          ),
                        ).staggered(i, step: const Duration(milliseconds: 30)),
                  ],
                ),
        ),
      ]),
    );
  }
}

/// بخش «از دستیار هوشمند بپرس» بالای نتایج جستجو — با یک دکمه‌ی دعوت‌کننده،
/// و پس از پاسخ، یک خلاصه‌ی هوشمند به‌همراه بخش‌های پیشنهادی نشان می‌دهد.
class _AiSearchPanel extends StatelessWidget {
  final AppColors theme;
  final String query;
  final bool loading;
  final AiSearchResult? result;
  final String? error;
  final VoidCallback onAsk;
  final void Function(String sectionId) onOpenSection;

  const _AiSearchPanel({
    required this.theme,
    required this.query,
    required this.loading,
    required this.result,
    required this.error,
    required this.onAsk,
    required this.onOpenSection,
  });

  @override
  Widget build(BuildContext context) {
    if (result == null && error == null) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loading ? null : onAsk,
        child: HzGlassCard(
          theme: theme,
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: theme.aiGradient),
              child: loading
                  ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                loading ? 'دستیار هوشمند در حال فکرکردن است…' : 'از دستیار هوشمند درباره‌ی «$query» بپرس',
                style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            if (!loading) Icon(Icons.arrow_back, size: 14, color: theme.aiViolet),
          ]),
        ),
      );
    }

    if (error != null) {
      return HzGlassCard(
        theme: theme,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Icon(Icons.error_outline, size: 16, color: theme.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(error!, style: TextStyle(color: theme.danger, fontSize: 12.5))),
        ]),
      );
    }

    final r = result!;
    return HzGlassCard(
      theme: theme,
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome, size: 15, color: theme.aiViolet),
          const SizedBox(width: 6),
          Text('پاسخ دستیار هوشمند', style: TextStyle(color: theme.aiViolet, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Text(r.answer.isEmpty ? 'پاسخی یافت نشد.' : r.answer, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, height: 1.7)),
        if (r.sectionIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: r.sectionIds.map((id) {
              final s = sectionById(id);
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onOpenSection(id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: theme.aiViolet.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: theme.aiViolet.withValues(alpha: 0.35))),
                  child: Text(s.title, style: TextStyle(color: theme.aiViolet, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              );
            }).toList(),
          ),
        ],
      ]),
    ).animate().fadeIn(duration: 260.ms).slideY(begin: 0.04, end: 0);
  }
}

class _EmptyState extends StatelessWidget {
  final AppColors theme;
  final IconData icon;
  final String label;
  const _EmptyState({required this.theme, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 30, color: theme.textFaint.withValues(alpha: 0.6)),
        const SizedBox(height: 10),
        Text(label, textAlign: TextAlign.center, style: TextStyle(color: theme.textFaint, fontSize: 12)),
      ]),
    );
  }
}

/// صفحه‌ی آغاز جست‌وجو — پیشنهادهای آماده و میان‌بر بخش‌ها
class _SearchHome extends StatelessWidget {
  final AppColors theme;
  final ValueChanged<String> onPick;
  final void Function(String sectionId) onOpenSection;
  const _SearchHome({required this.theme, required this.onPick, required this.onOpenSection});

  @override
  Widget build(BuildContext context) {
    final sections = kSections.where((s) => s.id != 'oral' && s.id != 'dailyStory').toList();
    return ListView(
      padding: const EdgeInsets.only(top: 18, bottom: 110),
      children: [
        Text('جست‌وجوهای پیشنهادی', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in _kSuggestions)
            ActionChip(
              onPressed: () => onPick(t),
              avatar: Icon(Icons.north_west_rounded, size: 14, color: theme.blue),
              label: Text(t, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
              backgroundColor: theme.bgCard.withValues(alpha: 0.7),
              side: BorderSide(color: theme.glassBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
        ]),
        const SizedBox(height: 24),
        Text('مرور بخش‌ها', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final (i, sec) in sections.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: theme.bgCard.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onOpenSection(sec.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(gradient: sectionStyle(sec.id).gradient, borderRadius: BorderRadius.circular(12)),
                      child: Icon(sectionStyle(sec.id).icon, color: Colors.white, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(sec.title, style: TextStyle(color: theme.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700))),
                    Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: theme.textFaint),
                  ]),
                ),
              ),
            ),
          ).staggered(i, step: const Duration(milliseconds: 25)),
      ],
    );
  }
}
