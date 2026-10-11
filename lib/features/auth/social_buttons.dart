import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../state/app_state.dart';

/// دکمه‌های «ادامه با فیسبوک / ایکس» — فقط روش‌هایی که روی سرور فعال‌اند نشان داده می‌شوند.
class SocialAuthButtons extends StatefulWidget {
  final AppColors theme;
  final void Function(String? error) onResult;
  const SocialAuthButtons({super.key, required this.theme, required this.onResult});

  @override
  State<SocialAuthButtons> createState() => _SocialAuthButtonsState();
}

class _SocialAuthButtonsState extends State<SocialAuthButtons> {
  String? _busy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().loadOAuthProviders());
  }

  Future<void> _go(AppState app, String provider) async {
    setState(() => _busy = provider);
    final e = await app.signInWithProvider(provider);
    if (!mounted) return;
    setState(() => _busy = null);
    widget.onResult(e);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.oauthProviders ?? const {};
    if (!app.socialLoginSupported || !(p['facebook'] == true || p['x'] == true)) return const SizedBox.shrink();
    final t = widget.theme;

    return Column(children: [
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: Container(height: 1, color: t.glassBorder)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('یا ادامه با', style: TextStyle(color: t.textFaint, fontSize: 11.5))),
        Expanded(child: Container(height: 1, color: t.glassBorder)),
      ]),
      const SizedBox(height: 14),
      if (p['facebook'] == true)
        _SocialButton(
          label: 'ادامه با فیسبوک',
          color: const Color(0xFF1877F2),
          mark: const _Mark(text: 'f', bg: Colors.white, fg: Color(0xFF1877F2), fontSize: 19),
          busy: _busy == 'facebook',
          onTap: _busy == null ? () => _go(app, 'facebook') : null,
        ),
      if (p['facebook'] == true && p['x'] == true) const SizedBox(height: 10),
      if (p['x'] == true)
        _SocialButton(
          label: 'ادامه با X (توییتر)',
          color: const Color(0xFF0F1419),
          border: Colors.white24,
          mark: const _Mark(text: 'X', bg: Colors.white, fg: Color(0xFF0F1419), fontSize: 13),
          busy: _busy == 'x',
          onTap: _busy == null ? () => _go(app, 'x') : null,
        ),
    ]);
  }
}

class _Mark extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final double fontSize;
  const _Mark({required this.text, required this.bg, required this.fg, required this.fontSize});
  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Text(text, style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w900, height: 1.15, fontFamily: 'Roboto')),
      );
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color? border;
  final Widget mark;
  final bool busy;
  final VoidCallback? onTap;
  const _SocialButton({required this.label, required this.color, required this.mark, required this.busy, required this.onTap, this.border});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: border == null ? BorderSide.none : BorderSide(color: border!)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (busy)
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
            else
              mark,
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}
