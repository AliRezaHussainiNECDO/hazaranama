import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/widgets.dart';
import '../../state/app_state.dart';

/// صفحه‌ی «تنظیم رمز تازه» — آخرین گام بازیابی رمز عبور. کاربر از طریق پیوند
/// ایمیل‌شده (Supabase) با یک نشست موقتِ بازیابی به این صفحه می‌رسد (نگاه
/// کنید به AppState → passwordRecovery listener). یک شاخص قدرت رمز زنده،
/// تطبیق آنیِ دو فیلد، و یک لحظه‌ی جشنِ کوتاه هنگام موفقیت دارد.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPass = false;
  bool _showConfirm = false;
  bool _loading = false;
  bool _success = false;
  String? _error;
  int _strength = 0;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() => _strength = _calcStrength(_password.text)));
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  int _calcStrength(String p) {
    if (p.isEmpty) return 0;
    var score = 1;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    return score.clamp(0, 5);
  }

  (String, Color) _strengthMeta(AppColors theme) {
    switch (_strength) {
      case 0:
        return ('', theme.border);
      case 1:
      case 2:
        return ('ضعیف', theme.danger);
      case 3:
        return ('متوسط', theme.yellow);
      case 4:
        return ('خوب', theme.blue);
      default:
        return ('عالی', theme.success);
    }
  }

  Future<void> _submit(AppState app) async {
    setState(() => _error = null);
    final p = _password.text;
    final c = _confirm.text;
    if (p.isEmpty || c.isEmpty) {
      setState(() => _error = 'هر دو فیلد را پر کنید.');
      return;
    }
    if (p.length < 6) {
      setState(() => _error = 'رمز عبور باید حداقل ۶ نویسه باشد.');
      return;
    }
    if (p != c) {
      setState(() => _error = 'رمز عبور و تکرار آن یکسان نیستند.');
      return;
    }
    setState(() => _loading = true);
    final error = await app.updatePasswordFromRecovery(p);
    if (!mounted) return;
    if (error != null) {
      setState(() { _loading = false; _error = error; });
      return;
    }
    setState(() { _loading = false; _success = true; });
    await Future.delayed(const Duration(milliseconds: 1350));
    if (!mounted) return;
    await app.completeRecoveryLogin();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bg,
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: _success ? 1.4 : 0.75)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(anim), child: child),
                  ),
                  child: _success ? _successCard(theme) : _formCard(theme, app),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _formCard(AppColors theme, AppState app) {
    final meta = _strengthMeta(theme);
    return HzGlassCard(
      key: const ValueKey('form'),
      theme: theme,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        HzBadge(
          theme: theme,
          size: 54,
          filled: true,
          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 24),
        ).animate().scale(begin: const Offset(0.6, 0.6), duration: 480.ms, curve: Curves.easeOutBack).fadeIn(),
        const SizedBox(height: 16),
        Text('تنظیم رمز تازه', style: TextStyle(color: theme.textPrimary, fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'یک رمز عبور تازه و قوی برای حساب‌تان انتخاب کنید.',
          style: TextStyle(color: theme.textFaint, fontSize: 12, height: 1.9),
        ),
        const SizedBox(height: 20),
        HzTextField(
          controller: _password,
          icon: Icons.lock_outline_rounded,
          hint: 'رمز عبور تازه',
          theme: theme,
          obscureText: !_showPass,
          suffix: IconButton(
            icon: Icon(_showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: theme.textFaint),
            onPressed: () => setState(() => _showPass = !_showPass),
          ),
        ),
        const SizedBox(height: 10),
        _strengthMeter(theme, meta),
        const SizedBox(height: 14),
        HzTextField(
          controller: _confirm,
          icon: Icons.lock_outline_rounded,
          hint: 'تکرار رمز عبور تازه',
          theme: theme,
          obscureText: !_showConfirm,
          suffix: IconButton(
            icon: Icon(_showConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: theme.textFaint),
            onPressed: () => setState(() => _showConfirm = !_showConfirm),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: _confirm.text.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Icon(
                      _confirm.text == _password.text ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      size: 14,
                      color: _confirm.text == _password.text ? theme.success : theme.danger,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _confirm.text == _password.text ? 'رمزها یکسان‌اند' : 'رمزها هنوز یکسان نیستند',
                      style: TextStyle(fontSize: 12.5, color: _confirm.text == _password.text ? theme.success : theme.danger),
                    ),
                  ]),
                ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: theme.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(_error!, style: TextStyle(color: theme.danger, fontSize: 12.5)),
          ),
        ],
        const SizedBox(height: 20),
        HzPrimaryButton(
          theme: theme,
          label: _loading ? 'در حال ذخیره…' : 'ذخیره‌ی رمز تازه',
          icon: _loading ? null : Icons.check_rounded,
          loading: _loading,
          onPressed: () => _submit(app),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _loading ? null : () => app.goTo(AuthStage.login),
            child: Text('انصراف و بازگشت به ورود', style: TextStyle(color: theme.textFaint, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.06, end: 0);
  }

  Widget _strengthMeter(AppColors theme, (String, Color) meta) {
    return Row(children: [
      Expanded(
        child: Row(
          children: List.generate(5, (i) {
            final active = i < _strength;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                height: 5,
                margin: EdgeInsets.only(left: i == 4 ? 0 : 4),
                decoration: BoxDecoration(
                  color: active ? meta.$2 : theme.border,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: active ? [BoxShadow(color: meta.$2.withValues(alpha: 0.5), blurRadius: 6)] : null,
                ),
              ),
            );
          }),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 34,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            meta.$1,
            key: ValueKey(meta.$1),
            textAlign: TextAlign.left,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: meta.$2),
          ),
        ),
      ),
    ]);
  }

  Widget _successCard(AppColors theme) {
    return HzGlassCard(
      key: const ValueKey('success'),
      theme: theme,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [theme.success.withValues(alpha: 0.25), theme.success.withValues(alpha: 0.05)]),
            border: Border.all(color: theme.success, width: 1.6),
            boxShadow: [BoxShadow(color: theme.success.withValues(alpha: 0.35), blurRadius: 26, spreadRadius: 2)],
          ),
          child: Icon(Icons.check_rounded, color: theme.success, size: 38),
        ).animate().scale(begin: const Offset(0.4, 0.4), duration: 520.ms, curve: Curves.elasticOut).fadeIn(duration: 220.ms),
        const SizedBox(height: 20),
        Text('رمز عبور تازه ذخیره شد', style: TextStyle(color: theme.textPrimary, fontSize: 16.5, fontWeight: FontWeight.w800))
            .animate(delay: 200.ms).fadeIn(duration: 340.ms).slideY(begin: 0.15, end: 0),
        const SizedBox(height: 8),
        Text(
          'در حال ورود به هزاره‌نامه…',
          style: TextStyle(color: theme.textFaint, fontSize: 12),
        ).animate(delay: 320.ms).fadeIn(duration: 340.ms),
        const SizedBox(height: 22),
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: theme.blue),
        ).animate(delay: 420.ms).fadeIn(duration: 300.ms),
      ]),
    );
  }
}
