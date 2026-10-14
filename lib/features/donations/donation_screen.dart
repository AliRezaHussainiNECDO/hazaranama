import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/afghan_calendar.dart';
import '../../core/animated_backdrop.dart';
import '../../core/app_colors.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import 'donor_leaderboard_screen.dart';

const String kPaypalEmail = 'alireza.necdo@gmail.com';
const String kTransferRecipientName = 'Ali Reza Hussaini';
const String kTransferRecipientCity = 'Geneva';
const String kTransferRecipientCountry = 'Switzerland';

/// صفحه‌ی وب مستقل و عمومیِ «کمک‌های مالی» — روی iOS به‌جای نمایش مستقیم
/// مشخصات پی‌پال/حواله داخل اپ، کاربر با این لینک به مرورگر (Safari) فرستاده
/// می‌شود. این جدایی برای رعایت قوانین اپ‌استور اپل (بند ۳.۲.۱ و ۳.۲.۲) است:
/// اپل برای اپ‌هایی که هنوز به‌عنوان سازمان غیرانتفاعی تأیید نشده‌اند، فقط
/// جمع‌آوری کمک از طریق یک صفحه‌ی وب بیرون از اپ (بدون هیچ پرکردن خودکار) را
/// می‌پذیرد، نه نمایش مستقیم مشخصات پرداخت در صفحه‌ی خودِ اپ. نسخه‌ی اندروید
/// (که گوگل‌پلی چنین محدودیتی ندارد) همچنان کارت‌های PayPal/حواله را مستقیم
/// نشان می‌دهد.
const String kDonationWebUrl = 'https://hazaranama.com/donate/';

const List<String> kDonationCurrencies = ['USD', 'EUR', 'CHF', 'GBP', 'AFN'];

IconData donationCategoryIcon(DonationCategory c) {
  switch (c) {
    case DonationCategory.family:
      return Icons.menu_book_rounded;
    case DonationCategory.hospital:
      return Icons.dns_rounded;
    case DonationCategory.school:
      return Icons.school_outlined;
    case DonationCategory.roadsBridges:
      return Icons.library_music_rounded;
    case DonationCategory.general:
      return Icons.volunteer_activism;
  }
}

