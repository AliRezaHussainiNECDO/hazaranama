import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

/// کارت پروفایل بالای صفحه‌ی خانه — بنر گرادیانی زنده با بلوب‌های شناور و
/// درخشش موربِ در حال حرکت، حلقه‌ی چرخان دور آواتار (به‌سبک استوری اینستاگرام)،
/// نشان نقش کاربر، تراشه‌های زادگاه/قوم، و سه آمار زنده با انیمیشن شمارش.
class ProfileHeader extends StatefulWidget {
  const ProfileHeader({super.key});
  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> with TickerProviderStateMixin {
  bool _editingName = false;
  bool _uploading = false;
  late TextEditingController _nameCtrl;
  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(AppState app) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (file == null) return;
    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      await app.uploadAvatar(file);
    } catch (_) {
      if (mounted) showHzToast(context, 'بارگذاری عکس ناموفق بود؛ دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    if (!_editingName) _nameCtrl.text = app.displayName;
    final user = app.currentUser;
    final myPostsCount = app.myPosts.length;
    final myReactions = app.myReactionsReceived;
    final myComments = app.myPosts.fold<int>(0, (s, p) => s + p.commentsCount);
    final donorTier = app.rankTierForUser(user);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: HzGlassCard(
        theme: theme,
        radius: 20,
        padding: EdgeInsets.zero,
        child: Column(children: [
          _buildBanner(theme),
          Transform.translate(
            offset: const Offset(0, -34),
            child: Center(child: _buildAvatar(theme, app, donorTier)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(children: [
              if (_editingName)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _nameCtrl,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.textPrimary),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true, fillColor: theme.bgCardAlt,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: theme.border)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  InkWell(
                    onTap: () {
                      if (_nameCtrl.text.trim().isNotEmpty) app.setDisplayName(_nameCtrl.text.trim());
                      setState(() => _editingName = false);
                    },
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(color: theme.blue, borderRadius: BorderRadius.circular(9)),
                      child: const Icon(Icons.check, size: 13, color: Colors.white),
                    ),
                  ),
                ])
              else
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(app.displayName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: theme.textPrimary)),
                  const SizedBox(width: 5),
                  InkWell(onTap: () => setState(() => _editingName = true), child: Icon(Icons.edit, size: 15, color: theme.textFaint)),
                  if (user != null && user.role != UserRole.user) ...[
                    const SizedBox(width: 7),
                    _RoleBadge(theme: theme, role: user.role),
                  ],
                  const SizedBox(width: 7),
                  DonorTierChip(tier: donorTier),
                ]),
              if (user?.email != null) ...[
                const SizedBox(height: 3),
                Text(user!.email, style: TextStyle(fontSize: 12, color: theme.textFaint)),
              ],
              const SizedBox(height: 9),
              _buildLocationChips(theme, user),
              const SizedBox(height: 10),
              _StatsRow(theme: theme, posts: myPostsCount, reactions: myReactions, comments: myComments),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildBanner(AppColors theme) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        height: 84,
        width: double.infinity,
        child: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          return AnimatedBuilder(
            animation: _bgCtrl,
            builder: (context, _) {
              final t = _bgCtrl.value;
              final shineX = -100 + (w + 200) * t;
              return Stack(children: [
                Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: theme.heroGradient))),
                Positioned(
                  left: w * 0.12 + 14 * math.sin(t * 2 * math.pi),
                  top: -22 + 8 * math.cos(t * 2 * math.pi),
                  child: _blob(theme.aiViolet.withValues(alpha: 0.36), 78),
                ),
                Positioned(
                  right: w * 0.08 + 11 * math.cos(t * 2 * math.pi),
                  bottom: -22 + 7 * math.sin(t * 2 * math.pi),
                  child: _blob(theme.aiTeal.withValues(alpha: 0.3), 62),
                ),
                Positioned.fill(
                  child: ClipRect(
                    child: Transform.translate(
                      offset: Offset(shineX, 0),
                      child: Transform.rotate(
                        angle: -0.45,
                        child: Container(width: 32, height: 160, color: Colors.white.withValues(alpha: 0.16)),
                      ),
                    ),
                  ),
                ),
              ]);
            },
          );
        }),
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
    );
  }

  Widget _buildAvatar(AppColors theme, AppState app, DonorTier? donorTier) {
    return SizedBox(
      width: 96, height: 96,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        DonorRing(
          theme: theme,
          tier: donorTier,
          size: 88,
          childSize: 66,
          child: HzBadge(
            theme: theme, size: 66, filled: true, avatarPath: app.avatarPath,
            child: Text(app.displayName.isNotEmpty ? app.displayName[0] : 'ه', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)),
          ),
        ),
        if (_uploading)
          Container(
            width: 66, height: 66,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.35)),
            child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
          ),
        Positioned(
          bottom: 0, left: 0,
          child: GestureDetector(
            onTap: _uploading ? null : () => _pickAvatar(app),
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, color: theme.yellow, border: Border.all(color: theme.bgCard, width: 2.6)),
              child: Icon(Icons.photo_camera, size: 12, color: theme.bg),
            ),
          ),
        ),
        Positioned(top: 2, right: 2, child: _PulsingDot(theme: theme)),
      ]),
    );
  }

  Widget _buildLocationChips(AppColors theme, UserProfile? user) {
    if (user == null) return const SizedBox.shrink();
    final chips = <Widget>[];
    if (user.originProvince.isNotEmpty && user.originProvince != 'نامشخص') {
      chips.add(_InfoChip(theme: theme, icon: Icons.location_on_rounded, label: user.originProvince));
    }
    if (user.tribe.isNotEmpty && user.tribe != '—' && user.tribe != 'نامشخص') {
      chips.add(_InfoChip(theme: theme, icon: Icons.groups_rounded, label: user.tribe));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: chips);
  }
}

