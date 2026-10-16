import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/widgets.dart';
import '../../core/app_logo.dart';
import '../../data/sections.dart';
import '../../state/app_state.dart';
import '../../services/ai_service.dart';

/// ابزار هوش مصنوعی مدیر — تولید پیش‌نویس، خلاصه‌سازی یا ترجمه‌ی محتوا برای
/// هر یک از بخش‌های هزاره‌نامه، پیش از افزودن نهایی از «مدیریت محتوا».
class AiToolsPage extends StatefulWidget {
  const AiToolsPage({super.key});

  @override
  State<AiToolsPage> createState() => _AiToolsPageState();
}

const _kActions = [
  {'id': 'draft', 'label': 'پیش‌نویس محتوا', 'icon': Icons.edit_note_rounded},
  {'id': 'summarize', 'label': 'خلاصه‌سازی', 'icon': Icons.short_text_rounded},
  {'id': 'translate', 'label': 'ترجمه', 'icon': Icons.translate_rounded},
];

const _kLanguages = ['فارسی', 'انگلیسی', 'هزارگی'];

class _AiToolsPageState extends State<AiToolsPage> {
  final _ai = AiService();
  final _topicCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();

  String _sectionId = kSections.first.id;
  String _action = 'draft';
  String _targetLang = 'فارسی';
  bool _loading = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _topicCtrl.dispose();
    _sourceCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final section = sectionById(_sectionId);
    if (_action == 'draft' && _topicCtrl.text.trim().isEmpty) {
      showHzToast(context, 'موضوع را بنویس تا دستیار پیش‌نویس بسازد.');
      return;
    }
    if (_action != 'draft' && _sourceCtrl.text.trim().isEmpty) {
      showHzToast(context, 'ابتدا متن مبدأ را وارد کن.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final text = await _ai.adminAssist(
        action: _action,
        sectionTitle: section.title,
        topic: _topicCtrl.text.trim(),
        sourceText: _sourceCtrl.text.trim(),
        targetLang: _targetLang,
      );
      if (!mounted) return;
      setState(() => _result = text);
    } on AiServiceException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().colors;
    final sections = kSections.where((s) => s.id != 'oral').toList();

    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        children: [
          HzGlassCard(
            theme: theme,
            radius: 18,
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: theme.aiGradient),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('دستیار هوش مصنوعی محتوا', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('پیش‌نویس، خلاصه یا ترجمه بساز؛ سپس در «مدیریت محتوا» ثبت کن', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          Text('بخش هدف', style: TextStyle(color: theme.textFaint, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          HzSelectField(
            value: sectionById(_sectionId).title,
            icon: Icons.folder_open_rounded,
            hint: 'انتخاب بخش',
            options: sections.map((s) => s.title).toList(),
            theme: theme,
            onChanged: (title) {
              final match = sections.firstWhere((s) => s.title == title, orElse: () => sections.first);
              setState(() => _sectionId = match.id);
            },
          ),
          const SizedBox(height: 16),

          Text('نوع تولید', style: TextStyle(color: theme.textFaint, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            for (final a in _kActions)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: a == _kActions.last ? 0 : 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() { _action = a['id'] as String; _result = null; _error = null; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _action == a['id'] ? theme.aiViolet.withValues(alpha: 0.14) : theme.bgCard.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _action == a['id'] ? theme.aiViolet : theme.glassBorder),
                      ),
                      child: Column(children: [
                        Icon(a['icon'] as IconData, size: 16, color: _action == a['id'] ? theme.aiViolet : theme.textFaint),
                        const SizedBox(height: 4),
                        Text(a['label'] as String, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _action == a['id'] ? theme.aiViolet : theme.textFaint)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 16),

          if (_action == 'draft') ...[
            Text('موضوع پیش‌نویس', style: TextStyle(color: theme.textFaint, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            HzTextField(controller: _topicCtrl, icon: Icons.lightbulb_outline_rounded, hint: 'مثلاً: نقش دمبوره در موسیقی هزارگی', theme: theme),
          ] else ...[
            Text('متن مبدأ', style: TextStyle(color: theme.textFaint, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _sourceCtrl,
              maxLines: 5,
              style: TextStyle(color: theme.textPrimary, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'متن را اینجا بچسبان…',
                hintStyle: TextStyle(color: theme.textFaint, fontSize: 12),
                filled: true, fillColor: theme.bgCard.withValues(alpha: 0.4),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.glassBorder)),
              ),
            ),
            if (_action == 'translate') ...[
              const SizedBox(height: 12),
              Text('زبان مقصد', style: TextStyle(color: theme.textFaint, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              HzSelectField(
                value: _targetLang,
                icon: Icons.language_rounded,
                hint: 'زبان مقصد',
                options: _kLanguages,
                theme: theme,
                onChanged: (v) => setState(() => _targetLang = v ?? 'فارسی'),
              ),
            ],
          ],
          const SizedBox(height: 18),

          HzPrimaryButton(
            label: _loading ? 'در حال تولید…' : 'تولید با هوش مصنوعی',
            icon: Icons.auto_awesome_rounded,
            loading: _loading,
            theme: theme,
            onPressed: _generate,
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: theme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.danger.withValues(alpha: 0.3))),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, size: 16, color: theme.danger),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: TextStyle(color: theme.danger, fontSize: 12.5))),
              ]),
            ),
          ],

          if (_result != null) ...[
            const SizedBox(height: 16),
            HzGlassCard(
              theme: theme,
              radius: 16,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.check_circle_outline_rounded, size: 15, color: theme.success),
                  const SizedBox(width: 6),
                  Text('نتیجه', style: TextStyle(color: theme.success, fontSize: 12.5, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _result!));
                      showHzToast(context, 'متن کپی شد');
                    },
                    child: Icon(Icons.copy_all_rounded, size: 16, color: theme.textFaint),
                  ),
                ]),
                const SizedBox(height: 8),
                SelectableText(_result!, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, height: 1.8)),
              ]),
            ).animate().fadeIn(duration: 260.ms).slideY(begin: 0.04, end: 0),
          ],
        ],
      );
  }
}
