import 'dart:math' show min;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import 'notification_router.dart';
import 'notification_style.dart';

/// صندوق اعلان‌ها — همه‌ی اعلان‌های خودِ کاربر جاری، تازه‌ترین بالا؛ از همان
/// ناقوس کنار لوگو در بالای اپ باز می‌شود.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await context.read<AppState>().loadNotifications();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final items = _unreadOnly ? app.notifications.where((n) => !n.isRead).toList() : app.notifications;

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
                title: Text('اعلان‌ها', style: TextStyle(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                actions: [
                  if (app.unreadNotificationCount > 0)
                    TextButton(
                      onPressed: () => app.markAllNotificationsRead(),
                      child: Text('خواندن همه', style: TextStyle(color: theme.blue, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.6)),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: app.notifications.isEmpty
                        ? ListView(children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: Center(
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.notifications_off_outlined, size: 40, color: theme.textFaint),
                                  const SizedBox(height: 10),
                                  Text('هنوز اعلانی ندارید', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                                ]),
                              ),
                            ),
                          ])
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                            children: [
                              _filterBar(theme, app),
                              ..._grouped(items, theme, app),
                            ],
                          ),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _filterBar(AppColors theme, AppState app) {
    Widget chip(String label, bool on, VoidCallback tap) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: ChoiceChip(
            label: Text(label, style: TextStyle(color: on ? Colors.white : theme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
            selected: on,
            onSelected: (_) => tap(),
            selectedColor: theme.blue,
            backgroundColor: theme.bgCard.withValues(alpha: 0.6),
            side: BorderSide(color: on ? theme.blue : theme.glassBorder),
            showCheckmark: false,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        chip('همه', !_unreadOnly, () => setState(() => _unreadOnly = false)),
        chip('خوانده‌نشده (${app.unreadNotificationCount})', _unreadOnly, () => setState(() => _unreadOnly = true)),
      ]),
    );
  }

  List<Widget> _grouped(List<AppNotification> items, AppColors theme, AppState app) {
    if (items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(children: [
            Icon(Icons.mark_email_read_outlined, size: 40, color: theme.textFaint),
            const SizedBox(height: 10),
            Text('همه‌ی اعلان‌ها را خوانده‌اید', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
          ]),
        ),
      ];
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String bucket(DateTime d) {
      final l = d.toLocal();
      final day = DateTime(l.year, l.month, l.day);
      final diff = today.difference(day).inDays;
      if (diff <= 0) return 'امروز';
      if (diff == 1) return 'دیروز';
      if (diff < 7) return 'این هفته';
      return 'پیش‌تر';
    }

    final out = <Widget>[];
    String? current;
    for (var i = 0; i < items.length; i++) {
      final n = items[i];
      final b = bucket(n.createdAt);
      if (b != current) {
        current = b;
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Text(b, style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w800)),
        ));
      }
      out.add(_tile(n, theme, app).animate(delay: (min(i, 12) * 35).ms).fadeIn(duration: 240.ms).slideX(begin: 0.03, end: 0));
    }
    return out;
  }

  Widget _tile(AppNotification n, AppColors theme, AppState app) {
    final color = notificationTypeColor(n.type, theme);
    final isAnnouncement = n.type == 'announcement';
    final navigable = n.refType != null || kAdminNotificationPages.containsKey(n.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            app.markNotificationRead(n.id);
            if (navigable) openNotificationTarget(context, app, NotificationTarget(type: n.type, refType: n.refType, refId: n.refId));
          },
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: n.isRead ? theme.bgCard.withValues(alpha: 0.55) : Color.alphaBlend(color.withValues(alpha: 0.1), theme.bgCard.withValues(alpha: 0.85)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: n.isRead ? theme.glassBorder : color.withValues(alpha: 0.4)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, Color.lerp(color, theme.aiViolet, 0.45)!]),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(notificationTypeIcon(n.type), color: Colors.white, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.title, style: TextStyle(color: theme.textPrimary, fontSize: 13.5, height: 1.5, fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800), maxLines: 3, overflow: TextOverflow.ellipsis),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(n.body, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.6), maxLines: isAnnouncement ? null : 2, overflow: isAnnouncement ? null : TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  Text(notificationTimeAgo(n.createdAt), style: TextStyle(color: theme.textFaint, fontSize: 11)),
                ]),
              ),
              const SizedBox(width: 6),
              Column(children: [
                if (!n.isRead) Container(width: 9, height: 9, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                if (navigable) ...[
                  const SizedBox(height: 10),
                  Icon(Icons.chevron_left_rounded, size: 20, color: theme.textFaint),
                ],
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
