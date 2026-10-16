import 'package:flutter/material.dart';
import '../models/models.dart';

/// هویت رنگی هر بخش — دو رنگ برای گرادیان آیکون/سربرگ و یک آیکون.
/// همه‌ی کارت‌ها، دسترسی سریع و سربرگ صفحه‌ی هر بخش از همین‌جا رنگ می‌گیرند
/// تا هر «دروازه» چهره‌ی خودش را داشته باشد.
class SectionStyle {
  final Color a;
  final Color b;
  final IconData icon;
  const SectionStyle(this.a, this.b, this.icon);

  LinearGradient get gradient => LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [a, b]);
}

const Map<String, SectionStyle> kSectionStyles = {
  'identity': SectionStyle(Color(0xFF5B93FF), Color(0xFF7C5CFF), Icons.account_balance_rounded),
  'figures': SectionStyle(Color(0xFFFFB547), Color(0xFFFF7A45), Icons.groups_rounded),
  'genocide': SectionStyle(Color(0xFFFF6B85), Color(0xFFA8325E), Icons.local_florist_rounded),
  'culture': SectionStyle(Color(0xFFB57BFF), Color(0xFFF472B6), Icons.auto_awesome_rounded),
  'music': SectionStyle(Color(0xFFF472B6), Color(0xFFFB923C), Icons.music_note_rounded),
  'language': SectionStyle(Color(0xFF2FE3D6), Color(0xFF3B82F6), Icons.translate_rounded),
  'map': SectionStyle(Color(0xFF4EDBA0), Color(0xFF15936A), Icons.map_rounded),
  'album': SectionStyle(Color(0xFF38BDF8), Color(0xFF5B5BFF), Icons.photo_library_rounded),
  'news': SectionStyle(Color(0xFFFB923C), Color(0xFFE5484D), Icons.newspaper_rounded),
  'library': SectionStyle(Color(0xFFE0B07A), Color(0xFFA0642B), Icons.menu_book_rounded),
  'oral': SectionStyle(Color(0xFF2FE3D6), Color(0xFF4EDBA0), Icons.mic_rounded),
  'dailyStory': SectionStyle(Color(0xFFA06BFF), Color(0xFF2FE3D6), Icons.auto_stories_rounded),
  'articleWinners': SectionStyle(Color(0xFFFFD166), Color(0xFFE09B12), Icons.emoji_events_rounded),
};

SectionStyle sectionStyle(String id) =>
    kSectionStyles[id] ?? const SectionStyle(Color(0xFF5B93FF), Color(0xFF7C5CFF), Icons.circle_rounded);

/// برچسب شمارش برای کارت بخش (مثلاً «۵۳ رویداد»)
String sectionCountLabel(ContentSection s, int n) {
  if (n <= 0) return '';
  const unit = {
    'identity': 'فصل',
    'figures': 'چهره',
    'genocide': 'رویداد',
    'culture': 'روایت',
    'language': 'واژه',
    'map': 'منطقه',
    'album': 'تصویر',
    'news': 'خبر',
    'library': 'منبع',
    'music': 'هنرمند',
    'dailyStory': 'روایت',
  };
  return '$n ${unit[s.id] ?? 'مطلب'}';
}

/// نام کوتاه هر بخش برای جاهای تنگ (دسترسی سریع)
const Map<String, String> kSectionShortTitles = {
  'identity': 'تاریخ',
  'figures': 'چهره‌ها',
  'genocide': 'نسل‌کشی',
  'culture': 'فرهنگ',
  'music': 'موسیقی',
  'language': 'زبان',
  'map': 'نقشه',
  'album': 'آلبوم',
  'news': 'خبرنامه',
  'library': 'کتابخانه',
  'oral': 'حافظه جمعی',
  'articleWinners': 'برگزیدگان',
};

String sectionShortTitle(ContentSection s) => kSectionShortTitles[s.id] ?? s.title.split(' ').first;

/// شمار واژه‌های واژه‌نامه‌ی نبی‌زاده که داخل خودِ اپ است (assets/data/hazaragi_glossary.json)
const int kHazaragiGlossaryCount = 2005;
