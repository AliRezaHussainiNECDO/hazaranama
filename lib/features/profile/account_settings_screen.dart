import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_constants.dart';
import '../../core/app_logo.dart';
import '../../core/widgets.dart';
import '../../state/app_state.dart';
import 'blocked_users_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late TextEditingController _name;
  late TextEditingController _country;
  late TextEditingController _originProvince;
  late TextEditingController _district;
  late TextEditingController _tribe;
  late TextEditingController _bio;
  String? _nativeLanguage;

  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _showPass = false;

  bool _savingProfile = false;
  bool _deletingAccount = false;
  bool _savingPassword = false;
  String? _profileError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    final u = context.read<AppState>().currentUser!;
    _name = TextEditingController(text: u.name);
    _country = TextEditingController(text: u.country == 'نامشخص' ? '' : u.country);
    _originProvince = TextEditingController(text: u.originProvince == 'نامشخص' ? '' : u.originProvince);
    _district = TextEditingController(text: u.district == 'نامشخص' ? '' : u.district);
    _tribe = TextEditingController(text: u.tribe == '—' ? '' : u.tribe);
    _bio = TextEditingController(text: u.bio);
    _nativeLanguage = AppConstants.languageOptions.contains(u.nativeLanguage) ? u.nativeLanguage : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    _originProvince.dispose();
    _district.dispose();
    _tribe.dispose();
    _bio.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(AppState app) async {
    setState(() { _savingProfile = true; _profileError = null; });
    if (_name.text.trim().isEmpty) {
      setState(() { _savingProfile = false; _profileError = 'نام نمی‌تواند خالی باشد.'; });
      return;
    }
    try {
      await app.updateMyProfile(
        name: _name.text.trim(),
        country: _country.text.trim().isEmpty ? 'نامشخص' : _country.text.trim(),
        originProvince: _originProvince.text.trim().isEmpty ? 'نامشخص' : _originProvince.text.trim(),
        district: _district.text.trim().isEmpty ? 'نامشخص' : _district.text.trim(),
        tribe: _tribe.text.trim().isEmpty ? '—' : _tribe.text.trim(),
        nativeLanguage: _nativeLanguage ?? 'نامشخص',
        bio: _bio.text.trim(),
      );
      if (mounted) showHzToast(context, 'اطلاعات پروفایل ذخیره شد');
    } catch (_) {
      setState(() => _profileError = 'ذخیره ناموفق بود؛ دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePassword(AppState app) async {
    setState(() { _passwordError = null; });
    if (_currentPassword.text.isEmpty || _newPassword.text.isEmpty) {
      setState(() => _passwordError = 'رمز فعلی و رمز تازه را وارد کنید.');
      return;
    }
    if (_newPassword.text.length < 6) {
      setState(() => _passwordError = 'رمز تازه باید حداقل ۶ نویسه باشد.');
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      setState(() => _passwordError = 'رمز تازه و تکرار آن یکسان نیستند.');
      return;
    }
    setState(() => _savingPassword = true);
    final error = await app.changePassword(currentPassword: _currentPassword.text, newPassword: _newPassword.text);
    if (!mounted) return;
    setState(() => _savingPassword = false);
    if (error != null) {
      setState(() => _passwordError = error);
    } else {
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      showHzToast(context, 'رمز عبور با موفقیت تغییر کرد');
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
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: AppBar(
                backgroundColor: theme.bgElevated.withValues(alpha: 0.5), elevation: 0,
                leading: IconButton(icon: Icon(Icons.arrow_forward, color: theme.textPrimary, size: 20), onPressed: () => Navigator.of(context).pop()),
                title: Text('تنظیمات حساب', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.6)),
          SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            children: [
              HzGlassCard(
                theme: theme,
                radius: 22,
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _sectionHeader(theme, Icons.person_outline, 'ویرایش اطلاعات پروفایل'),
                  const SizedBox(height: 14),
                  HzTextField(controller: _name, icon: Icons.badge_outlined, hint: 'نام و تخلص', theme: theme),
                  const SizedBox(height: 12),
                  HzTextField(controller: _country, icon: Icons.public, hint: 'کشور محل سکونت فعلی', theme: theme, suggestions: AppConstants.countrySuggestions),
                  const SizedBox(height: 12),
                  HzTextField(controller: _originProvince, icon: Icons.map_outlined, hint: 'ولایت/منطقه‌ی اصلی نیاکان', theme: theme, suggestions: AppConstants.originSuggestions),
                  const SizedBox(height: 12),
                  HzTextField(controller: _district, icon: Icons.account_balance_outlined, hint: 'ولسوالی', theme: theme),
                  const SizedBox(height: 12),
                  HzTextField(controller: _tribe, icon: Icons.groups_outlined, hint: 'طایفه (اختیاری)', theme: theme),
                  const SizedBox(height: 12),
                  HzSelectField(
                    value: _nativeLanguage, icon: Icons.translate, hint: 'زبان مادری', theme: theme,
                    options: AppConstants.languageOptions, onChanged: (v) => setState(() => _nativeLanguage = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bio, maxLines: 3,
                    style: TextStyle(color: theme.textPrimary, fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'یادداشتی درباره‌ی ریشه‌ی خانواده‌ات (اختیاری)…',
                      hintStyle: TextStyle(color: theme.textFaint, fontSize: 12.5),
                      filled: true, fillColor: theme.bgCard.withValues(alpha: 0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.glassBorder)),
                    ),
                  ),
                  if (_profileError != null) ...[
                    const SizedBox(height: 10),
                    _errorBox(theme, _profileError!),
                  ],
                  const SizedBox(height: 14),
                  HzPrimaryButton(theme: theme, label: _savingProfile ? 'در حال ذخیره…' : 'ذخیره‌ی اطلاعات', loading: _savingProfile, onPressed: () => _saveProfile(app)),
                ]),
              ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 22),
              HzGlassCard(
                theme: theme,
                radius: 22,
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _sectionHeader(theme, Icons.lock_outline, 'تغییر رمز عبور'),
                  const SizedBox(height: 14),
                  HzTextField(controller: _currentPassword, icon: Icons.lock_outline, hint: 'رمز عبور فعلی', theme: theme, obscureText: !_showPass),
                  const SizedBox(height: 12),
                  HzTextField(
                    controller: _newPassword, icon: Icons.lock_reset, hint: 'رمز عبور تازه', theme: theme, obscureText: !_showPass,
                    suffix: IconButton(icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, size: 18, color: theme.textFaint), onPressed: () => setState(() => _showPass = !_showPass)),
                  ),
                  const SizedBox(height: 12),
                  HzTextField(controller: _confirmPassword, icon: Icons.lock_reset, hint: 'تکرار رمز عبور تازه', theme: theme, obscureText: !_showPass),
                  if (_passwordError != null) ...[
                    const SizedBox(height: 10),
                    _errorBox(theme, _passwordError!),
                  ],
                  const SizedBox(height: 14),
                  HzPrimaryButton(theme: theme, label: _savingPassword ? 'در حال تغییر…' : 'تغییر رمز عبور', loading: _savingPassword, onPressed: () => _savePassword(app)),
                ]),
              ).animate(delay: 80.ms).fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 22),
              HzGlassCard(
                theme: theme,
                radius: 22,
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _sectionHeader(theme, Icons.warning_amber_rounded, 'حذف حساب کاربری'),
                  const SizedBox(height: 10),
                  Text(
                    'با حذف حساب، پروفایل، پست‌ها، کامنت‌ها، پیام‌ها و تمام اطلاعات شخصی شما برای همیشه از هزاره‌نامه پاک می‌شود. این کار غیرقابل بازگشت است.',
                    style: TextStyle(color: theme.textFaint, fontSize: 11.5, height: 1.8),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _deletingAccount ? null : () => _confirmDeleteAccount(app),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.danger,
                        side: BorderSide(color: theme.danger.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _deletingAccount
                          ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: theme.danger))
                          : const Icon(Icons.delete_forever_outlined, size: 18),
                      label: Text(_deletingAccount ? 'در حال حذف…' : 'حذف همیشگی حساب من', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BlockedUsersScreen())),
                      icon: Icon(Icons.block_outlined, size: 15, color: theme.textFaint),
                      label: Text('کاربران مسدودشده', style: TextStyle(color: theme.textFaint, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => openContentUrl(context, 'https://claude.ai/code/artifact/6a99f9a5-adca-4153-a980-bd844bb3213f'),
                      icon: Icon(Icons.privacy_tip_outlined, size: 15, color: theme.textFaint),
                      label: Text('سیاست حریم خصوصی و حذف داده', style: TextStyle(color: theme.textFaint, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ).animate(delay: 160.ms).fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0),
            ],
          ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionHeader(theme, IconData icon, String title) {
    return Row(children: [
      StatIconBox(icon: icon, color: theme.blue, size: 32),
      const SizedBox(width: 10),
      Expanded(child: Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800))),
    ]).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0);
  }

  void _confirmDeleteAccount(AppState app) {
    final theme = app.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.bgElevated,
        title: Text('حساب کاربری‌تان برای همیشه حذف شود؟', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        content: Text(
          'پروفایل، پست‌ها، کامنت‌ها، پیام‌ها و هر اطلاعات دیگری که با این حساب ثبت کرده‌اید، پاک می‌شود و امکان بازگرداندن آن وجود ندارد.',
          style: TextStyle(color: theme.textFaint, fontSize: 12, height: 1.7),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('انصراف')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteAccount(app);
            },
            child: Text('حذف همیشگی', style: TextStyle(color: theme.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(AppState app) async {
    setState(() => _deletingAccount = true);
    final error = await app.deleteAccount();
    if (!mounted) return;
    if (error != null) {
      setState(() => _deletingAccount = false);
      showHzToast(context, error);
      return;
    }
    // پس از موفقیت، AppState.stage به welcome تغییر کرده و ریشه‌ی اپ خودش
    // صفحه را عوض می‌کند؛ اگر این صفحه هنوز روی پشته مانده باشد (حالت نادر)،
    // آن را هم می‌بندیم.
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Widget _errorBox(theme, String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: theme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Text(msg, style: TextStyle(color: theme.danger, fontSize: 11.5)),
      );
}
