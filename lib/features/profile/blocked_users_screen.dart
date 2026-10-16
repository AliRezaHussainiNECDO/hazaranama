import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/widgets.dart';
import '../../state/app_state.dart';

/// فهرست کاربرانی که خودِ کاربر مسدود کرده — از «تنظیمات حساب» باز می‌شود.
/// از هرکدام می‌توان لغو مسدودی کرد تا پست/کامنتشان دوباره در فید دیده شود.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});
  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await context.read<AppState>().loadBlockedUsers();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final blocked = app.blockedUsers;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: AppBar(
                backgroundColor: theme.bgElevated.withValues(alpha: 0.5), elevation: 0,
                leading: IconButton(icon: Icon(Icons.arrow_forward_rounded, color: theme.textPrimary, size: 20), onPressed: () => Navigator.of(context).pop()),
                title: Text('کاربران مسدودشده', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.6)),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : blocked.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.block_rounded, size: 34, color: theme.textFaint),
                            const SizedBox(height: 12),
                            Text('هنوز هیچ‌کسی را مسدود نکرده‌اید', style: TextStyle(color: theme.textFaint, fontSize: 12.5)),
                            const SizedBox(height: 6),
                            Text(
                              'برای مسدودکردن یک کاربر، از منوی سه‌نقطه‌ی روی پست او در «حافظه‌ی جمعی» استفاده کنید.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.textFaint, fontSize: 12.5, height: 1.7),
                            ),
                          ]),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                        itemCount: blocked.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final b = blocked[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
                            child: Row(children: [
                              HzBadge(
                                theme: theme, size: 38, filled: true, avatarPath: b.blockedAvatarUrl,
                                child: Text(b.blockedName.isNotEmpty ? b.blockedName[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(b.blockedName, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                                  Text('مسدود از ${b.createdAtLabel}', style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
                                ]),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await context.read<AppState>().unblockUser(b.blockedId);
                                  if (context.mounted) showHzToast(context, '${b.blockedName} از حالت مسدود خارج شد');
                                },
                                child: Text('لغو مسدودی', style: TextStyle(color: theme.blue, fontSize: 12.5, fontWeight: FontWeight.w700)),
                              ),
                            ]),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}
