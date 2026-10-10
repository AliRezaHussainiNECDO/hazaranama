import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets.dart';
import '../../state/app_state.dart';
import '../home/home_screen.dart';
import '../explore/explore_screen.dart';
import '../community/community_screen.dart';
import '../search/search_screen.dart';
import '../profile/profile_screen.dart';

/// پوسته‌ی اپلیکیشن کاربران — معادل UserApp در دموی وب.
/// یک BottomNavigationBar واقعی به‌جای نوار پایین شبیه‌سازی‌شده‌ی وب.
class UserShell extends StatefulWidget {
  final VoidCallback? onWantExplore;
  const UserShell({super.key, this.onWantExplore});

  @override
  State<UserShell> createState() => UserShellState();
}

class UserShellState extends State<UserShell> {
  int _tab = 0;

  void goToTab(int i) => setState(() => _tab = i);
  void goToCommunity() => setState(() => _tab = 2);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;

    final pages = [
      HomeScreen(onOpenExplore: () => goToTab(1), onOpenSection: _openSection, onOpenProfile: () => goToTab(4)),
      ExploreScreen(onOpenSection: _openSection),
      const CommunityScreen(),
      SearchScreen(onOpenSection: _openSection),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: SafeArea(bottom: false, child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: SafeArea(
        child: HzGlassNavBar(
          theme: theme,
          selectedIndex: _tab,
          onSelected: goToTab,
          items: const [
            HzGlassNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'خانه'),
            HzGlassNavItem(icon: Icons.explore_outlined, activeIcon: Icons.explore, label: 'کاوش'),
            HzGlassNavItem(icon: Icons.forum_outlined, activeIcon: Icons.forum, label: 'حافظه جمعی'),
            HzGlassNavItem(icon: Icons.search, activeIcon: Icons.search, label: 'جستجو'),
            HzGlassNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'پروفایل'),
          ],
        ),
      ),
    );
  }

  void _openSection(String sectionId) {
    if (sectionId == 'oral') {
      goToTab(2);
    } else {
      Navigator.of(context).pushNamed('/section', arguments: sectionId);
    }
  }
}
