import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/widgets.dart';
import '../../state/app_state.dart';
import 'social_buttons.dart';
import 'terms_sheet.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 1;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _country = TextEditingController();
  final _originProvince = TextEditingController();
  final _district = TextEditingController();
  final _tribe = TextEditingController();
  final _bio = TextEditingController();
  String? _nativeLanguage;
  bool _showPass = false;
  bool _loading = false;
  bool _acceptedTerms = false;
  String? _error;

  void _goStep2() {
    setState(() => _error = null);
    if ([_name, _email, _password, _confirm].any((c) => c.text.trim().isEmpty)) {
      setState(() => _error = 'لطفاً همه‌ی فیلدها را پر کنید.');
      return;
    }
    if (!_email.text.contains('@')) {
      setState(() => _error = 'ایمیل معتبر نیست.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'رمز عبور باید حداقل ۶ نویسه باشد.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'رمز عبور و تکرار آن یکسان نیستند.');
      return;
    }
    setState(() => _step = 2);
  }

  Future<void> _submit(AppState app) async {
    if (!_acceptedTerms) {
      setState(() => _error = 'برای ادامه باید شرایط و قوانین را بپذیرید.');
      return;
    }
    setState(() => _loading = true);
    final error = await app.signUp(
      email: _email.text.trim(),
      password: _password.text,
      name: _name.text.trim(),
      country: _country.text.trim().isEmpty ? 'نامشخص' : _country.text.trim(),
      originProvince: _originProvince.text.trim().isEmpty ? 'نامشخص' : _originProvince.text.trim(),
      district: _district.text.trim().isEmpty ? 'نامشخص' : _district.text.trim(),
      tribe: _tribe.text.trim().isEmpty ? '—' : _tribe.text.trim(),
      nativeLanguage: _nativeLanguage ?? 'نامشخص',
      bio: _bio.text.trim(),
    );
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
                HzIconButton(
                  theme: theme,
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => _step == 1 ? app.goTo(AuthStage.welcome) : setState(() => _step = 1),
                ),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
                child: Column(children: [
                  StepDots(theme: theme, step: _step, total: 2),
                  const SizedBox(height: 18),
                  HzGlassCard(
                    theme: theme,
                    radius: 26,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    child: Column(
                      key: ValueKey(_step),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _step == 1 ? _buildStep1(theme) : _buildStep2(theme, app),
                    ),
                  ).animate(key: ValueKey('card-$_step')).fadeIn(duration: 320.ms).slideY(begin: 0.06, end: 0),
                ]),
              ),
            ),
          ]),
          ),
        ]),
      ),
    );
  }

  List<Widget> _buildStep1(theme) {
    return [
      HzBadge(theme: theme, size: 54, filled: true, child: const Icon(Icons.person_add_alt_rounded, color: Colors.white, size: 22)),
      const SizedBox(height: 16),
      Text('ساخت حساب تازه', style: TextStyle(color: theme.textPrimary, fontSize: 21, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text('گام ۱ از ۲ — اطلاعات حساب کاربری', style: TextStyle(color: theme.textFaint, fontSize: 12)),
      const SizedBox(height: 22),
      HzTextField(controller: _name, icon: Icons.person_outline_rounded, hint: 'نام و تخلص', theme: theme),
      const SizedBox(height: 12),
      HzTextField(controller: _email, icon: Icons.mail_outline_rounded, hint: 'ایمیل', theme: theme, keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 12),
      HzTextField(
        controller: _password, icon: Icons.lock_outline_rounded, hint: 'رمز عبور', theme: theme, obscureText: !_showPass,
        suffix: IconButton(icon: Icon(_showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: theme.textFaint), onPressed: () => setState(() => _showPass = !_showPass)),
      ),
      const SizedBox(height: 12),
      HzTextField(controller: _confirm, icon: Icons.lock_outline_rounded, hint: 'تکرار رمز عبور', theme: theme, obscureText: !_showPass),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: theme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Text(_error!, style: TextStyle(color: theme.danger, fontSize: 12.5)),
        ),
      ],
      const SizedBox(height: 18),
      HzPrimaryButton(theme: theme, label: 'مرحله‌ی بعد', icon: Icons.arrow_back_rounded, onPressed: _goStep2),
      SocialAuthButtons(theme: theme, onResult: (e) => setState(() => _error = e)),
      if (context.watch<AppState>().appleAvailable) ...[
        const SizedBox(height: 8),
        Text('با ادامه از راه اپل، شرایط و قوانین هزاره‌نامه را می‌پذیرید.', textAlign: TextAlign.center, style: TextStyle(color: theme.textFaint, fontSize: 10.5)),
      ],
      const SizedBox(height: 20),
      Center(
        child: Wrap(alignment: WrapAlignment.center, children: [
          Text('قبلاً حساب دارید؟ ', style: TextStyle(color: theme.textFaint, fontSize: 12)),
          GestureDetector(
            onTap: () => context.read<AppState>().goTo(AuthStage.login),
            child: Text('وارد شوید', style: TextStyle(color: theme.blue, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ]),
      ),
    ];
  }

  List<Widget> _buildStep2(theme, AppState app) {
    return [
      HzBadge(theme: theme, size: 54, filled: true, child: const Icon(Icons.public_rounded, color: Colors.white, size: 22)),
      const SizedBox(height: 16),
      Text('ریشه‌های شما', style: TextStyle(color: theme.textPrimary, fontSize: 21, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text(
        'گام ۲ از ۲ — یکی از هدف‌های هزاره‌نامه، پیدا کردن هزاره‌های سراسر جهان و نگاشت ریشه‌های خانوادگی آن‌هاست. این بخش اختیاری اما بسیار ارزشمند است.',
        style: TextStyle(color: theme.textFaint, fontSize: 12, height: 1.9),
      ),
      const SizedBox(height: 18),
      HzTextField(controller: _country, icon: Icons.public_rounded, hint: 'کشور محل سکونت فعلی', theme: theme, suggestions: AppConstants.countrySuggestions),
      const SizedBox(height: 12),
      HzTextField(controller: _originProvince, icon: Icons.map_rounded, hint: 'ولایت/منطقه‌ی اصلی نیاکان', theme: theme, suggestions: AppConstants.originSuggestions),
      const SizedBox(height: 12),
      HzTextField(controller: _district, icon: Icons.account_balance_rounded, hint: 'ولسوالی (مثلاً بهسود، یکاولنگ، جاغوری…)', theme: theme),
      const SizedBox(height: 12),
      HzTextField(controller: _tribe, icon: Icons.groups_rounded, hint: 'طایفه (اختیاری، مثلاً بهسودی، جاغوری…)', theme: theme),
      const SizedBox(height: 12),
      HzSelectField(
        value: _nativeLanguage, icon: Icons.translate_rounded, hint: 'زبان مادری', theme: theme,
        options: AppConstants.languageOptions, onChanged: (v) => setState(() => _nativeLanguage = v),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _bio,
        maxLines: 3,
        style: TextStyle(color: theme.textPrimary, fontSize: 12.5),
        decoration: InputDecoration(
          hintText: 'چیزی درباره‌ی ریشه‌ی خانواده‌ات بگو (اختیاری)…',
          hintStyle: TextStyle(color: theme.textFaint, fontSize: 12.5),
          filled: true,
          fillColor: theme.bgCard.withValues(alpha: 0.4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.glassBorder)),
        ),
      ),
      const SizedBox(height: 18),
      TermsCheckRow(
        theme: theme,
        accepted: _acceptedTerms,
        onToggle: () => setState(() => _acceptedTerms = !_acceptedTerms),
        onReadTerms: () async {
          final result = await showTermsSheet(context, theme);
          if (!mounted) return;
          if (result == true) setState(() => _acceptedTerms = true);
        },
      ),
      const SizedBox(height: 14),
      if (_error != null) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: theme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Text(_error!, style: TextStyle(color: theme.danger, fontSize: 12.5)),
        ),
        const SizedBox(height: 12),
      ],
      HzPrimaryButton(theme: theme, label: _loading ? 'در حال ایجاد حساب…' : 'ایجاد حساب', loading: _loading, onPressed: () => _submit(app)),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: theme.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.success.withValues(alpha: 0.3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.mark_email_read_rounded, size: 16, color: theme.success),
          const SizedBox(width: 9),
          Expanded(child: Text('پس از ثبت‌نام، یک کد ۶ رقمی به ایمیل شما فرستاده می‌شود. با وارد کردن آن، ایمیل‌تان تأیید و حساب‌تان کامل فعال می‌شود (پوشه‌ی Spam را هم نگاه کنید).', style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.8))),
        ]),
      ),
    ];
  }
}

class TermsCheckRow extends StatelessWidget {
  final AppColors theme;
  final bool accepted;
  final VoidCallback onToggle;
  final VoidCallback onReadTerms;
  const TermsCheckRow({super.key, required this.theme, required this.accepted, required this.onToggle, required this.onReadTerms});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accepted ? theme.blue.withValues(alpha: 0.12) : theme.bgCard.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accepted ? theme.blue : theme.glassBorder),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedScale(
            scale: accepted ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: accepted ? theme.blue : Colors.transparent,
                border: Border.all(color: accepted ? theme.blue : theme.textFaint, width: 1.6),
                borderRadius: BorderRadius.circular(7),
              ),
              child: accepted ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontFamily: 'Vazirmatn', color: theme.textSecondary, fontSize: 12.5, height: 1.9),
                children: [
                  const TextSpan(text: 'با ساخت حساب، '),
                  TextSpan(
                    text: 'شرایط و قوانین هزاره‌نامه',
                    style: TextStyle(color: theme.blue, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = onReadTerms,
                  ),
                  const TextSpan(text: ' را می‌پذیرم.'),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