/// نشانِ نقشِ کاربر (مدیر/ویراستار) — با گرادیان نرم و آیکن.
class _RoleBadge extends StatelessWidget {
  final AppColors theme;
  final UserRole role;
  const _RoleBadge({required this.theme, required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == UserRole.admin;
    final color = isAdmin ? theme.yellow : theme.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.24), color.withValues(alpha: 0.08)]),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isAdmin ? Icons.workspace_premium_rounded : Icons.edit_note_rounded, size: 12, color: color),
        const SizedBox(width: 2.5),
        Text(roleLabel(role), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

/// تراشه‌ی کوچک اطلاعاتی (زادگاه/قوم) با آیکن.
class _InfoChip extends StatelessWidget {
  final AppColors theme;
  final IconData icon;
  final String label;
  const _InfoChip({required this.theme, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: theme.bgCardAlt, borderRadius: BorderRadius.circular(999), border: Border.all(color: theme.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: theme.textFaint),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11.5, color: theme.textSecondary, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// نقطه‌ی سبزِ تپنده — نشانه‌ی «حساب فعال» روی گوشه‌ی آواتار.
class _PulsingDot extends StatefulWidget {
  final AppColors theme;
  const _PulsingDot({required this.theme});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return SizedBox(
          width: 14, height: 14,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 9 + t * 5, height: 9 + t * 5,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.theme.success.withValues(alpha: (1 - t) * 0.5)),
            ),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.theme.success, border: Border.all(color: widget.theme.bgCard, width: 1.6)),
            ),
          ]),
        );
      },
    );
  }
}

/// ردیف آمار زنده‌ی کاربر — پست‌ها، واکنش‌های دریافتی و نظرهای دریافتی،
/// با انیمیشن شمارشِ نرم هر بار که مقدار تغییر می‌کند.
class _StatsRow extends StatelessWidget {
  final AppColors theme;
  final int posts;
  final int reactions;
  final int comments;
  const _StatsRow({required this.theme, required this.posts, required this.reactions, required this.comments});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: theme.bgCardAlt.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
      child: Row(children: [
        Expanded(child: _StatCell(theme: theme, icon: Icons.dynamic_feed_rounded, value: posts, label: 'پست')),
        _StatDivider(theme: theme),
        Expanded(child: _StatCell(theme: theme, icon: Icons.favorite_rounded, value: reactions, label: 'واکنش')),
        _StatDivider(theme: theme),
        Expanded(child: _StatCell(theme: theme, icon: Icons.mode_comment_rounded, value: comments, label: 'نظر')),
      ]),
    );
  }
}

class _StatCell extends StatelessWidget {
  final AppColors theme;
  final IconData icon;
  final int value;
  final String label;
  const _StatCell({required this.theme, required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, size: 16, color: theme.blue),
      const SizedBox(height: 3),
      TweenAnimationBuilder<int>(
        tween: IntTween(begin: 0, end: value),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text('$v', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: theme.textPrimary)),
      ),
      const SizedBox(height: 1),
      Text(label, style: TextStyle(fontSize: 11, color: theme.textSecondary)),
    ]);
  }
}

class _StatDivider extends StatelessWidget {
  final AppColors theme;
  const _StatDivider({required this.theme});

  @override
  Widget build(BuildContext context) => Container(width: 1, height: 26, color: theme.border);
}
