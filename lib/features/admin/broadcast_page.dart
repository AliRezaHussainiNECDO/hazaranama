import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/afghan_calendar.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/widgets.dart';
import '../../state/app_state.dart';

/// ارسال اعلان همگانی — یک پیام برای همه‌ی کاربران (یا فقط مدیران) که هم در
/// صندوق اعلان‌های اپ می‌نشیند و هم، اگر پوش تنظیم شده باشد، روی گوشی‌ها می‌آید.
class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key});

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _adminsOnly = false;
  bool _sending = false;
  Map<String, dynamic>? _status;
  String? _statusError;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _body.addListener(() => setState(() {}));
    _loadStatus();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final s = await context.read<AppState>().fetchPushStatus();
      if (mounted) setState(() => _status = s);
    } catch (e) {
      if (mounted) setState(() => _statusError = 'وضعیت پوش در دسترس نیست.');
    }
  }

  Future<void> _send() async {
    final app = context.read<AppState>();
    final theme = app.colors;
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty) {
      showHzToast(context, 'عنوان اعلان را بنویسید.');
      return;
    }
    final audience = _adminsOnly ? 'همه‌ی مدیران' : 'همه‌ی کاربران فعال (${toFaDigits(_status?['active_users'] ?? 0)} نفر)';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: theme.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('ارسال اعلان؟', style: TextStyle(color: theme.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
          content: Text('«$title» برای $audience فرستاده می‌شود. این کار برگشت‌پذیر نیست.',
              style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.7)),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('انصراف', style: TextStyle(color: theme.textSecondary))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: theme.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('ارسال', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _sending = true);
    try {
      final n = await app.sendBroadcast(title: title, body: body, adminsOnly: _adminsOnly);
      if (!mounted) return;
      showHzToast(context, 'اعلان برای ${toFaDigits(n)} نفر فرستاده شد');
      _title.clear();
      _body.clear();
      await _loadStatus();
    } catch (e) {
      if (mounted) showHzToast(context, 'ارسال نشد؛ دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _PushStatusCard(theme: theme, status: _status, error: _statusError).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 18),
        Text('اعلان تازه', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('همه‌ی کاربران'), icon: Icon(Icons.groups_rounded, size: 18)),
            ButtonSegment(value: true, label: Text('فقط مدیران'), icon: Icon(Icons.admin_panel_settings_rounded, size: 18)),
          ],
          selected: {_adminsOnly},
          onSelectionChanged: (v) => setState(() => _adminsOnly = v.first),
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : theme.textSecondary),
            backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? theme.blue : theme.bgCard.withValues(alpha: 0.5)),
            side: WidgetStatePropertyAll(BorderSide(color: theme.glassBorder)),
          ),
        ),
        const SizedBox(height: 12),
        _field(theme, _title, 'عنوان (حداکثر ۱۲۰ نویسه)', Icons.title_rounded, maxLength: 120),
        const SizedBox(height: 10),
        _field(theme, _body, 'متن اعلان (اختیاری، حداکثر ۵۰۰ نویسه)', Icons.notes_rounded, maxLength: 500, lines: 5),
        const SizedBox(height: 16),
        Text('پیش‌نمایش روی گوشی', style: TextStyle(color: theme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _Preview(theme: theme, title: _title.text.trim(), body: _body.text.trim()),
        const SizedBox(height: 20),
        HzPrimaryButton(
          theme: theme,
          label: _adminsOnly ? 'ارسال برای مدیران' : 'ارسال برای همه',
          icon: Icons.send_rounded,
          loading: _sending,
          onPressed: _sending || _title.text.trim().isEmpty ? null : _send,
        ),
      ],
    );
  }

  Widget _field(AppColors theme, TextEditingController c, String hint, IconData icon, {int maxLength = 200, int lines = 1}) {
    return TextField(
      controller: c,
      maxLength: maxLength,
      minLines: lines,
      maxLines: lines,
      style: TextStyle(color: theme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textFaint, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: theme.textFaint),
        filled: true,
        fillColor: theme.bgCard.withValues(alpha: 0.5),
        counterStyle: TextStyle(color: theme.textFaint, fontSize: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.glassBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.blue, width: 1.6)),
      ),
    );
  }
}

class _PushStatusCard extends StatelessWidget {
  final AppColors theme;
  final Map<String, dynamic>? status;
  final String? error;
  const _PushStatusCard({required this.theme, required this.status, required this.error});

  @override
  Widget build(BuildContext context) {
    final s = status;
    final configured = s?['configured'] == true;
    final color = s == null ? theme.textFaint : (configured ? theme.success : theme.yellow);

    Widget stat(String label, Object? v) => Expanded(
          child: Column(children: [
            Text(toFaDigits(v ?? 0), style: TextStyle(color: theme.textPrimary, fontSize: 19, fontWeight: FontWeight.w900)),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.bgCard.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
            child: Icon(configured ? Icons.notifications_active_rounded : Icons.notifications_paused_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('پوش نوتیفیکیشن', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
              Text(
                s == null
                    ? (error ?? 'در حال بررسی…')
                    : configured
                        ? 'فعال — اعلان‌ها روی گوشی‌ها هم می‌آیند'
                        : 'تنظیم نشده — اعلان‌ها فقط داخل اپ دیده می‌شوند',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ]),
          ),
        ]),
        if (s != null) ...[
          const SizedBox(height: 14),
          Row(children: [
            stat('کاربر فعال', s['active_users']),
            stat('گوشی ثبت‌شده', s['devices']),
            stat('اندروید', s['android']),
            stat('آیفون', s['ios']),
          ]),
        ],
        if (s != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(s['email_configured'] == true ? Icons.mark_email_read_rounded : Icons.unsubscribe_rounded,
                size: 18, color: s['email_configured'] == true ? theme.success : theme.textFaint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s['email_configured'] == true
                    ? 'ایمیل فعال است — بازیابی رمز، خوش‌آمد و هشدار تغییر رمز از ${s['email_from'] ?? ''} فرستاده می‌شود'
                    : 'ایمیل خاموش است — بازیابی رمز از راه مدیر (ساخت کد در صفحه‌ی کاربر)',
                style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.6),
              ),
            ),
          ]),
        ],
        if (s != null && !configured) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.yellow.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
            child: Text(
              'برای روشن‌کردن پوش: در Firebase Console ← Project settings ← Service accounts یک کلید خصوصی بسازید و کل فایل JSON را در داشبورد Cloudflare ← Workers ← hazaranama-api ← Settings ← Variables and Secrets به‌عنوان Secret با نام FCM_SERVICE_ACCOUNT ذخیره کنید.',
              style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.8),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Preview extends StatelessWidget {
  final AppColors theme;
  final String title;
  final String body;
  const _Preview({required this.theme, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.bgElevated,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(0, 8))],
        border: Border.all(color: theme.glassBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AppLogo(size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('هزاره‌نامه', style: TextStyle(color: theme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text('· اکنون', style: TextStyle(color: theme.textFaint, fontSize: 11)),
            ]),
            const SizedBox(height: 3),
            Text(title.isEmpty ? 'عنوان اعلان' : title,
                style: TextStyle(color: title.isEmpty ? theme.textFaint : theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.5)),
            ],
          ]),
        ),
      ]),
    );
  }
}
