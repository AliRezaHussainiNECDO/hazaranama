import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});
  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _text = TextEditingController();
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await context.read<AppState>().loadMyMessages();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _send(AppState app) async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    await app.sendContactMessage(_text.text);
    _text.clear();
    if (mounted) {
      setState(() => _sending = false);
      showHzToast(context, 'پیام شما برای مدیر ارسال شد');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;

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
                leading: IconButton(icon: Icon(Icons.arrow_forward_rounded, color: theme.textPrimary, size: 20), onPressed: () => Navigator.of(context).pop()),
                title: Text('تماس با ما', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.6)),
          SafeArea(
          child: Column(children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [theme.blue.withValues(alpha: 0.16), theme.yellow.withValues(alpha: 0.08)]),
                            borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.glassBorder),
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            StatIconBox(icon: Icons.support_agent_rounded, color: theme.blue, size: 34),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'پیام، پیشنهاد یا مشکلی دارید؟ مستقیم برای مدیر هزاره‌نامه بنویسید؛ پاسخ اینجا نمایش داده می‌شود.',
                                style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.8),
                              ),
                            ),
                          ]),
                        ).animate().fadeIn(duration: 300.ms),
                        const SizedBox(height: 18),
                        if (app.myMessages.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: Text('هنوز پیامی نفرستاده‌ای', style: TextStyle(color: theme.textFaint, fontSize: 12))),
                          )
                        else
                          for (final (i, m) in app.myMessages.indexed) ...[
                            _MessageCard(theme: theme, message: m).staggered(i),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.glassBorder)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      maxLines: 4, minLines: 1,
                      style: TextStyle(color: theme.textPrimary, fontSize: 12.5),
                      decoration: InputDecoration.collapsed(
                        hintText: 'پیام‌تان را بنویسید…',
                        hintStyle: TextStyle(color: theme.textFaint, fontSize: 12.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _sending ? null : () => _send(app),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: theme.blue),
                      child: _sending
                          ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
          ),
        ]),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final AppColors theme;
  final ContactMessage message;
  const _MessageCard({required this.theme, required this.message});

  @override
  Widget build(BuildContext context) {
    final replied = message.status == MessageStatus.replied;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(Icons.person_rounded, size: 13, color: theme.textFaint),
            const SizedBox(width: 5),
            Text('پیام شما', style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (replied ? theme.success : theme.yellow).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(messageStatusLabel(message.status), style: TextStyle(color: replied ? theme.success : theme.yellow, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(message.message, style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.8)),
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(message.createdAtLabel, style: TextStyle(color: theme.textFaint, fontSize: 11))),
        if (message.adminReply != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: theme.blue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.blue.withValues(alpha: 0.25))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.support_agent_rounded, size: 13, color: theme.blue),
                const SizedBox(width: 5),
                Text('پاسخ مدیر', style: TextStyle(color: theme.blue, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              Text(message.adminReply!, style: TextStyle(color: theme.textPrimary, fontSize: 12, height: 1.8)),
            ]),
          ),
        ],
      ]),
    );
  }
}
