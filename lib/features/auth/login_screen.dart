import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_logo.dart';
import '../../core/widgets.dart';
import '../../state/app_state.dart';
import 'social_buttons.dart';

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

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _email.text = app.rememberedEmail;
    _error = app.oauthError;
  }

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
    if (error != null) {
      setState(() => _error = error);
    } else {
      // از سیستم (Google/iCloud) می‌خواهد رمز را امن ذخیره کند تا دفعه‌ی بعد خودکار پر شود
      TextInput.finishAutofillContext(shouldSave: app.rememberMe);
    }
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
                      AutofillGroup(
                        child: Column(children: [
                          HzTextField(controller: _email, icon: Icons.mail_outline, hint: 'ایمیل', theme: theme, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email, AutofillHints.username]),
                          const SizedBox(height: 12),
                          HzTextField(
                            controller: _password, icon: Icons.lock_outline, hint: 'رمز عبور', theme: theme, obscureText: !_showPass,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _submit(app),
                            suffix: IconButton(
                              icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, size: 18, color: theme.textFaint),
                              onPressed: () => setState(() => _showPass = !_showPass),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        // «مرا به خاطر بسپار»: ورود روی این دستگاه می‌ماند، ایمیل یادش می‌ماند و رمز در مدیر رمز سیستم ذخیره می‌شود
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => app.setRememberMe(!app.rememberMe),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: app.rememberMe ? LinearGradient(colors: [theme.blue, theme.aiViolet]) : null,
                                  border: Border.all(color: app.rememberMe ? Colors.transparent : theme.textFaint, width: 1.4),
                                ),
                                child: app.rememberMe ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
                              ),
                              const SizedBox(width: 8),
                              Text('مرا به خاطر بسپار', style: TextStyle(color: theme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => app.goTo(AuthStage.forgot),
                          child: Text('فراموشی رمز؟', style: TextStyle(color: theme.blue, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ),
                      ]),
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
                      SocialAuthButtons(theme: theme, onResult: (e) => setState(() => _error = e)),
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
