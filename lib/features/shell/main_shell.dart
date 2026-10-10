import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../admin/admin_shell.dart';
import '../ai/ai_assistant_screen.dart';
import '../notifications/notification_permission_sheet.dart';
import '../notifications/notification_style.dart';
import '../notifications/notifications_screen.dart';
import 'user_shell.dart';

/// پوسته‌ی اصلی برنامه پس از ورود — معادل MainApp در دموی وب.
/// بر اساس نقش کاربر، یا پنل مدیریت یا اپلیکیشن کاربران را نشان می‌دهد.
/// کاربر عادی هرگز راهی به پنل مدیریت ندارد.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final isAdmin = app.currentUser?.role == UserRole.admin;
    final showAdmin = isAdmin && !app.adminPreviewAsUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 1.5),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: AppBar(
                backgroundColor: theme.bgElevated.withValues(alpha: 0.55),
                elevation: 0,
                titleSpacing: 12,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1.5),
                  child: Container(height: 1.5, decoration: BoxDecoration(gradient: theme.heroGradient)),
                ),
                title: Row(children: [
                  const AppLogo(size: 32),
                  const SizedBox(width: 8),
                  Text('هزاره‌نامه', style: TextStyle(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                  if (isAdmin) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: theme.yellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999), border: Border.all(color: theme.yellow.withValues(alpha: 0.3))),
                      child: Text('مدیر', style: TextStyle(color: theme.yellow, fontSize: 9.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                actions: [
                  _NotificationBell(theme: theme, unreadCount: app.unreadNotificationCount),
                  IconButton(
                    tooltip: 'دستیار هوش مصنوعی',
                    icon: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: theme.aiGradient,
                        boxShadow: [BoxShadow(color: theme.aiViolet.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 3))],
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
                    ),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiAssistantScreen())),
                  ),
                  if (isAdmin)
                    IconButton(
                      tooltip: app.adminPreviewAsUser ? 'بازگشت به پنل مدیریت' : 'پیش‌نمایش کاربران',
                      icon: Icon(app.adminPreviewAsUser ? Icons.dashboard_outlined : Icons.visibility_outlined, color: theme.textSecondary, size: 20),
                      onPressed: () => app.toggleAdminPreview(),
                    ),
                  IconButton(
                    tooltip: app.isDark ? 'حالت روشن' : 'حالت تیره',
                    icon: Icon(app.isDark ? Icons.light_mode : Icons.dark_mode, color: app.isDark ? theme.yellow : theme.blue, size: 20),
                    onPressed: () => app.toggleTheme(),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.7)),
          Positioned.fill(child: showAdmin ? const AdminShell() : const UserShell()),
          if (app.incomingToast != null)
            Positioned(
              top: 10,
              right: 12,
              left: 12,
              child: SafeArea(
                bottom: false,
                child: _NotificationToast(
                  key: ValueKey(app.incomingToast!.id),
                  notification: app.incomingToast!,
                  theme: theme,
                  onDismiss: () => app.clearIncomingToast(),
                  onTap: () {
                    app.clearIncomingToast();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                  },
                ),
              ),
            ),
          if (app.showNotificationPermissionSheet)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: NotificationPermissionSheet(
                  theme: theme,
                  onAllow: () => app.grantNotificationPermission(),
                  onDecline: () => app.declineNotificationPermissionSheet(),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// آیکون ناقوس با نشان‌گر تعداد اعلان‌های نخوانده — کنار لوگو در بالای اپ،
/// از هر صفحه‌ای در دسترس است.
class _NotificationBell extends StatelessWidget {
  final AppColors theme;
  final int unreadCount;
  const _NotificationBell({required this.theme, required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      IconButton(
        tooltip: 'اعلان‌ها',
        icon: Icon(Icons.notifications_none_rounded, color: theme.textSecondary, size: 22),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      ),
      if (unreadCount > 0)
        Positioned(
          top: 6,
          left: 6,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: theme.danger,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: theme.bgElevated, width: 1.5),
              ),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800, height: 1.3),
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1, end: 1.14, duration: 900.ms, curve: Curves.easeInOut),
        ),
    ]);
  }
}

/// بنر پویای اعلانِ تازه — همان لحظه‌ای که از Realtime می‌رسد، از بالای صفحه
/// با انیمیشن ظاهر می‌شود و پس از چند ثانیه خودش کنار می‌رود.
class _NotificationToast extends StatefulWidget {
  final AppNotification notification;
  final AppColors theme;
  final VoidCallback onDismiss;
  final VoidCallback onTap;
  const _NotificationToast({super.key, required this.notification, required this.theme, required this.onDismiss, required this.onTap});

  @override
  State<_NotificationToast> createState() => _NotificationToastState();
}

class _NotificationToastState extends State<_NotificationToast> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final n = widget.notification;
    final color = notificationTypeColor(n.type, theme);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [theme.bgElevated.withValues(alpha: 0.98), theme.bgCard.withValues(alpha: 0.96)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatIconBox(icon: notificationTypeIcon(n.type), color: color, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5)),
                if (n.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 10.5)),
                ],
              ]),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: widget.onDismiss,
              child: Padding(padding: const EdgeInsets.all(3), child: Icon(Icons.close_rounded, size: 15, color: theme.textFaint)),
            ),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: -0.35, end: 0, duration: 420.ms, curve: Curves.easeOutBack);
  }
}
