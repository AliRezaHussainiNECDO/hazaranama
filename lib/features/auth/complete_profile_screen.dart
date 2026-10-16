import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_constants.dart';
import '../../core/widgets.dart';
import '../../state/app_state.dart';
import 'register_screen.dart' show TermsCheckRow;
import 'terms_sheet.dart';

/// پس از ساخت حساب با اپل، فیسبوک یا شماره‌ی تلفن: تکمیل نام، ایمیل (برای حساب‌های بی‌ایمیل)،
/// ریشه‌ها و پذیرش شرایط — همان اطلاعاتی که ثبت‌نام با ایمیل می‌گیرد.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});
  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _country = TextEditingController();
  final _originProvince = TextEditingController();
  final _district = TextEditingController();
  final _tribe = TextEditingController();
  final _bio = TextEditingController();
  String? _nativeLanguage;
  bool _acceptedTerms = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = context.read<AppState>().currentUser;
    final n = u?.name ?? '';
    if (n != 'کاربر هزاره‌نامه') _name.text = n;
  }

  Future<void> _save(AppState app) async {
    setState(() => _error = null);
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'نام خود را بنویسید.');
      return;
    }
    final email = _email.text.trim();
    if (email.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'ایمیل معتبر نیست.');
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _error = 'برای ادامه باید شرایط و قوانین را بپذیرید.');
      return;
    }
    setState(() => _loading = true);
    final e = await app.completeProfile(
      name: _name.text,
      email: email,
      country: _country.text,
      originProvince: _originProvince.text,
      district: _district.text,
      tribe: _tribe.text,
      nativeLanguage: _nativeLanguage ?? '',
      bio: _bio.text,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = e;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final u = app.currentUser;
    final needsEmail = u?.hasPlaceholderEmail ?? false;

    Widget section(String title, IconData icon) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Row(children: [
            Icon(icon, size: 16, color: theme.blue),
            const SizedBox(width: 7),
            Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800)),
          ]),
        );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bg,
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // سربرگ خوش‌آمد با عکس پروفایلی که از اپل/فیسبوک آمده
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [theme.blueDeep, theme.blue, theme.aiViolet]),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [BoxShadow(color: theme.blue.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                      child: HzBadge(
                        theme: theme,
                        size: 58,
                        filled: true,
                        avatarPath: app.avatarPath,
                        child: Text((u?.name ?? 'ه').characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('خوش آمدید! 🌿', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('حسابتان ساخته شد. چند مورد کوتاه را کامل کنید تا پروفایلتان آماده شود.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.7)),
                      ]),
                    ),
                  ]),
                ).animate().fadeIn(duration: 380.ms).slideY(begin: -0.05, end: 0),
                const SizedBox(height: 18),
                HzGlassCard(
                  theme: theme,
                  radius: 24,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    section('حساب شما', Icons.person_rounded),
                    HzTextField(controller: _name, icon: Icons.person_outline_rounded, hint: 'نام و تخلص', theme: theme),
                    if (needsEmail) ...[
                      const SizedBox(height: 12),
                      HzTextField(controller: _email, icon: Icons.mail_outline_rounded, hint: 'ایمیل (اختیاری؛ برای بازیابی حساب)', theme: theme, keyboardType: TextInputType.emailAddress),
                    ],
                    const SizedBox(height: 18),
                    section('ریشه‌های شما', Icons.public_rounded),
                    Text('هزاره‌نامه می‌خواهد هزاره‌های سراسر جهان را پیدا کند و ریشه‌های خانوادگی را نگاشت کند؛ این بخش اختیاری اما ارزشمند است.',
                        style: TextStyle(color: theme.textFaint, fontSize: 11.5, height: 1.8)),
                    const SizedBox(height: 12),
                    HzTextField(controller: _country, icon: Icons.public_rounded, hint: 'کشور محل سکونت فعلی', theme: theme, suggestions: AppConstants.countrySuggestions),
                    const SizedBox(height: 12),
                    HzTextField(controller: _originProvince, icon: Icons.map_rounded, hint: 'ولایت/منطقه‌ی اصلی نیاکان', theme: theme, suggestions: AppConstants.originSuggestions),
                    const SizedBox(height: 12),
                    HzTextField(controller: _district, icon: Icons.account_balance_rounded, hint: 'ولسوالی (مثلاً بهسود، یکاولنگ، جاغوری…)', theme: theme),
                    const SizedBox(height: 12),
                    HzTextField(controller: _tribe, icon: Icons.groups_rounded, hint: 'طایفه (اختیاری)', theme: theme),
                    const SizedBox(height: 12),
                    HzSelectField(
                      value: _nativeLanguage, icon: Icons.translate_rounded, hint: 'زبان مادری', theme: theme,
                      options: AppConstants.languageOptions, onChanged: (v) => setState(() => _nativeLanguage = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bio,
                      maxLines: 3,
                      style: TextStyle(fontFamily: 'Vazirmatn', color: theme.textPrimary, fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'چیزی درباره‌ی خودت یا ریشه‌ی خانواده‌ات بگو (اختیاری)…',
                        hintStyle: TextStyle(color: theme.textFaint, fontSize: 12.5),
                        filled: true,
                        fillColor: theme.bgCard.withValues(alpha: 0.4),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.glassBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.glassBorder)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TermsCheckRow(
                      theme: theme,
                      accepted: _acceptedTerms,
                      onToggle: () => setState(() => _acceptedTerms = !_acceptedTerms),
                      onReadTerms: () async {
                        final r = await showTermsSheet(context, theme);
                        if (!mounted) return;
                        if (r == true) setState(() => _acceptedTerms = true);
                      },
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
                    const SizedBox(height: 16),
                    HzPrimaryButton(theme: theme, label: _loading ? 'در حال ذخیره…' : 'ذخیره و ورود به هزاره‌نامه', icon: Icons.check_rounded, loading: _loading, onPressed: () => _save(app)),
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton(
                        onPressed: _loading ? null : () => app.logout(),
                        child: Text('خروج و ورود با حساب دیگر', style: TextStyle(color: theme.textFaint, fontSize: 12)),
                      ),
                    ),
                  ]),
                ).animate(delay: 120.ms).fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