/// صفحه‌ی «کمک‌های مالی» — هدر تشویق‌کننده، دسته‌بندی‌های تأثیر، دو راه کمک
/// (پی‌پال و حواله)، فهرست حواله‌های خودِ کاربر، و فید گزارش‌های شفافیت
/// (با عکس/ویدیوی مستند) که با کمک هوش مصنوعی نوشته می‌شوند.
class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});
  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  bool _loading = true;
  final _waysKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final app = context.read<AppState>();
      await Future.wait([
        app.loadDonationSettings(),
        app.loadDonationReports(),
        app.loadMyDonationTransfers(),
      ]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    showHzToast(context, '$label کپی شد');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final settings = app.donationSettings;
    final reports = app.donationReports;
    final myTransfers = app.myDonationTransfers;

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
                backgroundColor: theme.bgElevated.withValues(alpha: 0.5),
                elevation: 0,
                leading: IconButton(icon: Icon(Icons.arrow_forward, color: theme.textPrimary, size: 20), onPressed: () => Navigator.of(context).pop()),
                title: Text('حمایت از هزاره‌نامه', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.6)),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                      children: [
                        _HeroCard(theme: theme, settings: settings),
                        if (donorPerksEnabled) ...[
                          const SizedBox(height: 14),
                          _LeaderboardButton(theme: theme),
                        ],
                        const SizedBox(height: 18),
                        _LegalNote(theme: theme),
                        const SizedBox(height: 18),
                        _ImpactCategoriesRow(theme: theme),
                        const SizedBox(height: 22),
                        KeyedSubtree(
                          key: _waysKey,
                          child: Row(children: [
                            Icon(Icons.volunteer_activism_outlined, size: 15, color: theme.success),
                            const SizedBox(width: 7),
                            Text('راه‌های حمایت', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        // در وب، Platform از dart:io خطای Unsupported می‌دهد؛ پس اول kIsWeb.
                        if (!kIsWeb && Platform.isIOS) ...[
                          _ExternalDonationCard(theme: theme),
                        ] else ...[
                          _PaypalCard(theme: theme, onCopy: _copy),
                          const SizedBox(height: 12),
                          _TransferCard(theme: theme, onCopy: _copy),
                        ],
                        if (myTransfers.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          Row(children: [
                            Icon(Icons.receipt_long_outlined, size: 15, color: theme.blue),
                            const SizedBox(width: 7),
                            Text('حواله‌های من', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                          ]),
                          const SizedBox(height: 12),
                          for (final t in myTransfers) ...[
                            _MyTransferCard(theme: theme, transfer: t),
                            const SizedBox(height: 8),
                          ],
                        ],
                        const SizedBox(height: 22),
                        Row(children: [
                          Icon(Icons.fact_check_outlined, size: 15, color: theme.aiViolet),
                          const SizedBox(width: 7),
                          Expanded(child: Text('گزارش‌های شفافیت مصرف حمایت‌ها', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800))),
                        ]),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(right: 22),
                          child: Text('این گزارش‌ها با کمک هوش مصنوعی نوشته می‌شوند تا مصرف واقعی حمایت‌های شما همیشه شفاف بماند.',
                              style: TextStyle(color: theme.textFaint, fontSize: 12, height: 1.7)),
                        ),
                        const SizedBox(height: 12),
                        if (reports.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: Text('هنوز گزارشی منتشر نشده — به‌زودی اولین گزارش را می‌بینید.', style: TextStyle(color: theme.textFaint, fontSize: 12))),
                          )
                        else
                          for (final r in reports) ...[
                            _ReportCard(theme: theme, report: r),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

// =============================================================================
// هدر تشویق‌کننده
// =============================================================================

class _HeroCard extends StatelessWidget {
  final AppColors theme;
  final DonationSettings settings;
  const _HeroCard({required this.theme, required this.settings});

  @override
  Widget build(BuildContext context) {
    return HzGlassCard(
      theme: theme,
      radius: 24,
      padding: EdgeInsets.zero,
      child: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [theme.success.withValues(alpha: 0.9), theme.aiTeal.withValues(alpha: 0.82), theme.blueDeep.withValues(alpha: 0.85)],
              ),
            ),
          ),
        ),
        Positioned(top: -20, left: -20, child: Icon(Icons.favorite, size: 130, color: Colors.white.withValues(alpha: 0.12))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(999)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.volunteer_activism, size: 13, color: Colors.white),
                SizedBox(width: 5),
                Text('حمایت از پروژه', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(height: 12),
            const Text('هزاره‌نامه را با هم زنده نگه داریم',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.4)),
            const SizedBox(height: 6),
            const Text(
              'هزاره‌نامه رایگان و بدون تبلیغ است. حمایت داوطلبانه‌ی شما هزینه‌ی سرور، پژوهش و نوشتن محتوای تازه، آموزش زبان هزارگی و آرشیو موسیقی و روایت‌های مردم هزاره را می‌پردازد؛ مصرف هر مبلغ با شفافیت کامل گزارش می‌شود.',
              style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.9),
            ),
            if (settings.totalRaised > 0 || settings.familiesHelped > 0) ...[
              const SizedBox(height: 16),
              Row(children: [
                if (settings.totalRaised > 0) Expanded(child: _stat('${settings.totalRaised.toStringAsFixed(0)} ${settings.currency}', 'جمع‌آوری‌شده')),
                if (settings.totalRaised > 0 && settings.familiesHelped > 0) const SizedBox(width: 8),
                if (settings.familiesHelped > 0) Expanded(child: _stat(toFaDigits('${settings.familiesHelped}'), 'حامی')),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _stat(String value, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );
}

/// دکمه‌ای به فهرست حامیان — فقط برای قدردانی (مقام‌ها از فعالیت می‌آیند، نه از حمایت مالی).
class _LeaderboardButton extends StatelessWidget {
  final AppColors theme;
  const _LeaderboardButton({required this.theme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DonorLeaderboardScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [theme.yellow.withValues(alpha: 0.16), theme.yellow.withValues(alpha: 0.06)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.yellow.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(Icons.emoji_events_rounded, size: 20, color: theme.yellow),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('فهرست حامیان', style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
              Text('سپاس از همه‌ی حامیان هزاره‌نامه', style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
            ]),
          ),
          Icon(Icons.arrow_back_ios_new, size: 13, color: theme.textFaint),
        ]),
      ),
    );
  }
}

class _ImpactCategoriesRow extends StatelessWidget {
  final AppColors theme;
  const _ImpactCategoriesRow({required this.theme});

  @override
  Widget build(BuildContext context) {
    final items = [DonationCategory.family, DonationCategory.hospital, DonationCategory.school, DonationCategory.roadsBridges];
    return Row(
      children: [
        for (final c in items) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.glassBorder)),
              child: Column(children: [
                Icon(donationCategoryIcon(c), size: 20, color: theme.success),
                const SizedBox(height: 6),
                Text(donationCategoryLabel(c), textAlign: TextAlign.center, maxLines: 2, style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, height: 1.3)),
              ]),
            ),
          ),
          if (c != items.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

// =============================================================================
// کارت کمک مالی — نسخه‌ی iOS (لینک بیرونی به‌جای نمایش مستقیم مشخصات پرداخت)
// =============================================================================

/// روی iOS، به‌جای دو کارت PayPal/حواله، کاربر با یک دکمه به صفحه‌ی وب عمومی
/// «کمک‌های مالی» (خارج از اپ، در Safari) فرستاده می‌شود. دلیل: راهنمای اپ‌استور
/// اپل برای اپ‌هایی که تأییدیه‌ی سازمان غیرانتفاعی ندارند.
class _ExternalDonationCard extends StatelessWidget {
  final AppColors theme;
  const _ExternalDonationCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return HzGlassCard(
      theme: theme,
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatIconBox(icon: Icons.volunteer_activism_outlined, color: theme.success, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('حمایت از طریق وب‌سایت', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('PayPal و حواله‌ی بانکی — روی صفحه‌ی وب هزاره‌نامه', style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Text(
          'برای رعایت قوانین اپ‌استور اپل، مشخصات پرداخت (ایمیل پی‌پال و اطلاعات حواله) را در یک صفحه‌ی وب جداگانه گذاشته‌ایم. با زدن دکمه‌ی زیر، همان مشخصات در مرورگرتان باز می‌شود.',
          style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.9),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => openContentUrl(context, kDonationWebUrl),
            icon: const Icon(Icons.open_in_new, size: 15),
            label: const Text('باز کردن صفحه‌ی حمایت', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.success, foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DonationTransferFormScreen())),
            icon: const Icon(Icons.edit_note, size: 16),
            label: const Text('قبلاً حمایت کرده‌اید؟ ثبتش کنید', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.success, side: BorderSide(color: theme.success.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
// کارت پی‌پال
// =============================================================================

class _PaypalCard extends StatelessWidget {
  final AppColors theme;
  final void Function(String label, String value) onCopy;
  const _PaypalCard({required this.theme, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return HzGlassCard(
      theme: theme,
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatIconBox(icon: Icons.payments_outlined, color: theme.blue, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ارسال از طریق PayPal', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('ساده و آنی — برای کاربران خارج از افغانستان', style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: theme.blue.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.blue.withValues(alpha: 0.25))),
          child: Row(children: [
            Icon(Icons.email_outlined, size: 15, color: theme.blue),
            const SizedBox(width: 8),
            Expanded(child: Text(kPaypalEmail, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700))),
            InkWell(
              onTap: () => onCopy('ایمیل پی‌پال', kPaypalEmail),
              borderRadius: BorderRadius.circular(8),
              child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.copy_rounded, size: 16, color: theme.blue)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Text('در اپ یا سایت PayPal، گزینه‌ی Send را بزنید، همین ایمیل را وارد کنید و برای اینکه کارمزد کم‌تری کسر شود، گزینه‌ی «Friends & Family» را انتخاب کنید.',
            style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.9)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => openContentUrl(context, 'https://www.paypal.com'),
            icon: const Icon(Icons.open_in_new, size: 15),
            label: const Text('باز کردن PayPal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.blue, foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DonationTransferFormScreen(method: DonationMethod.paypal))),
            icon: const Icon(Icons.edit_note, size: 16),
            label: const Text('بعد از ارسال، حمایتم را ثبت کن', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.blue, side: BorderSide(color: theme.blue.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
// کارت حواله
// =============================================================================

class _TransferCard extends StatelessWidget {
  final AppColors theme;
  final void Function(String label, String value) onCopy;
  const _TransferCard({required this.theme, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return HzGlassCard(
      theme: theme,
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatIconBox(icon: Icons.account_balance_outlined, color: theme.yellow, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ارسال از طریق حواله', style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('صرافی، ویسترن یونیون یا هر روش حواله‌ی دلخواه شما', style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: theme.yellow.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.yellow.withValues(alpha: 0.28))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _row(Icons.person_outline, 'نام گیرنده', kTransferRecipientName),
            const SizedBox(height: 8),
            _row(Icons.location_city_outlined, 'شهر', kTransferRecipientCity),
            const SizedBox(height: 8),
            _row(Icons.flag_outlined, 'کشور', kTransferRecipientCountry),
          ]),
        ),
        const SizedBox(height: 10),
        Text('بعد از ارسال حواله از طریق صرافی یا بانک محل خودتان، جزئیات آن را همین‌جا ثبت کنید تا مدیریت دریافت آن را تأیید کند و در گزارش شفافیت شما لحاظ شود.',
            style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.9)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DonationTransferFormScreen())),
            icon: const Icon(Icons.edit_note, size: 16),
            label: const Text('ثبت جزئیات حواله‌ی من', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.yellow, side: BorderSide(color: theme.yellow.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 14, color: theme.yellow),
      const SizedBox(width: 8),
      Text('$label: ', style: TextStyle(color: theme.textFaint, fontSize: 12)),
      Expanded(child: Text(value, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700))),
      InkWell(
        onTap: () => onCopy(label, value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.copy_rounded, size: 14, color: theme.yellow)),
      ),
    ]);
  }
}

class _MyTransferCard extends StatelessWidget {
  final AppColors theme;
  final DonationTransfer transfer;
  const _MyTransferCard({required this.theme, required this.transfer});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (transfer.status) {
      DonationTransferStatus.confirmed => ('تأییدشده ✓', theme.success),
      DonationTransferStatus.rejected => ('رد شده', theme.danger),
      DonationTransferStatus.pending => ('در انتظار تأیید مدیر', theme.yellow),
    };
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.glassBorder)),
      child: Row(children: [
        StatIconBox(icon: donationCategoryIcon(transfer.category), color: color, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${transfer.amount.toStringAsFixed(0)} ${transfer.currency} — ${donationCategoryLabel(transfer.category)}',
                style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('${donationMethodLabel(transfer.method)} · ${afghanDateLabel(transfer.submittedAt)}', style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
          child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

// =============================================================================
// کارت گزارش شفافیت
// =============================================================================

class _ReportCard extends StatelessWidget {
  final AppColors theme;
  final DonationReport report;
  const _ReportCard({required this.theme, required this.report});

  @override
  Widget build(BuildContext context) {
    final hasImage = report.imageUrls.isNotEmpty;
    final hasVideo = report.videoUrl != null && report.videoUrl!.isNotEmpty;
    return HzGlassCard(
      theme: theme,
      radius: 20,
      padding: EdgeInsets.zero,
      onTap: hasVideo ? () => openContentUrl(context, report.videoUrl!) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (hasImage)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(children: [
              Image.network(report.imageUrls.first, height: 150, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 150, color: theme.bgCardAlt)),
              if (hasVideo)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.18),
                    alignment: Alignment.center,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                ),
              if (report.imageUrls.length > 1)
                Positioned(
                  left: 10, bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.photo_library_outlined, size: 11, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('${report.imageUrls.length}', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.all(15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: theme.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(donationCategoryIcon(report.category), size: 11, color: theme.success),
                  const SizedBox(width: 4),
                  Text(donationCategoryLabel(report.category), style: TextStyle(color: theme.success, fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
              ),
              const Spacer(),
              Text(report.publishedAtLabel, style: TextStyle(color: theme.textFaint, fontSize: 11)),
            ]),
            const SizedBox(height: 8),
            Text(report.title, style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800, height: 1.5)),
            const SizedBox(height: 5),
            Text(report.summary, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 1.8)),
            if (report.amountSpent != null || report.location != null || report.beneficiariesCount != null) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (report.amountSpent != null) _chip(Icons.payments_outlined, '${report.amountSpent!.toStringAsFixed(0)} ${report.currency} مصرف شد'),
                if (report.location != null && report.location!.isNotEmpty) _chip(Icons.place_outlined, report.location!),
                if (report.beneficiariesCount != null) _chip(Icons.groups_outlined, '${toFaDigits('${report.beneficiariesCount}')} نفر/خانواده'),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: theme.bgCardAlt, borderRadius: BorderRadius.circular(999), border: Border.all(color: theme.glassBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: theme.textFaint),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

// =============================================================================
// فرم ثبت جزئیات حواله
// =============================================================================

class DonationTransferFormScreen extends StatefulWidget {
  final DonationMethod method;
  const DonationTransferFormScreen({super.key, this.method = DonationMethod.bankTransfer});
  @override
  State<DonationTransferFormScreen> createState() => _DonationTransferFormScreenState();
}

class _DonationTransferFormScreenState extends State<DonationTransferFormScreen> {
  late final TextEditingController _nameCtrl;
  final _countryCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _currency = 'USD';
  DonationCategory _category = DonationCategory.general;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().currentUser;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _countryCtrl.text = (user?.country != null && user!.country != 'نامشخص') ? user.country : '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _countryCtrl.dispose();
    _contactCtrl.dispose();
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (_nameCtrl.text.trim().isEmpty) {
      showHzToast(context, 'نام ارسال‌کننده را وارد کنید.');
      return;
    }
    if (_countryCtrl.text.trim().isEmpty) {
      showHzToast(context, 'کشور خودتان را وارد کنید.');
      return;
    }
    if (amount == null || amount <= 0) {
      showHzToast(context, 'مبلغ حواله را درست وارد کنید.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await app.submitDonationTransfer(
        senderName: _nameCtrl.text.trim(),
        senderCountry: _countryCtrl.text.trim(),
        senderContact: _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
        amount: amount,
        currency: _currency,
        transferReference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        category: _category,
        method: widget.method,
      );
      if (mounted) {
        Navigator.of(context).pop();
        showHzToast(context, 'متشکریم! اعلام حمایت شما ثبت شد و به‌زودی تأیید می‌شود.');
      }
    } catch (_) {
      if (mounted) showHzToast(context, 'ثبت جزئیات ناموفق بود؛ دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final isPaypal = widget.method == DonationMethod.paypal;

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
                backgroundColor: theme.bgElevated.withValues(alpha: 0.5),
                elevation: 0,
                leading: IconButton(icon: Icon(Icons.arrow_forward, color: theme.textPrimary, size: 20), onPressed: () => Navigator.of(context).pop()),
                title: Text(isPaypal ? 'ثبت اعلام حمایت پی‌پال' : 'ثبت جزئیات حواله', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
        body: Stack(children: [
          Positioned.fill(child: AnimatedBackdrop(theme: theme, intensity: 0.6)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: theme.yellow.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.yellow.withValues(alpha: 0.28))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline, size: 15, color: theme.yellow),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isPaypal
                            ? 'این فرم فقط جزئیات حمایتی را ثبت می‌کند که خودتان از طریق PayPal به ایمیل «$kPaypalEmail» ارسال کرده‌اید یا در حال ارسال آن هستید — تا مدیر دریافت واقعی را تأیید کند.'
                            : 'این فرم فقط جزئیات حواله‌ای را ثبت می‌کند که خودتان از طریق صرافی/بانک برای «$kTransferRecipientName» در $kTransferRecipientCity، $kTransferRecipientCountry ارسال کرده‌اید یا در حال ارسال آن هستید.',
                        style: TextStyle(color: theme.textPrimary, fontSize: 12.5, height: 1.8, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
                _label(theme, isPaypal ? 'نام کامل ارسال‌کننده (یا نام حساب پی‌پال)' : 'نام کامل ارسال‌کننده'),
                _field(theme, _nameCtrl, hint: 'نام شما (همان‌طور که در تراکنش ثبت شده)'),
                const SizedBox(height: 12),
                _label(theme, 'کشور شما'),
                _field(theme, _countryCtrl, hint: 'مثلاً: سویس'),
                const SizedBox(height: 12),
                _label(theme, 'شماره تماس یا ایمیل (اختیاری)'),
                _field(theme, _contactCtrl, hint: isPaypal ? 'ایمیلی که با آن در پی‌پال ارسال کردید' : 'برای هماهنگی احتمالی'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label(theme, 'مبلغ'),
                      _field(theme, _amountCtrl, hint: '۰', keyboardType: TextInputType.number),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 108,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label(theme, 'واحد پول'),
                      HzSelectField(
                        value: _currency,
                        icon: Icons.attach_money,
                        hint: 'واحد پول',
                        options: kDonationCurrencies,
                        theme: theme,
                        onChanged: (v) => setState(() => _currency = v ?? 'USD'),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                _label(theme, 'این حمایت برای کدام بخش باشد؟ (اختیاری)'),
                HzSelectField(
                  value: donationCategoryLabel(_category),
                  icon: Icons.category_outlined,
                  hint: 'دسته‌بندی',
                  options: DonationCategory.values.map(donationCategoryLabel).toList(),
                  theme: theme,
                  onChanged: (v) {
                    final match = DonationCategory.values.firstWhere((c) => donationCategoryLabel(c) == v, orElse: () => DonationCategory.general);
                    setState(() => _category = match);
                  },
                ),
                const SizedBox(height: 12),
                _label(theme, isPaypal ? 'شماره تراکنش پی‌پال (اختیاری)' : 'شماره/کد پیگیری حواله (اختیاری)'),
                _field(theme, _refCtrl, hint: isPaypal ? 'مثلاً: Transaction ID پی‌پال' : 'مثلاً: کد MTCN یا شماره فیش صرافی'),
                const SizedBox(height: 12),
                _label(theme, 'یادداشت (اختیاری)'),
                _field(theme, _noteCtrl, hint: 'هر نکته‌ی دیگری که برای تأیید حمایت لازم است…', maxLines: 3),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _submitting ? null : () => _submit(app),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.yellow, foregroundColor: theme.bg, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: theme.bg))
                      : Text(isPaypal ? 'ثبت اعلام حمایت پی‌پال' : 'ثبت جزئیات حواله', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(AppColors theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700)),
      );

  Widget _field(AppColors theme, TextEditingController ctrl, {String hint = '', int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.textPrimary, fontSize: 12.5, height: 1.8),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textFaint, fontSize: 12.5),
        filled: true, fillColor: theme.bgCard.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.glassBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.yellow)),
      ),
    );
  }
}

/// یادداشت حقوقی — همان متن صفحه‌ی وب: هزاره‌نامه خیریه‌ی ثبت‌شده نیست و
/// حمایت مالی داوطلبانه، غیرقابل کسر از مالیات و بدون دریافت کالا/خدمت است.
class _LegalNote extends StatelessWidget {
  final AppColors theme;
  const _LegalNote({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.bgCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.glassBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.gavel_rounded, size: 16, color: theme.textFaint),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'هزاره‌نامه یک پروژه‌ی فرهنگی و آموزشیِ مستقل است، نه سازمان خیریه‌ی ثبت‌شده. '
            'حمایت مالی کاملاً داوطلبانه است، کمک خیریه یا قابل کسر از مالیات به شمار نمی‌رود، '
            'و در برابر آن کالا یا خدمتی دریافت نمی‌کنید. همه‌ی مبالغ فقط صرف توسعه و نگه‌داری '
            'هزاره‌نامه (محتوا، سرور، آموزش و آرشیو) می‌شود و گزارش مصرف آن به‌صورت عمومی منتشر می‌گردد.',
            style: TextStyle(color: theme.textFaint, fontSize: 11, height: 1.8),
          ),
        ),
      ]),
    );
  }
}
