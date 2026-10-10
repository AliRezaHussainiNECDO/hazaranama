import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await context.read<AppState>().loadAllMessages();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;

    if (_loading) return const Center(child: CircularProgressIndicator());

    final newCount = app.allMessages.where((m) => m.status == MessageStatus.newMsg).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          StatIconBox(icon: Icons.mark_email_unread_outlined, color: theme.blue, size: 32),
          const SizedBox(width: 10),
          Expanded(child: Text('${app.allMessages.length} پیام ثبت‌شده · $newCount پیام تازه', style: TextStyle(color: theme.textFaint, fontSize: 12.5))),
        ]),
        const SizedBox(height: 16),
        if (app.allMessages.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('هنوز پیامی دریافت نشده است.', style: TextStyle(color: theme.textFaint, fontSize: 12)))),
        for (final (i, m) in app.allMessages.indexed) ...[
          _AdminMessageCard(theme: theme, message: m).staggered(i),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AdminMessageCard extends StatefulWidget {
  final AppColors theme;
  final ContactMessage message;
  const _AdminMessageCard({required this.theme, required this.message});

  @override
  State<_AdminMessageCard> createState() => _AdminMessageCardState();
}

class _AdminMessageCardState extends State<_AdminMessageCard> {
  bool _expanded = false;
  final _reply = TextEditingController();
  bool _sending = false;

  Future<void> _sendReply(AppState app) async {
    if (_reply.text.trim().isEmpty) return;
    setState(() => _sending = true);
    await app.replyToMessage(widget.message.id, _reply.text);
    if (mounted) {
      setState(() => _sending = false);
      showHzToast(context, 'پاسخ ارسال شد');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final m = widget.message;
    final app = context.watch<AppState>();
    final isNew = m.status == MessageStatus.newMsg;

    return Container(
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(18), border: Border.all(color: isNew ? theme.blue.withValues(alpha: 0.5) : theme.glassBorder, width: isNew ? 1.4 : 1)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: () {
            setState(() => _expanded = !_expanded);
            if (isNew) app.markMessageRead(m.id);
          },
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DonorRing(
                theme: theme, size: 46, childSize: 40, tier: app.donorTierForUserId(m.userId),
                child: HzBadge(theme: theme, size: 40, filled: true, avatarPath: m.userAvatar,
                  child: Text(m.userName.isNotEmpty ? m.userName[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(m.userName, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    _statusPill(theme, m.status),
                  ]),
                  const SizedBox(height: 3),
                  Text('${m.userEmail} · ${m.userCountry}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
                  const SizedBox(height: 8),
                  Text(m.message, maxLines: _expanded ? null : 2, overflow: _expanded ? null : TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.8)),
                  const SizedBox(height: 4),
                  Text(m.createdAtLabel, style: TextStyle(color: theme.textFaint, fontSize: 11)),
                ]),
              ),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: theme.textFaint, size: 18),
            ]),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(children: [
                _infoChip(theme, Icons.map_outlined, m.userOriginProvince),
              ]),
              const SizedBox(height: 12),
              if (m.adminReply != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: theme.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.success.withValues(alpha: 0.3))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('پاسخ ارسال‌شده', style: TextStyle(color: theme.success, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(m.adminReply!, style: TextStyle(color: theme.textPrimary, fontSize: 12, height: 1.8)),
                  ]),
                ),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: TextField(
                    controller: _reply,
                    maxLines: 3, minLines: 1,
                    style: TextStyle(color: theme.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: m.adminReply != null ? 'ارسال پاسخ تازه…' : 'پاسخ خود را بنویسید…',
                      hintStyle: TextStyle(color: theme.textFaint, fontSize: 12),
                      filled: true, fillColor: theme.bgCardAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.border)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _sending ? null : () => _sendReply(app),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: theme.blue),
                    child: _sending
                        ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, size: 16, color: Colors.white),
                  ),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }

  Widget _statusPill(theme, MessageStatus status) {
    final color = status == MessageStatus.replied ? theme.success : status == MessageStatus.read ? theme.textFaint : theme.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(messageStatusLabel(status), style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }

  Widget _infoChip(theme, IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: theme.bgCardAlt, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: theme.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 11.5)),
        ]),
      );
}
