import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/widgets.dart';
import '../../state/app_state.dart';
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
    final items = app.notifications;

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
                title: Text('اعلان‌ها', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                actions: [
                  if (app.unreadNotificationCount > 0)
                    TextButton(
                      onPressed: () => app.markAllNotificationsRead(),
                      child: Text('علامت‌زدن همه', style: TextStyle(color: theme.blue, fontSize: 12.5, fontWeight: FontWeight.w700)),
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
                    child: items.isEmpty
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
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final n = items[i];
                              final color = notificationTypeColor(n.type, theme);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => app.markNotificationRead(n.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: (n.isRead ? theme.bgCard : color.withValues(alpha: 0.08)).withValues(alpha: n.isRead ? 0.5 : 1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: n.isRead ? theme.glassBorder : color.withValues(alpha: 0.35)),
                                    ),
                                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      StatIconBox(icon: notificationTypeIcon(n.type), color: color, size: 36),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(n.title, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          if (n.body.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(n.body, style: TextStyle(color: theme.textSecondary, fontSize: 12.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          ],
                                          const SizedBox(height: 5),
                                          Text(notificationTimeAgo(n.createdAt), style: TextStyle(color: theme.textFaint, fontSize: 11)),
                                        ]),
                                      ),
                                      if (!n.isRead)
                                        Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4, right: 2), decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                                    ]),
                                  ),
                                ),
                              ).animate(delay: (i * 35).ms).fadeIn(duration: 240.ms).slideX(begin: 0.03, end: 0);
                            },
                          ),
                  ),
          ),
        ]),
      ),
    );
  }
}
