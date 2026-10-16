import 'package:flutter/material.dart';

/// یک ردیف از جدول امتیاز فعالیت (XP) — از سرور (/xp/leaderboard و /xp/me)
class RankEntry {
  final String userId;
  final String name;
  final String? avatarPath;
  final String role;
  final int xp;
  final int position;
  final Map<String, int> stats;

  const RankEntry({
    required this.userId,
    required this.name,
    required this.avatarPath,
    required this.role,
    required this.xp,
    required this.position,
    required this.stats,
  });

  factory RankEntry.fromJson(Map<String, dynamic> j) {
    final raw = (j['stats'] as Map?) ?? const {};
    return RankEntry(
      userId: j['user_id'] as String,
      name: (j['name'] as String?) ?? 'کاربر هزاره‌نامه',
      avatarPath: j['avatar_path'] as String?,
      role: (j['role'] as String?) ?? 'user',
      xp: (j['xp'] as num?)?.toInt() ?? 0,
      position: (j['position'] as num?)?.toInt() ?? 0,
      stats: {for (final e in raw.entries) e.key.toString(): (e.value as num?)?.toInt() ?? 0},
    );
  }

  int stat(String k) => stats[k] ?? 0;
}

/// یک راه گرفتن امتیاز — برای کارت‌های «چطور مقام بگیرم؟»
class XpWay {
  final String key; // همان کلید stats در سرور
  final String title;
  final String hint;
  final IconData icon;
  final Color color;
  final int points;
  const XpWay(this.key, this.title, this.hint, this.icon, this.color, this.points);
}

/// باید با XP_RULES در cloudflare/api/src/xp.ts یکی بماند
const List<XpWay> kXpWays = [
  XpWay('visit', 'آمدن روزانه', 'هر روز که هزاره‌نامه را باز کنید', Icons.wb_sunny_rounded, Color(0xFFFFB547), 5),
  XpWay('read', 'خواندن', 'هر روایت، مقاله، شخصیت یا رویداد تازه', Icons.auto_stories_rounded, Color(0xFF5B93FF), 2),
  XpWay('video', 'تماشای ویدیو', 'هر ویدیوی موسیقی و فرهنگ', Icons.play_circle_fill_rounded, Color(0xFFFF6A8A), 2),
  XpWay('book', 'کتاب', 'دانلود یا خواندن هر کتاب کتابخانه', Icons.menu_book_rounded, Color(0xFF2FBE86), 3),
  XpWay('news', 'خبر', 'خواندن هر خبر خبرنامه', Icons.newspaper_rounded, Color(0xFF6BC8FF), 1),
  XpWay('post', 'پست', 'انتشار روایت و خاطره در «حافظه‌ی جمعی»', Icons.edit_note_rounded, Color(0xFFA06BFF), 15),
  XpWay('comment', 'کامنت', 'نظر روی پست، ویدیو یا مقاله', Icons.chat_bubble_rounded, Color(0xFF4FD1C5), 4),
  XpWay('reaction', 'واکنش', 'لایک و واکنش به کار دیگران', Icons.favorite_rounded, Color(0xFFFF5C7A), 1),
  XpWay('liked', 'لایک گرفتن', 'هر لایکی که پست شما می‌گیرد', Icons.volunteer_activism_rounded, Color(0xFFFF8A3D), 2),
  XpWay('article', 'مسابقه‌ی مقاله', 'فرستادن مقاله به مسابقه‌ی ماهانه', Icons.emoji_events_rounded, Color(0xFFFFC94D), 25),
  XpWay('featured', 'مقاله‌ی برگزیده', 'رتبه‌ی اول ۳۰۰، دوم ۲۰۰، سوم ۱۰۰', Icons.workspace_premium_rounded, Color(0xFFFFD36B), 100),
];
