import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/widgets.dart';
import '../../state/app_state.dart';

/// برگه‌ی «تأیید ایمیل» — کد ۶ رقمی که به ایمیل کاربر فرستاده شده.
/// تا تأیید نشود، کاربر فقط می‌تواند بخواند (پست، کامنت و لایک ممنوع است).
Future<void> showVerifyEmailSheet(BuildContext context) {
  final app = context.read<AppState>();
  app.clearVerifyPrompt();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: app.colors.bgElevated,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => const _VerifyEmailSheet(),
  );
}

class _VerifyEmailSheet extends StatefulWidget {
  const _VerifyEmailSheet();
  @override
  State<_VerifyEmailSheet> createState() => _VerifyEmailSheetState();
}

class _VerifyEmailSheetState extends State<_VerifyEmailSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    final app = context.read<AppState>();
    setState(() => _error = null);
    final e = await app.sendEmailVerification();
    if (!mounted) return;
    if (e != null) {
      setState(() => _error = e);
    } else {
      _startCooldown();
      showHzToast(context, 'کد تازه به ایمیل شما فرستاده شد.');
    }
  }

  Future<void> _verify() async {
    final code = _code.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      setState(() => _error = 'کد ۶ رقمی را کامل وارد کنید.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final app = context.read<AppState>();
    final e = await app.verifyEmailCode(code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (e != null) {
      setState(() => _error = e);
      return;
    }
    Navigator.of(context).pop();
    showHzToast(context, 'ایمیل شما تأیید شد؛ خوش آمدید!');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final AppColors t = app.colors;
    final email = app.currentUser?.email ?? '';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 18, 22, 18 + MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(shape: BoxShape.circle, color: t.blue.withValues(alpha: 0.15)),
                child: Icon(Icons.mark_email_read_rounded, color: t.blue, size: 30),
              ),
            ),
            const SizedBox(height: 12),
            Text('ایمیل‌تان را تأیید کنید', textAlign: TextAlign.center,
                style: TextStyle(color: t.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('یک کد ۶ رقمی به ایمیل زیر فرستادیم. برای نوشتن پست، کامنت و مشارکت در هزاره‌نامه، آن را وارد کنید. (پوشه‌ی Spam را هم نگاه کنید.)',
                textAlign: TextAlign.center, style: TextStyle(color: t.textSecondary, fontSize: 12.5, height: 1.7)),
            const SizedBox(height: 4),
            Text(email, textAlign: TextAlign.center, textDirection: TextDirection.ltr,
                style: TextStyle(color: t.blue, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: t.textPrimary, fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••••',
                hintStyle: TextStyle(color: t.textFaint, letterSpacing: 10),
                filled: true,
                fillColor: t.bgCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.blue, width: 1.6)),
              ),
              onSubmitted: (_) => _verify(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: t.danger, fontSize: 12.5)),
            ],
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: t.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _busy ? null : _verify,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('تأیید', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _cooldown > 0 ? null : _resend,
              child: Text(_cooldown > 0 ? 'ارسال دوباره تا $_cooldown ثانیه‌ی دیگر' : 'کد نرسید؟ ارسال دوباره',
                  style: TextStyle(color: _cooldown > 0 ? t.textFaint : t.blue, fontSize: 12.5)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('بعداً', style: TextStyle(color: t.textFaint, fontSize: 12.5)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// نوار کوچک «ایمیل تأیید نشده» برای صفحه‌ی خانه
class VerifyEmailBanner extends StatelessWidget {
  const VerifyEmailBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.emailUnverified) return const SizedBox.shrink();
    final t = app.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
      child: Material(
        color: t.yellow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showVerifyEmailSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(Icons.mark_email_unread_rounded, color: t.yellow, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text('ایمیل شما هنوز تأیید نشده؛ برای نوشتن و مشارکت، کد را وارد کنید.',
                    style: TextStyle(color: t.textPrimary, fontSize: 12.5, height: 1.6)),
              ),
              Icon(Icons.chevron_left_rounded, color: t.textFaint),
            ]),
          ),
        ),
      ),
    );
  }
}
