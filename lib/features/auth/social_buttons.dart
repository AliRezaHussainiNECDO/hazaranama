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
    final fb = p['facebook'] == true;
    final apple = app.appleAvailable;
    final phone = app.phoneAvailable;
    if (!fb && !apple && !phone) return const SizedBox.shrink();
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
      if (fb)
        _SocialButton(
          label: 'ادامه با فیسبوک',
          color: const Color(0xFF1877F2),
          mark: const _Mark(text: 'f', bg: Colors.white, fg: Color(0xFF1877F2), fontSize: 19),
          busy: _busy == 'facebook',
          onTap: _busy == null ? () => _go(app, 'facebook') : null,
        ),
      if (phone)
        _SocialButton(
          label: 'ادامه با شماره‌ی تلفن',
          color: const Color(0xFF0F9D7A),
          mark: const Icon(Icons.phone_iphone_rounded, color: Colors.white, size: 22),
          busy: false,
          onTap: _busy == null ? () => showPhoneAuthSheet(context, t) : null,
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

/// برگه‌ی ورود با شماره‌ی تلفن: شماره ← کد پیامکی ۶ رقمی
Future<void> showPhoneAuthSheet(BuildContext context, AppColors theme) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(value: context.read<AppState>(), child: _PhoneAuthSheet(theme: theme)),
  );
}

class _PhoneAuthSheet extends StatefulWidget {
  final AppColors theme;
  const _PhoneAuthSheet({required this.theme});
  @override
  State<_PhoneAuthSheet> createState() => _PhoneAuthSheetState();
}

class _PhoneAuthSheetState extends State<_PhoneAuthSheet> {
  static const _codes = [('+93', 'افغانستان'), ('+98', 'ایران'), ('+92', 'پاکستان'), ('+49', 'آلمان'), ('+44', 'بریتانیا'), ('+1', 'آمریکا/کانادا'), ('+61', 'استرالیا'), ('+90', 'ترکیه'), ('+46', 'سوئد'), ('+31', 'هلند'), ('+47', 'ناروی'), ('+45', 'دنمارک'), ('+33', 'فرانسه'), ('+43', 'اتریش'), ('+971', 'امارات')];
  String _cc = '+93';
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  String get _e164 {
    // ارقام فارسی/عربی به لاتین
    const fa = '۰۱۲۳۴۵۶۷۸۹', ar = '٠١٢٣٤٥٦٧٨٩';
    var raw = _phone.text;
    for (var i = 0; i < 10; i++) {
      raw = raw.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
    }
    var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('00')) return '+${d.substring(2)}';
    if (d.startsWith('0')) d = d.substring(1);
    return '$_cc$d';
  }

  Future<void> _send() async {
    final app = context.read<AppState>();
    if (_phone.text.trim().length < 6) {
      setState(() => _error = 'شماره را کامل بنویسید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final e = await app.sendPhoneCode(_e164, name: _name.text.trim(), onAutoSignedIn: () {
      if (mounted) Navigator.of(context).pop();
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = e;
      if (e == null) _codeSent = true;
    });
  }

  Future<void> _verify() async {
    final app = context.read<AppState>();
    if (_code.text.trim().length < 6) {
      setState(() => _error = 'کد ۶ رقمی را بنویسید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final e = await app.verifyPhoneCode(_code.text, name: _name.text.trim());
    if (!mounted) return;
    if (e == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    InputDecoration deco(String hint, IconData icon) => InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: t.textFaint, fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: t.textFaint),
          filled: true,
          fillColor: t.bgCard.withValues(alpha: 0.5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.glassBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.glassBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.blue, width: 1.6)),
        );
    final style = TextStyle(fontFamily: 'Vazirmatn', color: t.textPrimary, fontSize: 14);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(color: t.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), border: Border.all(color: t.glassBorder)),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: t.glassBorder, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 18),
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F9D7A), Color(0xFF34D399)]), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.sms_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_codeSent ? 'کد تأیید را وارد کنید' : 'ورود با شماره‌ی تلفن', style: TextStyle(color: t.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(_codeSent ? 'کد ۶ رقمی به ‎$_e164‎ فرستاده شد' : 'یک کد ۶ رقمی با پیامک برایتان می‌فرستیم', style: TextStyle(color: t.textFaint, fontSize: 12)),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              if (!_codeSent) ...[
                TextField(controller: _name, style: style, decoration: deco('نام شما (برای حساب تازه)', Icons.person_outline)),
                const SizedBox(height: 10),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(color: t.bgCard.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: t.glassBorder)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _cc,
                          dropdownColor: t.bgCard,
                          style: style,
                          items: [for (final c in _codes) DropdownMenuItem(value: c.$1, child: Text('${c.$1}  ${c.$2}', style: style.copyWith(fontSize: 13)))],
                          selectedItemBuilder: (_) => [for (final c in _codes) Center(child: Text(c.$1, style: style))],
                          onChanged: (v) => setState(() => _cc = v ?? _cc),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumberNational],
                        style: style,
                        decoration: deco('7X XXX XXXX', Icons.phone_rounded),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ]),
                ),
              ] else
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    style: style.copyWith(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w800),
                    decoration: deco('••••••', Icons.lock_outline).copyWith(counterText: ''),
                    onChanged: (v) {
                      if (v.trim().length == 6) _verify();
                    },
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: t.danger, fontSize: 12.5)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F9D7A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _busy ? null : (_codeSent ? _verify : _send),
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : Text(_codeSent ? 'تأیید و ورود' : 'فرستادن کد', style: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w800, fontSize: 14.5)),
                ),
              ),
              if (_codeSent)
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _send,
                    child: Text('کد را دوباره بفرست', style: TextStyle(color: t.blue, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
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
