import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets.dart';
import '../../data/sections.dart';
import '../../state/app_state.dart';
import '../profile/account_settings_screen.dart';
import 'overview_page.dart';
import 'content_manager_page.dart';
import 'users_page.dart';
import 'community_moderation_page.dart';
import 'messages_page.dart';
import 'ai_tools_page.dart';
import 'music_manager_page.dart';
import 'contest_manager_page.dart';
import 'donation_manager_page.dart';

class _NavItem {
  final String id;
  final String label;
  final IconData icon;
  _NavItem(this.id, this.label, this.icon);
}

/// پوسته‌ی پنل مدیریت — معادل AdminDashboard در دموی وب، با یک Drawer
/// گروه‌بندی‌شده و قابل‌جستجو به‌جای نوار کناری عریض (که برای موبایل مناسب نیست).
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  String _page = 'overview';
  final _navQuery = TextEditingController();

  static final List<_NavItem> _overviewGroup = [
    _NavItem('overview', 'نمای کلی', Icons.dashboard_outlined),
    _NavItem('ai-tools', 'دستیار هوش مصنوعی', Icons.auto_awesome),
    _NavItem('account-settings', 'تنظیمات حساب', Icons.settings_outlined),
  ];
  static final List<_NavItem> _contentGroup = [
    _NavItem('content-dailyStory', 'روایت امروز', Icons.auto_awesome),
    ...kSections.where((s) => s.id != 'oral' && s.id != 'articleWinners').map((s) => _NavItem('content-${s.id}', s.title, iconForSectionId(s.id))),
  ];
  static final List<_NavItem> _communityGroup = [
    _NavItem('community', 'نظارت بر حافظه جمعی', Icons.forum_outlined),
    _NavItem('contest', 'مسابقه‌ی مقالات', Icons.emoji_events_outlined),
    _NavItem('donations', 'کمک‌های مالی', Icons.volunteer_activism_outlined),
    _NavItem('users', 'کاربران', Icons.groups_outlined),
    _NavItem('messages', 'پیام‌های کاربران', Icons.mail_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final q = _navQuery.text.trim().toLowerCase();

    List<_NavItem> filterGroup(List<_NavItem> g) =>
        q.isEmpty ? g : g.where((i) => i.label.toLowerCase().contains(q)).toList();

    final groups = {
      null: filterGroup(_overviewGroup),
      'مدیریت محتوا': filterGroup(_contentGroup),
      'جامعه و کاربران': filterGroup(_communityGroup),
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        backgroundColor: theme.bgElevated.withValues(alpha: 0.86),
        child: SafeArea(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.blue, theme.blueDeep, theme.yellow], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Row(children: [
                HzBadge(theme: theme, size: 44, filled: true, avatarPath: app.avatarPath,
                    child: Text(app.displayName.isNotEmpty ? app.displayName[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(app.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    const Text('مدیر کل سامانه', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: HzTextField(controller: _navQuery, icon: Icons.search, hint: 'جست‌وجوی بخش…', theme: theme),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final entry in groups.entries)
                    if (entry.value.isNotEmpty) ...[
                      if (entry.key != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Text(entry.key!, style: TextStyle(color: theme.textFaint, fontSize: 10.5, fontWeight: FontWeight.w700)),
                        ),
                      for (final item in entry.value)
                        ListTile(
                          dense: true,
                          leading: Icon(item.icon, size: 18, color: _page == item.id ? theme.blue : theme.textSecondary),
                          title: Text(item.label, style: TextStyle(fontSize: 12.5, color: _page == item.id ? theme.blue : theme.textSecondary, fontWeight: _page == item.id ? FontWeight.w700 : FontWeight.w500)),
                          selected: _page == item.id,
                          selectedTileColor: theme.blue.withValues(alpha: 0.1),
                          onTap: () {
                            Navigator.of(context).pop();
                            if (item.id == 'account-settings') {
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountSettingsScreen()));
                            } else {
                              setState(() => _page = item.id);
                            }
                          },
                        ),
                    ],
                ],
              ),
            ),
          ]),
        ),
      ),
      body: Builder(builder: (context) {
        return Column(children: [
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: theme.bgElevated.withValues(alpha: 0.5),
                  border: Border(bottom: BorderSide(color: theme.glassBorder)),
                ),
                child: Row(children: [
                  IconButton(icon: Icon(Icons.menu, color: theme.textPrimary), onPressed: () => Scaffold.of(context).openDrawer()),
                  Expanded(child: Text(_titleFor(_page), style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800))),
                ]),
              ),
            ),
          ),
          Expanded(child: _pageFor(_page)),
        ]);
      }),
    );
  }

  String _titleFor(String page) {
    if (page == 'overview') return 'نمای کلی';
    if (page == 'ai-tools') return 'دستیار هوش مصنوعی';
    if (page == 'community') return 'نظارت بر حافظه جمعی';
    if (page == 'contest') return 'مدیریت مسابقه‌ی مقالات';
    if (page == 'donations') return 'مدیریت کمک‌های مالی';
    if (page == 'users') return 'کاربران';
    if (page == 'messages') return 'پیام‌های کاربران';
    if (page.startsWith('content-')) {
      final id = page.replaceFirst('content-', '');
      if (id == 'dailyStory') return 'مدیریت محتوا — روایت امروز';
      if (id == 'music') return 'مدیریت هنرمندان و ویدیوها — موسیقی و شعر';
      return 'مدیریت محتوا — ${sectionById(id).title}';
    }
    return 'پنل مدیریت';
  }

  Widget _pageFor(String page) {
    if (page == 'overview') return const OverviewPage();
    if (page == 'ai-tools') return const AiToolsPage();
    if (page == 'community') return const CommunityModerationPage();
    if (page == 'contest') return const ContestManagerPage();
    if (page == 'donations') return const DonationManagerPage();
    if (page == 'users') return const UsersPage();
    if (page == 'messages') return const MessagesPage();
    if (page.startsWith('content-')) {
      final id = page.replaceFirst('content-', '');
      if (id == 'music') return const MusicManagerPage();
      return ContentManagerPage(sectionId: id);
    }
    return const SizedBox.shrink();
  }
}

IconData iconForSectionId(String id) {
  const map = {
    'identity': Icons.account_balance,
    'figures': Icons.groups,
    'genocide': Icons.history_edu,
    'culture': Icons.auto_awesome,
    'music': Icons.music_note,
    'language': Icons.translate,
    'map': Icons.map,
    'album': Icons.image,
    'news': Icons.newspaper,
    'library': Icons.menu_book,
    'articleWinners': Icons.emoji_events,
  };
  return map[id] ?? Icons.circle;
}
