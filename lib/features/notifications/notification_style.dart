import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

/// آیکون و رنگ متناسب با نوع اعلان — برای ناقوس، بنر پویا و صندوق اعلان‌ها.
/// نوع‌ها دقیقاً همان مقادیری‌اند که سرور (cloudflare/api/src/hooks.ts) در ستون
/// notifications.type می‌نویسد.
IconData notificationTypeIcon(String type) {
  switch (type) {
    case 'post_comment':
    case 'post_reply':
      return Icons.forum_rounded;
    case 'video_reply':
      return Icons.smart_display_rounded;
    case 'article_comment':
    case 'article_reply':
      return Icons.article_rounded;
    case 'article_featured':
      return Icons.emoji_events_rounded;
    case 'article_status':
      return Icons.fact_check_rounded;
    case 'donation_status':
      return Icons.volunteer_activism_rounded;
    case 'level10_reached':
      return Icons.emoji_events_rounded;
    case 'message_reply':
      return Icons.support_agent_rounded;
    case 'password_recovery_request':
      return Icons.key_rounded;
    default:
      return Icons.notifications_rounded;
  }
}

Color notificationTypeColor(String type, AppColors theme) {
  switch (type) {
    case 'post_comment':
    case 'post_reply':
    case 'video_reply':
    case 'article_comment':
    case 'article_reply':
      return theme.blue;
    case 'article_featured':
      return theme.yellow;
    case 'article_status':
      return theme.aiViolet;
    case 'donation_status':
      return theme.success;
    case 'level10_reached':
      return theme.yellow;
    case 'message_reply':
      return theme.aiTeal;
    case 'password_recovery_request':
      return theme.yellow;
    default:
      return theme.blue;
  }
}

String notificationTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'همین الان';
  if (diff.inHours < 1) return '${diff.inMinutes} دقیقه پیش';
  if (diff.inDays < 1) return '${diff.inHours} ساعت پیش';
  if (diff.inDays < 30) return '${diff.inDays} روز پیش';
  return '${(diff.inDays / 30).floor()} ماه پیش';
}
