import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_logo.dart';
import '../../state/app_state.dart';
import '../rank/rank_screen.dart';
import '../community/post_widgets.dart';
import '../home/profile_header.dart';
import 'account_settings_screen.dart';
import 'contact_us_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final myPosts = app.myPosts;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        const ProfileHeader().animate().fadeIn(duration: 380.ms).slideY(begin: -0.04, end: 0),
        const SizedBox(height: 4),
        RankCard(theme: theme).animate(delay: 60.ms).fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountSettingsScreen())),
              icon: Icon(Icons.settings_outlined, size: 16, color: theme.textSecondary),
              label: Text('تنظیمات حساب', style: TextStyle(color: theme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: theme.border), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactUsScreen())),
              icon: const Icon(Icons.support_agent, size: 16),
              label: const Text('تماس با ما', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: theme.blue, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ]).animate(delay: 100.ms).fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 20),
        Text('پست‌های من', style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (myPosts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder, style: BorderStyle.solid)),
            child: Center(child: Text('هنوز پستی نساخته‌ای', style: TextStyle(color: theme.textFaint, fontSize: 12.5))),
          ).animate(delay: 180.ms).fadeIn(duration: 350.ms)
        else
          for (final (i, post) in myPosts.indexed) ...[
            PostCard(post: post, onTap: () => Navigator.of(context).pushNamed('/post', arguments: post.id)).staggered(i),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => _confirmLogout(context, app),
          icon: Icon(Icons.logout_rounded, size: 18, color: theme.danger),
          label: Text('خروج از حساب', style: TextStyle(color: theme.danger, fontSize: 13, fontWeight: FontWeight.w800)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: theme.danger.withValues(alpha: 0.45)),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context, AppState app) async {
    final theme = app.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: theme.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('خروج از حساب؟', style: TextStyle(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
          content: Text('برای استفاده‌ی دوباره باید با ایمیل و رمز عبور وارد شوید.', style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.6)),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('انصراف', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w700))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: theme.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('خروج', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await app.logout();
  }
}
