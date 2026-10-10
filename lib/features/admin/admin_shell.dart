import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/section_style.dart';
import '../../core/widgets.dart';
import '../../data/sections.dart';
import '../../state/app_state.dart';
import '../home/section_card.dart';
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
import 'broadcast_page.dart';

class _NavItem {
  final String id;
  final String label;
  final IconData icon;
  final String? sectionId; // برای رنگ و آیکون اختصاصی بخش‌های محتوا
  _NavItem(this.id, this.label, this.icon, {this.sectionId});
}

/// پوسته‌ی پنل مدیریت — با همان نوار پایین شناور و همان کارت‌های بخش که
/// اپ کاربران دارد تا هر دو پنل یک زبان بصری داشته باشند؛ کشوی کناری برای
/// دسترسی به همه‌ی صفحه‌ها، و نشان‌های عددی برای کارهای در انتظار.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  String _page = 'overview';
  final _navQuery = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static final List<_NavItem> _overviewGroup = [
    _NavItem('overview', 'نمای کلی', Icons.dashboard_rounded),
    _NavItem('broadcast', 'ارسال اعلان همگانی', Icons.campaign_rounded),
    _NavItem('ai-tools', 'دستیار هوش مصنوعی', Icons.auto_awesome_rounded),
    _NavItem('account-settings', 'تنظیمات حساب', Icons.settings_rounded),
  ];
  static final List<_NavItem> _contentGroup = [
    _NavItem('content-hub', 'همه‌ی بخش‌ها', Icons.grid_view_rounded),
    _NavItem('content-dailyStory', 'روایت امروز', Icons.auto_stories_rounded, sectionId: 'dailyStory'),
    ...kSections
        .where((s) => s.id != 'oral' && s.id != 'articleWinners' && s.id != 'dailyStory')
        .map((s) => _NavItem('content-${s.id}', s.title, sectionStyle(s.id).icon, sectionId: s.id)),
  ];
  static final List<_NavItem> _communityGroup = [
    _NavItem('community', 'نظارت بر حافظه جمعی', Icons.forum_rounded),
    _NavItem('contest', 'مسابقه‌ی مقالات', Icons.emoji_events_rounded),
    _NavItem('donations', 'کمک‌های مالی', Icons.volunteer_activism_rounded),
    _NavItem('users', 'کاربران', Icons.groups_rounded),
    _NavItem('messages', 'پیام‌های کاربران', Icons.mail_rounded),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().loadAdminInbox());
  }

  @override
  void dispose() {
    _navQuery.dispose();
    super.dispose();
  }

  void _go(String id) {
    if (id == 'account-settings') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountSettingsScreen()));
      return;
    }
    setState(() => _page = id);
  }

  int _badgeFor(String id, AppState app) {
    switch (id) {
      case 'messages':
        return app.pendingMessagesCount;
      case 'donations':
        return app.pendingDonationsCount;
      case 'community':
        return app.pendingReportsCount;
      case 'contest':
        return app.activeSubmissionsCount;
    }
    return 0;
  }

  int get _tabIndex {
    if (_page == 'overview') return 0;
    if (_page.startsWith('content-')) return 1;
    if (_page == 'messages') return 2;
    if (_page == 'users') return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;

    // اعلانِ مدیر لمس شده (مثلاً «پیام تازه») — همان صفحه را باز کن
    final requested = app.consumeAdminRequestedPage();
    if (requested != null && requested != _page) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _page = requested);
      });
    }

    final communityBadge = app.pendingDonationsCount + app.pendingReportsCount + app.activeSubmissionsCount;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: _drawer(theme, app),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
          decoration: BoxDecoration(
            color: theme.bgElevated.withValues(alpha: 0.45),
            border: Border(bottom: BorderSide(color: theme.glassBorder)),
          ),
          child: Row(children: [
            IconButton(icon: Icon(Icons.menu_rounded, color: theme.textPrimary), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
            Expanded(
              child: Text(_titleFor(_page), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: KeyedSubtree(key: ValueKey(_page), child: _pageFor(_page)),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: HzGlassNavBar(
          theme: theme,
          selectedIndex: _tabIndex,
          onSelected: (i) {
            switch (i) {
              case 0:
                _go('overview');
              case 1:
                _go('content-hub');
              case 2:
                _go('messages');
              case 3:
                _go('users');
              default:
                _scaffoldKey.currentState?.openDrawer();
            }
          },
          items: [
            const HzGlassNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'نمای کلی'),
            const HzGlassNavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'محتوا'),
            HzGlassNavItem(icon: Icons.mail_outline_rounded, activeIcon: Icons.mail_rounded, label: 'پیام‌ها', badge: app.pendingMessagesCount),
            const HzGlassNavItem(icon: Icons.groups_outlined, activeIcon: Icons.groups_rounded, label: 'کاربران'),
            HzGlassNavItem(icon: Icons.apps_outlined, activeIcon: Icons.apps_rounded, label: 'بیشتر', badge: communityBadge),
          ],
        ),
      ),
    );
  }

  Widget _drawer(AppColors theme, AppState app) {
    final q = _navQuery.text.trim().toLowerCase();
    List<_NavItem> filterGroup(List<_NavItem> g) => q.isEmpty ? g : g.where((i) => i.label.toLowerCase().contains(q)).toList();
    final groups = {
      null: filterGroup(_overviewGroup),
      'جامعه و کاربران': filterGroup(_communityGroup),
      'مدیریت محتوا': filterGroup(_contentGroup),
    };

    return Drawer(
      backgroundColor: theme.bgElevated.withValues(alpha: 0.96),
      child: SafeArea(
        child: Column(children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.blueDeep, theme.blue, theme.aiViolet], begin: Alignment.topRight, end: Alignment.bottomLeft),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              HzBadge(
                theme: theme,
                size: 46,
                filled: true,
                avatarPath: app.avatarPath,
                child: Text(app.displayName.isNotEmpty ? app.displayName[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(app.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                  Text('مدیر کل سامانه', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _navQuery,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: theme.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'جست‌وجوی صفحه…',
                hintStyle: TextStyle(color: theme.textFaint, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: theme.textFaint, size: 19),
                isDense: true,
                filled: true,
                fillColor: theme.bgCard.withValues(alpha: 0.6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.glassBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.glassBorder)),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              children: [
                for (final entry in groups.entries)
                  if (entry.value.isNotEmpty) ...[
                    if (entry.key != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
                        child: Text(entry.key!, style: TextStyle(color: theme.textFaint, fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    for (final item in entry.value) _drawerTile(theme, app, item),
                  ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _drawerTile(AppColors theme, AppState app, _NavItem item) {
    final selected = _page == item.id;
    final badge = _badgeFor(item.id, app);
    final st = item.sectionId != null ? sectionStyle(item.sectionId!) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? theme.blue.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).pop();
            _go(item.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: st?.gradient,
                  color: st == null ? (selected ? theme.blue : theme.bgCard) : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 17, color: st != null || selected ? Colors.white : theme.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: selected ? theme.textPrimary : theme.textSecondary, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
              ),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: theme.danger, borderRadius: BorderRadius.circular(999)),
                  child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  String _titleFor(String page) {
    for (final g in [_overviewGroup, _contentGroup, _communityGroup]) {
      for (final i in g) {
        if (i.id == page) {
          if (page == 'content-hub') return 'مدیریت محتوا';
          if (page == 'content-music') return 'مدیریت هنرمندان و ویدیوها';
          if (page.startsWith('content-')) return 'مدیریت محتوا — ${i.label}';
          return i.label;
        }
      }
    }
    return 'پنل مدیریت';
  }

  Widget _pageFor(String page) {
    if (page == 'overview') return OverviewPage(onOpenPage: _go);
    if (page == 'broadcast') return const BroadcastPage();
    if (page == 'ai-tools') return const AiToolsPage();
    if (page == 'community') return const CommunityModerationPage();
    if (page == 'contest') return const ContestManagerPage();
    if (page == 'donations') return const DonationManagerPage();
    if (page == 'users') return const UsersPage();
    if (page == 'messages') return const MessagesPage();
    if (page == 'content-hub') return _ContentHub(onOpen: (id) => _go('content-$id'));
    if (page.startsWith('content-')) {
      final id = page.replaceFirst('content-', '');
      if (id == 'music') return const MusicManagerPage();
      return ContentManagerPage(sectionId: id);
    }
    return const SizedBox.shrink();
  }
}

/// انتخاب بخش برای مدیریت محتوا — همان کارت‌های «کاوش» اپ کاربران.
class _ContentHub extends StatelessWidget {
  final void Function(String sectionId) onOpen;
  const _ContentHub({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final sections = kSections.where((s) => s.id != 'oral' && s.id != 'articleWinners' && s.id != 'dailyStory').toList();
    final daily = sectionById('dailyStory');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text('بخشی را برای افزودن یا ویرایش محتوا انتخاب کنید', style: TextStyle(color: theme.textSecondary, fontSize: 12.5)),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: SectionCard(theme: theme, section: daily, wide: true, count: app.sectionItemCount('dailyStory'), onTap: () => onOpen('dailyStory')),
        ).staggered(0),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: sections.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.0),
          itemBuilder: (context, i) {
            final s = sections[i];
            final count = app.sectionItemCount(s.id);
            return SectionCard(theme: theme, section: s, count: count, onTap: () => onOpen(s.id)).staggered(i + 1);
          },
        ),
      ],
    );
  }
}

IconData iconForSectionId(String id) => sectionStyle(id).icon;
