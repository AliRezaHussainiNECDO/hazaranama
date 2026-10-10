import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/widgets.dart';
import '../../state/app_state.dart';

/// بازیابی رمز عبور با کد یک‌بارمصرف — نه با کلیک روی پیوند ایمیل. دلیل:
/// بسیاری از سرویس‌های ایمیل (از جمله Gmail) پیش از این‌که کاربر واقعاً روی
/// پیوند بزند، به‌طور خودکار برای اسکن امنیتی به آن سر می‌زنند و توکنِ
/// یک‌بارمصرفِ داخل پیوند را مصرف می‌کنند — یعنی وقتی کاربر واقعی کلیک
/// می‌کند، پیوند از قبل «منقضی» شده. کد چون فقط متنِ ساده در ایمیل است (نه
/// یک URL قابل‌کلیک)، هیچ اسکنری آن را مصرف نمی‌کند. طول کد را Supabase
/// تعیین می‌کند (پیش‌فرض این پروژه ۸ رقم است)؛ اگر در تنظیمات
/// Auth › Sign In / Providers › Email مقدار «OTP Length» تغییر کرد،
/// کافی است [_codeLength] همین‌جا به‌روز شود.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const int _codeLength = 8;
  static const String _codeLengthFa = '۸'; // معادل فارسیِ _codeLength — فقط برای نمایش در متن

  String _step = 'email'; // email | code
  String _via = 'email'; // email: کد به ایمیل رفت | admin: مدیر کد می‌سازد
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;

  final List<TextEditingController> _digits = List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _digitNodes = List.generate(_codeLength, (_) => FocusNode());
  bool _verifying = false;
  bool _resending = false;
  int _resendCooldown = 0;

  @override
  void dispose() {
    _email.dispose();
    for (final c in _digits) {
      c.dispose();
    }
    for (final n in _digitNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _digits.map((c) => c.text).join();

  Future<void> _sendResetEmail(AppState app, {bool isResend = false}) async {
    setState(() => _error = null);
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      setState(() => _error = 'یک ایمیل معتبر وارد کنید.');
      return;
    }
    setState(() => isResend ? _resending = true : _loading = true);
    try {
      final via = await app.resetPasswordForEmail(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _via = via;
        _loading = false;
        _resending = false;
        _step = 'code';
      });
      _startResendCooldown();
      if (!isResend) {
        for (final c in _digits) {
          c.clear();
        }
        Future.delayed(const Duration(milliseconds: 260), () {
          if (mounted) _digitNodes.first.requestFocus();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _resending = false;
        _error = 'ثبت درخواست ناموفق بود؛ اتصال اینترنت را بررسی کنید.';
      });
    }
  }

  void _startResendCooldown() {
    _resendCooldown = 45;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown--);
      return _resendCooldown > 0;
    });
  }

  Future<void> _verifyCode(AppState app) async {
    setState(() => _error = null);
    if (_code.length != _codeLength) {
      setState(() => _error = 'هر $_codeLengthFa رقم کد را وارد کنید.');
      return;
    }
    setState(() => _verifying = true);
    final error = await app.verifyRecoveryOtp(email: _email.text.trim(), token: _code);
    if (!mounted) return;
    if (error != null) {
      setState(() { _verifying = false; _error = error; });
      for (final c in _digits) {
        c.clear();
      }
      _digitNodes.first.requestFocus();
      return;
    }
    // موفقیت: AppState خودش stage را به resetPassword عوض می‌کند و
    // _AuthGate این صفحه را با ResetPasswordScreen جابه‌جا می‌کند.
  }

  void _onDigitChanged(int i, String value, AppState app) {
    if (value.length > 1) {
      // چسباندن کل کد در یک خانه (کپی/پیست از ایمیل)
      final pasted = value.replaceAll(RegExp(r'\D'), '');
      for (var j = 0; j < _codeLength && j < pasted.length; j++) {
        _digits[j].text = pasted[j];
      }
      setState(() {});
      final next = pasted.length.clamp(0, _codeLength - 1);
      _digitNodes[next].requestFocus();
      if (_code.length == _codeLength) _verifyCode(app);
      return;
    }
    setState(() {});
    if (value.isNotEmpty && i < _codeLength - 1) {
      _digitNodes[i + 1].requestFocus();
    }
    if (_code.length == _codeLength) {
      FocusScope.of(context).unfocus();
      _verifyCode(app);
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
                HzIconButton(
                  theme: theme,
                  icon: Icons.arrow_forward,
                  onPressed: () => _step == 'code' ? setState(() => _step = 'email') : app.goTo(AuthStage.login),
                ),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(position: Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(anim), child: child),
                  ),
                  child: _step == 'email'
                      ? HzGlassCard(
                          key: const ValueKey('email'),
                          theme: theme,
                          radius: 26,
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            HzBadge(theme: theme, size: 54, filled: true, child: const Icon(Icons.lock_outline, color: Colors.white, size: 22)),
                            const SizedBox(height: 16),
                            Text('بازیابی رمز عبور', style: TextStyle(color: theme.textPrimary, fontSize: 21, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 16),
                            ..._emailStep(theme, app),
                          ]),
                        )
                      : _codeCard(theme, app),
                ),
              ),
            ),
          ]),
          ),
        ]),
      ),
    );
  }

  List<Widget> _emailStep(theme, AppState app) {
    return [
      Text('ایمیل حساب‌تان را وارد کنید. یک کد $_codeLengthFa رقمی برای ساختن رمز تازه دریافت می‌کنید.', style: TextStyle(color: theme.textFaint, fontSize: 12, height: 1.9)),
      const SizedBox(height: 16),
      HzTextField(controller: _email, icon: Icons.mail_outline, hint: 'ایمیل', theme: theme, keyboardType: TextInputType.emailAddress),
      if (_error != null) ...[const SizedBox(height: 10), _errorBox(theme)],
      const SizedBox(height: 18),
      HzPrimaryButton(theme: theme, label: _loading ? 'در حال ارسال…' : 'درخواست کد بازیابی', loading: _loading, onPressed: () => _sendResetEmail(app)),
    ];
  }

  Widget _codeCard(AppColors theme, AppState app) {
    return HzGlassCard(
      key: const ValueKey('code'),
      theme: theme,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(shape: BoxShape.circle, color: theme.success.withValues(alpha: 0.12), border: Border.all(color: theme.success, width: 1.5)),
          child: Icon(Icons.mark_email_read_outlined, color: theme.success, size: 26),
        ).animate().scale(begin: const Offset(0.6, 0.6), duration: 460.ms, curve: Curves.easeOutBack).fadeIn(),
        const SizedBox(height: 16),
        Text('کد را وارد کنید', style: TextStyle(color: theme.textPrimary, fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          _via == 'email'
              ? 'اگر حسابی با ${_email.text} وجود داشته باشد، یک کد $_codeLengthFa رقمی به همین ایمیل فرستاده شد (تا ۳۰ دقیقه معتبر). پوشه‌ی هرزنامه (Spam) را هم نگاه کنید.'
              : 'درخواست شما برای مدیر هزاره‌نامه فرستاده شد. مدیر یک کد $_codeLengthFa رقمی (با اعتبار ۲۴ ساعت) برای حساب ${_email.text} می‌سازد و برایتان می‌فرستد؛ برای سرعت بیشتر از همان ایمیل به alireza.necdo@gmail.com هم بنویسید.',
          style: TextStyle(color: theme.textFaint, fontSize: 12, height: 1.9),
        ),
        const SizedBox(height: 22),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_codeLength, (i) => _digitBox(theme, app, i)),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 14), _errorBox(theme)],
        const SizedBox(height: 22),
        HzPrimaryButton(
          theme: theme,
          label: _verifying ? 'در حال بررسی…' : 'تأیید کد',
          icon: _verifying ? null : Icons.check_rounded,
          loading: _verifying,
          onPressed: () => _verifyCode(app),
        ),
        const SizedBox(height: 14),
        Center(
          child: _resendCooldown > 0
              ? Text('ارسال دوباره‌ی کد تا $_resendCooldown ثانیه‌ی دیگر', style: TextStyle(color: theme.textFaint, fontSize: 12.5))
              : TextButton(
                  onPressed: _resending ? null : () => _sendResetEmail(app, isResend: true),
                  child: Text(
                    _resending ? 'در حال ارسال…' : (_via == 'email' ? 'ارسال دوباره‌ی کد' : 'یادآوری دوباره به مدیر'),
                    style: TextStyle(color: theme.blue, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
        ),
      ]),
    ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.06, end: 0);
  }

  Widget _digitBox(AppColors theme, AppState app, int i) {
    final filled = _digits[i].text.isNotEmpty;
    return SizedBox(
      width: 33,
      height: 46,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: theme.bgCardAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: filled ? theme.blue : theme.border, width: filled ? 1.6 : 1),
          boxShadow: filled ? [BoxShadow(color: theme.blue.withValues(alpha: 0.25), blurRadius: 8)] : null,
        ),
        child: TextField(
          controller: _digits[i],
          focusNode: _digitNodes[i],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: _codeLength,
          style: TextStyle(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(counterText: '', border: InputBorder.none, contentPadding: EdgeInsets.zero),
          onChanged: (v) => _onDigitChanged(i, v, app),
          onTap: () => _digits[i].selection = TextSelection(baseOffset: 0, extentOffset: _digits[i].text.length),
        ),
      ),
    );
  }

  Widget _errorBox(theme) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: theme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Text(_error!, style: TextStyle(color: theme.danger, fontSize: 12.5)),
      );
}
