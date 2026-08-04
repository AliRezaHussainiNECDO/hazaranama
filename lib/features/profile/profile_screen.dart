import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../core/app_logo.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../community/post_widgets.dart';
import '../donations/donation_screen.dart';
import 'account_settings_screen.dart';
import 'contact_us_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final myPosts = app.myPosts;
    final reactionsReceived = app.myReactionsReceived;
    final myComments = myPosts.fold<int>(0, (sum, p) => sum + p.commentsCount);
    final donorTier = donorTierForUser(app.currentUser, app.myDonationTotalUsd);
    final isAdmin = app.currentUser?.role == UserRole.admin;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        Center(
          child: Column(children: [
            DonorRing(
              theme: theme, tier: donorTier, size: 92, childSize: 72,
              child: HzBadge(theme: theme, size: 72, filled: true, avatarPath: app.avatarPath,
                child: const Icon(Icons.person, color: Colors.white, size: 28)),
            ),
            const SizedBox(height: 10),
            Text(app.displayName, style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const FlagStripe(width: 60),
          ]),
        ).animate().fadeIn(duration: 380.ms).scale(begin: const Offset(0.9, 0.9)),
        const SizedBox(height: 16),
        DonorTierCard(
          theme: theme, totalUsd: app.myDonationTotalUsd, isAdmin: isAdmin,
          onDonateTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DonationScreen())),
        ).animate(delay: 60.ms).fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountSettingsScreen())),
              icon: Icon(Icons.settings_outlined, size: 16, color: theme.textSecondary),
              label: Text('تنظیمات حساب', style: TextStyle(color: theme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: theme.border), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactUsScreen())),
              icon: const Icon(Icons.support_agent, size: 16),
              label: const Text('تماس با ما', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: theme.blue, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ]).animate(delay: 100.ms).fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _StatMini(theme: theme, label: 'پست‌های من', value: myPosts.length)),
          const SizedBox(width: 8),
          Expanded(child: _StatMini(theme: theme, label: 'واکنش‌های دریافتی', value: reactionsReceived)),
          const SizedBox(width: 8),
          Expanded(child: _StatMini(theme: theme, label: 'نظرهای من', value: myComments)),
        ]).animate(delay: 120.ms).fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
        const SizedBox(height: 20),
        Text('پست‌های من', style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (myPosts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder, style: BorderStyle.solid)),
            child: Center(child: Text('هنوز پستی نساخته‌ای', style: TextStyle(color: theme.textFaint, fontSize: 11.5))),
          ).animate(delay: 180.ms).fadeIn(duration: 350.ms)
        else
          for (final (i, post) in myPosts.indexed) ...[
            PostCard(post: post, onTap: () => Navigator.of(context).pushNamed('/post', arguments: post.id)).staggered(i),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _StatMini extends StatelessWidget {
  final AppColors theme;
  final String label;
  final int value;
  const _StatMini({required this.theme, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.glassBorder)),
      child: Column(children: [
        Text('$value', style: TextStyle(color: theme.blue, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: theme.textFaint, fontSize: 9.5), textAlign: TextAlign.center),
      ]),
    );
  }
}
