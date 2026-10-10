import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_logo.dart';
import '../../core/widgets.dart';
import '../../state/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPass = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit(AppState app) async {
    setState(() => _error = null);
    if (_email.text.trim().isEmpty || _password.text.trim().isEmpty) {
      setState(() => _error = 'لطفاً ایمیل و رمز عبور را کامل وارد کنید.');
      return;
    }
    if (!_email.text.contains('@')) {
      setState(() => _error = 'ایمیل معتبر نیست.');
      return;
    }
    setState(() => _loading = true);
    final error = await app.signIn(email: _email.text.trim(), password: _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) setState(() => _error = error);
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
          Positioned.fill(child: AnimatedBackdrop(theme: theme)),
          SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(children: [
                HzIconButton(theme: theme, icon: Icons.arrow_forward, onPressed: () => app.goTo(AuthStage.welcome)),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(
                    child: const AppLogo(size: 58, glow: true).animate().scale(begin: const Offset(0.7, 0.7), duration: 450.ms, curve: Curves.easeOutBack).fadeIn(),
                  ),
                  const SizedBox(height: 18),
                  HzGlassCard(
                    theme: theme,
                    radius: 26,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('خوش آمدید', style: TextStyle(color: theme.textPrimary, fontSize: 21, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text('برای ادامه، وارد حساب کاربری خود شوید', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                      const SizedBox(height: 22),
                      HzTextField(controller: _email, icon: Icons.mail_outline, hint: 'ایمیل', theme: theme, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 12),
                      HzTextField(
                        controller: _password, icon: Icons.lock_outline, hint: 'رمز عبور', theme: theme, obscureText: !_showPass,
                        suffix: IconButton(
                          icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, size: 18, color: theme.textFaint),
                          onPressed: () => setState(() => _showPass = !_showPass),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => app.goTo(AuthStage.forgot),
                          child: Text('رمز عبور را فراموش کرده‌اید؟', style: TextStyle(color: theme.blue, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: theme.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                          child: Text(_error!, style: TextStyle(color: theme.danger, fontSize: 12.5)),
                        ),
                      ],
                      const SizedBox(height: 18),
                      HzPrimaryButton(theme: theme, label: _loading ? 'در حال ورود…' : 'ورود', loading: _loading, onPressed: () => _submit(app)),
                      const SizedBox(height: 20),
                      Center(
                        child: Wrap(alignment: WrapAlignment.center, children: [
                          Text('حساب ندارید؟ ', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                          GestureDetector(
                            onTap: () => app.goTo(AuthStage.register),
                            child: Text('ثبت‌نام کنید', style: TextStyle(color: theme.blue, fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ]),
                      ),
                    ]),
                  ).animate(delay: 120.ms).fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
                ]),
              ),
            ),
          ]),
          ),
        ]),
      ),
    );
  }
}
