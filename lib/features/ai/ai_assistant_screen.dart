import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/widgets.dart';
import '../../core/app_logo.dart';
import '../../core/app_colors.dart';
import '../../state/app_state.dart';
import '../../services/ai_service.dart';

/// صفحه‌ی دستیار گفتگوی هوشمند — گفتگوی آزاد درباره‌ی تاریخ، فرهنگ و
/// هرچیزی که کاربر درباره‌ی هزاره‌نامه می‌خواهد بداند. تمام درخواست‌ها از
/// طریق ai-gateway (Edge Function امن) پردازش می‌شوند.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _ai = AiService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<AiChatMessage> _messages = [];
  bool _sending = false;

  static const List<String> _starters = [
    'خاستگاه تاریخی مردم هزاره را برایم خلاصه کن',
    'دمبوره چیست و در فرهنگ هزارگی چه جایگاهی دارد؟',
    'چند واژه‌ی زیبای هزارگی با معنی‌شان بگو',
    'هزارستان دقیقاً کجاست؟',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(AiChatMessage(fromUser: true, text: text));
      _input.clear();
      _sending = true;
    });
    _scrollToEnd();
    try {
      final reply = await _ai.chat(message: text, history: _messages);
      if (!mounted) return;
      setState(() => _messages.add(AiChatMessage(fromUser: false, text: reply.isEmpty ? 'پاسخی دریافت نشد؛ دوباره تلاش کنید.' : reply)));
    } on AiServiceException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(AiChatMessage(fromUser: false, text: '⚠️ ${e.message}')));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                flexibleSpace: Container(decoration: BoxDecoration(gradient: theme.aiGradient)),
                titleSpacing: 8,
                title: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text('راهنمای هزاره‌نامه', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme)),
          SafeArea(
            child: Column(children: [
              Expanded(
                child: _messages.isEmpty
                    ? _WelcomePane(theme: theme, starters: _starters, onPick: _send)
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                        itemCount: _messages.length + (_sending ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= _messages.length) {
                            return _Bubble(theme: theme, fromUser: false, child: TypingDots(color: theme.aiViolet));
                          }
                          final m = _messages[i];
                          return _Bubble(theme: theme, fromUser: m.fromUser, child: Text(m.text, style: TextStyle(color: m.fromUser ? Colors.white : theme.textPrimary, fontSize: 12.5, height: 1.6)))
                              .staggered(0, step: Duration.zero);
                        },
                      ),
              ),
              _Composer(theme: theme, controller: _input, sending: _sending, onSend: () => _send()),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _WelcomePane extends StatelessWidget {
  final AppColors theme;
  final List<String> starters;
  final void Function(String) onPick;
  const _WelcomePane({required this.theme, required this.starters, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
      children: [
        Center(child: Container(
          width: 68, height: 68,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: theme.aiGradient, boxShadow: [BoxShadow(color: theme.aiViolet.withValues(alpha: 0.35), blurRadius: 24)]),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
        )).animate().scale(begin: const Offset(0.7, 0.7), duration: 420.ms, curve: Curves.easeOutBack).fadeIn(),
        const SizedBox(height: 16),
        Text('سلام همسفر 👋', textAlign: TextAlign.center, style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('هرچه درباره‌ی تاریخ، فرهنگ، زبان یا مردم هزاره می‌خواهی بدانی، از من بپرس.',
            textAlign: TextAlign.center, style: TextStyle(color: theme.textFaint, fontSize: 12, height: 1.6)),
        const SizedBox(height: 22),
        for (var i = 0; i < starters.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onPick(starters[i]),
              child: HzGlassCard(
                theme: theme,
                radius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Icon(Icons.bolt, size: 15, color: theme.aiViolet),
                  const SizedBox(width: 8),
                  Expanded(child: Text(starters[i], style: TextStyle(color: theme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          ).staggered(i),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final AppColors theme;
  final bool fromUser;
  final Widget child;
  const _Bubble({required this.theme, required this.fromUser, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: fromUser ? theme.aiGradient : null,
          color: fromUser ? null : theme.bgCard.withValues(alpha: 0.6),
          borderRadius: BorderRadius.only(
            topRight: const Radius.circular(16),
            topLeft: const Radius.circular(16),
            bottomRight: Radius.circular(fromUser ? 16 : 4),
            bottomLeft: Radius.circular(fromUser ? 4 : 16),
          ),
          border: fromUser ? null : Border.all(color: theme.glassBorder),
          boxShadow: fromUser ? [BoxShadow(color: theme.aiViolet.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))] : null,
        ),
        child: child,
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final AppColors theme;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer({required this.theme, required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(color: theme.bgElevated.withValues(alpha: 0.55), border: Border(top: BorderSide(color: theme.glassBorder))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: TextStyle(color: theme.textPrimary, fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'پیامت را بنویس…',
                  hintStyle: TextStyle(color: theme.textFaint, fontSize: 12.5),
                  filled: true,
                  fillColor: theme.bgCard.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: theme.glassBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: theme.glassBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: theme.aiViolet)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Pressable(
              onTap: sending ? null : onSend,
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: theme.aiGradient,
                  boxShadow: [BoxShadow(color: theme.aiViolet.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: sending
                    ? const Padding(padding: EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Colors.white, size: 17),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
