import 'package:flutter/material.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../contest/article_contest_screen.dart';
import '../donations/donation_screen.dart';
import '../profile/contact_us_screen.dart';
import 'notifications_screen.dart';

/// اعلان‌های مخصوص مدیر و صفحه‌ی پنل مدیریتی که هر کدام باز می‌کند.
const Map<String, String> kAdminNotificationPages = {
  'admin_message': 'messages',
  'admin_donation': 'donations',
  'admin_article': 'contest',
  'admin_report': 'community',
  'admin_new_user': 'users',
  'password_recovery_request': 'users',
};

/// با لمس یک اعلان (درون اپ یا پوش)، صفحه‌ی مربوط به آن را باز می‌کند.
Future<void> openNotificationTarget(BuildContext context, AppState app, NotificationTarget t) async {
  final nav = Navigator.of(context);
  final isAdmin = app.currentUser?.role == UserRole.admin;

  final adminPage = kAdminNotificationPages[t.type];
  if (adminPage != null) {
    if (isAdmin) {
      nav.popUntil((r) => r.isFirst);
      app.requestAdminPage(adminPage);
    }
    return;
  }

  switch (t.refType) {
    case 'post':
      if (t.refId == null) break;
      final ok = await app.ensurePostLoaded(t.refId!);
      if (!context.mounted) return;
      if (ok) {
        nav.pushNamed('/post', arguments: t.refId);
      } else {
        showHzToast(context, 'این پست دیگر در دسترس نیست.');
      }
      return;
    case 'article':
      nav.pushNamed('/section', arguments: 'articleWinners');
      return;
    case 'article_submission':
      nav.push(MaterialPageRoute(builder: (_) => const ArticleContestScreen()));
      return;
    case 'donation_transfer':
    case 'donor_tier':
      nav.push(MaterialPageRoute(builder: (_) => const DonationScreen()));
      return;
    case 'contact_message':
      nav.push(MaterialPageRoute(builder: (_) => const ContactUsScreen()));
      return;
    case 'video':
      nav.pushNamed('/section', arguments: 'music');
      return;
  }
  // اعلان همگانی و بقیه: صندوق اعلان‌ها
  if (ModalRoute.of(context)?.settings.name != '/notifications') {
    nav.push(MaterialPageRoute(settings: const RouteSettings(name: '/notifications'), builder: (_) => const NotificationsScreen()));
  }
}
