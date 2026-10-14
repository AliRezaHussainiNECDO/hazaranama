import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../state/app_state.dart';

/// دکمه‌ی «ادامه با اپل» — فقط وقتی ورود با اپل در دسترس است نشان داده می‌شود.
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final apple = app.appleAvailable;
    if (!apple) return const SizedBox.shrink();
    final t = widget.theme;
    final buttons = <Widget>[
      if (apple)
        _SocialButton(
          label: 'ادامه با اپل',
          color: Colors.black,
          border: Colors.white24,
          mark: const Icon(Icons.apple, color: Colors.white, size: 24),
          busy: _busy == 'apple',
          onTap: _busy == null ? () => _run('apple', app.signInWithApple) : null,
        ),
    ];

    return Column(children: [
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: Container(height: 1, color: t.glassBorder)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('یا ادامه با', style: TextStyle(color: t.textFaint, fontSize: 11.5))),
        Expanded(child: Container(height: 1, color: t.glassBorder)),
      ]),
      const SizedBox(height: 14),
      for (var i = 0; i < buttons.length; i++) ...[if (i > 0) const SizedBox(height: 10), buttons[i]],
    ]);
  }

  Future<void> _run(String key, Future<String?> Function() f) async {
    setState(() => _busy = key);
    final e = await f();
    if (!mounted) return;
    setState(() => _busy = null);
    widget.onResult(e);
  }
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
