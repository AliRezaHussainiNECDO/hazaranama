import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/afghan_calendar.dart';
import '../../core/app_colors.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../services/ai_service.dart';
import '../../state/app_state.dart';
import '../donations/donation_screen.dart' show donationCategoryIcon, kDonationCurrencies;

/// پنل مدیریت «کمک‌های مالی» — سه بخش: حواله‌های ارسالی (تأیید/رد)،
/// گزارش‌های شفافیت (نوشتن با کمک هوش مصنوعی + عکس/ویدیو)، و تنظیمات/آمار
/// کلی کمپین (چون پرداخت PayPal بیرون از اپ و بدون اتصال خودکار است).
class DonationManagerPage extends StatefulWidget {
  const DonationManagerPage({super.key});
  @override
  State<DonationManagerPage> createState() => _DonationManagerPageState();
}

class _DonationManagerPageState extends State<DonationManagerPage> {
  int _tab = 0; // 0 = حواله‌ها، 1 = گزارش‌های شفافیت، 2 = تنظیمات/آمار
  String _statusFilter = 'all';
  bool _loading = false;
  final _ai = AiService();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final app = context.read<AppState>();
    await Future.wait([app.loadAllDonationTransfers(), app.loadDonationReports(), app.loadDonationSettings()]);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(children: [
          Expanded(child: _TabChip(theme: theme, label: 'حواله‌ها', selected: _tab == 0, onTap: () => setState(() => _tab = 0))),
          const SizedBox(width: 6),
          Expanded(child: _TabChip(theme: theme, label: 'گزارش‌های شفافیت', selected: _tab == 1, onTap: () => setState(() => _tab = 1))),
          const SizedBox(width: 6),
          Expanded(child: _TabChip(theme: theme, label: 'تنظیمات و آمار', selected: _tab == 2, onTap: () => setState(() => _tab = 2))),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : switch (_tab) {
                0 => _TransfersTab(
                    theme: theme,
                    app: app,
                    statusFilter: _statusFilter,
                    onFilterChanged: (f) => setState(() => _statusFilter = f),
                    onRefresh: _refresh,
                  ),
                1 => _ReportsTab(theme: theme, app: app, ai: _ai, onRefresh: _refresh),
                _ => _SettingsStatsTab(theme: theme, app: app),
              },
      ),
    ]);
  }
}

class _TabChip extends StatelessWidget {
  final AppColors theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({required this.theme, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? theme.success : theme.bgCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? theme.success : theme.glassBorder),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// =============================================================================
// تب حواله‌ها
// =============================================================================

class _TransfersTab extends StatelessWidget {
  final AppColors theme;
  final AppState app;
  final String statusFilter;
  final void Function(String) onFilterChanged;
  final Future<void> Function() onRefresh;

  const _TransfersTab({required this.theme, required this.app, required this.statusFilter, required this.onFilterChanged, required this.onRefresh});

  static const _filters = {'all': 'همه', 'pending': 'در انتظار', 'confirmed': 'تأییدشده', 'rejected': 'رد شده'};

  @override
  Widget build(BuildContext context) {
    var items = app.allDonationTransfers;
    if (statusFilter != 'all') {
      items = items.where((t) => t.status.name == statusFilter).toList();
    }
    final pendingCount = app.allDonationTransfers.where((t) => t.status == DonationTransferStatus.pending).length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (pendingCount > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: theme.yellow.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.yellow.withValues(alpha: 0.3))),
              child: Row(children: [
                Icon(Icons.hourglass_bottom, size: 15, color: theme.yellow),
                const SizedBox(width: 8),
                Expanded(child: Text('$pendingCount حواله در انتظار تأیید شماست.', style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.w700))),
              ]),
            ),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final key = _filters.keys.elementAt(i);
                final selected = statusFilter == key;
                return InkWell(
                  onTap: () => onFilterChanged(key),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? theme.success.withValues(alpha: 0.16) : theme.bgCard.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: selected ? theme.success : theme.glassBorder),
                    ),
                    child: Text(_filters[key]!, style: TextStyle(color: selected ? theme.success : theme.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('حواله‌ای در این وضعیت یافت نشد', style: TextStyle(color: theme.textFaint, fontSize: 12))),
            )
          else
            for (final t in items) ...[
              _TransferCard(theme: theme, app: app, transfer: t, onChanged: onRefresh),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _TransferCard extends StatefulWidget {
  final AppColors theme;
  final AppState app;
  final DonationTransfer transfer;
  final Future<void> Function() onChanged;
  const _TransferCard({required this.theme, required this.app, required this.transfer, required this.onChanged});

  @override
  State<_TransferCard> createState() => _TransferCardState();
}

class _TransferCardState extends State<_TransferCard> {
  bool _busy = false;

  Color get _statusColor => switch (widget.transfer.status) {
        DonationTransferStatus.confirmed => widget.theme.success,
        DonationTransferStatus.rejected => widget.theme.danger,
        DonationTransferStatus.pending => widget.theme.yellow,
      };

  String get _statusLabel => switch (widget.transfer.status) {
        DonationTransferStatus.confirmed => 'تأییدشده',
        DonationTransferStatus.rejected => 'رد شده',
        DonationTransferStatus.pending => 'در انتظار',
      };

  Future<void> _decide(String status) async {
    double? confirmedAmount;
    if (status == 'confirmed') {
      final ctrl = TextEditingController(text: widget.transfer.amount.toStringAsFixed(0));
      final theme = widget.theme;
      final result = await showDialog<double>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: theme.bgElevated,
          title: Text('تأیید دریافت حواله', style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: theme.textPrimary),
            decoration: InputDecoration(labelText: 'مبلغ واقعاً دریافت‌شده (${widget.transfer.currency})', labelStyle: TextStyle(color: theme.textFaint)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('انصراف')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(double.tryParse(ctrl.text.trim()) ?? widget.transfer.amount), child: Text('تأیید', style: TextStyle(color: theme.success, fontWeight: FontWeight.w700))),
          ],
        ),
      );
      if (result == null) return;
      confirmedAmount = result;
    }
    setState(() => _busy = true);
    try {
      await widget.app.updateDonationTransferStatus(widget.transfer.id, status, confirmedAmount: confirmedAmount);
      await widget.onChanged();
      if (mounted) showHzToast(context, status == 'confirmed' ? 'حواله تأیید شد.' : 'حواله رد شد.');
    } catch (_) {
      if (mounted) showHzToast(context, 'ثبت تصمیم ناموفق بود.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final t = widget.transfer;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatIconBox(icon: donationCategoryIcon(t.category), color: _statusColor, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.senderName, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)),
              Text('${t.senderCountry} — ${afghanDateLabel(t.submittedAt)}', style: TextStyle(color: theme.textFaint, fontSize: 10)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
            child: Text(_statusLabel, style: TextStyle(color: _statusColor, fontSize: 9.5, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _chip(theme, Icons.payments_outlined, '${t.amount.toStringAsFixed(0)} ${t.currency}'),
          _chip(theme, t.method == DonationMethod.paypal ? Icons.account_balance_wallet_outlined : Icons.account_balance_outlined, donationMethodLabel(t.method)),
          _chip(theme, Icons.category_outlined, donationCategoryLabel(t.category)),
          if (t.transferReference != null && t.transferReference!.isNotEmpty) _chip(theme, Icons.confirmation_number_outlined, t.transferReference!),
          if (t.senderContact != null && t.senderContact!.isNotEmpty) _chip(theme, Icons.contact_phone_outlined, t.senderContact!),
        ]),
        if (t.note != null && t.note!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(t.note!, style: TextStyle(color: theme.textSecondary, fontSize: 11, height: 1.7)),
        ],
        if (t.status == DonationTransferStatus.pending) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _decide('confirmed'),
                icon: const Icon(Icons.check_circle_outline, size: 15),
                label: const Text('تأیید دریافت', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(foregroundColor: theme.success, side: BorderSide(color: theme.success.withValues(alpha: 0.5)), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _decide('rejected'),
                icon: const Icon(Icons.cancel_outlined, size: 15),
                label: const Text('رد کردن', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(foregroundColor: theme.danger, side: BorderSide(color: theme.danger.withValues(alpha: 0.4)), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ]),
        ] else if (t.confirmedAmount != null) ...[
          const SizedBox(height: 8),
          Text('مبلغ تأییدشده: ${t.confirmedAmount!.toStringAsFixed(0)} ${t.currency}', style: TextStyle(color: theme.success, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }

  Widget _chip(AppColors theme, IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: theme.bgCardAlt, borderRadius: BorderRadius.circular(999), border: Border.all(color: theme.glassBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: theme.textFaint),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: theme.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w700)),
        ]),
      );
}

// =============================================================================
// تب گزارش‌های شفافیت
// =============================================================================

class _ReportsTab extends StatelessWidget {
  final AppColors theme;
  final AppState app;
  final AiService ai;
  final Future<void> Function() onRefresh;
  const _ReportsTab({required this.theme, required this.app, required this.ai, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final reports = app.donationReports;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openReportForm(context, app, ai, null, onRefresh),
              icon: const Icon(Icons.add_a_photo_outlined, size: 16),
              label: const Text('گزارش شفافیت تازه', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(backgroundColor: theme.success, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('هنوز گزارشی منتشر نشده', style: TextStyle(color: theme.textFaint, fontSize: 12))),
            )
          else
            for (final r in reports) ...[
              _ReportAdminCard(theme: theme, app: app, ai: ai, report: r, onRefresh: onRefresh),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ReportAdminCard extends StatelessWidget {
  final AppColors theme;
  final AppState app;
  final AiService ai;
  final DonationReport report;
  final Future<void> Function() onRefresh;
  const _ReportAdminCard({required this.theme, required this.app, required this.ai, required this.report, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: report.imageUrls.isNotEmpty
              ? Image.network(report.imageUrls.first, width: 56, height: 56, fit: BoxFit.cover)
              : Container(width: 56, height: 56, color: theme.bgCardAlt, child: Icon(donationCategoryIcon(report.category), size: 20, color: theme.textFaint)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(report.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('${donationCategoryLabel(report.category)} — ${report.publishedAtLabel}', style: TextStyle(color: theme.textFaint, fontSize: 10)),
          ]),
        ),
        IconButton(icon: Icon(Icons.edit_outlined, size: 16, color: theme.blue), onPressed: () => _openReportForm(context, app, ai, report, onRefresh)),
        IconButton(icon: Icon(Icons.delete_outline, size: 16, color: theme.danger), onPressed: () => _confirmDelete(context, app, report, onRefresh)),
      ]),
    );
  }

  void _confirmDelete(BuildContext context, AppState app, DonationReport report, Future<void> Function() onRefresh) {
    showDialog(context: context, builder: (ctx) {
      return AlertDialog(
        backgroundColor: theme.bgElevated,
        title: Text('حذف گزارش «${report.title}»؟', style: TextStyle(color: theme.textPrimary, fontSize: 13.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('انصراف')),
          TextButton(
            onPressed: () async { await app.deleteDonationReport(report.id); if (ctx.mounted) Navigator.of(ctx).pop(); await onRefresh(); if (context.mounted) showHzToast(context, 'گزارش حذف شد'); },
            child: Text('حذف', style: TextStyle(color: theme.danger)),
          ),
        ],
      );
    });
  }
}

void _openReportForm(BuildContext context, AppState app, AiService ai, DonationReport? existing, Future<void> Function() onRefresh) {
  final theme = app.colors;
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final rawNotesCtrl = TextEditingController();
  final summaryCtrl = TextEditingController(text: existing?.summary ?? '');
  final bodyCtrl = TextEditingController(text: existing?.body ?? '');
  final amountCtrl = TextEditingController(text: existing?.amountSpent?.toStringAsFixed(0) ?? '');
  final locationCtrl = TextEditingController(text: existing?.location ?? '');
  final beneficiariesCtrl = TextEditingController(text: existing?.beneficiariesCount?.toString() ?? '');
  var category = existing?.category ?? DonationCategory.general;
  var currency = existing?.currency ?? 'USD';
  var imageUrls = List<String>.from(existing?.imageUrls ?? const []);
  var videoUrl = existing?.videoUrl;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.bgElevated,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) {
      var uploadingImages = false;
      var uploadingVideo = false;
      var drafting = false;
      var saving = false;
      return StatefulBuilder(builder: (ctx, setSheetState) {
        Future<void> pickImages() async {
          final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
          if (picked.isEmpty) return;
          setSheetState(() => uploadingImages = true);
          try {
            for (final f in picked) {
              final url = await app.uploadDonationImage(File(f.path));
              imageUrls.add(url);
            }
          } catch (_) {
            if (context.mounted) showHzToast(context, 'آپلود عکس ناموفق بود.');
          } finally {
            setSheetState(() => uploadingImages = false);
          }
        }

        Future<void> pickVideo() async {
          final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
          if (picked == null) return;
          setSheetState(() => uploadingVideo = true);
          try {
            videoUrl = await app.uploadDonationVideoFile(File(picked.path));
          } catch (_) {
            if (context.mounted) showHzToast(context, 'آپلود ویدیو ناموفق بود.');
          } finally {
            setSheetState(() => uploadingVideo = false);
          }
        }

        Future<void> draftWithAi() async {
          if (rawNotesCtrl.text.trim().isEmpty) {
            showHzToast(context, 'اول نکات/واقعیت‌های خام گزارش را بنویسید.');
            return;
          }
          setSheetState(() => drafting = true);
          try {
            final draft = await ai.draftDonationReport(
              categoryLabel: donationCategoryLabel(category),
              rawNotes: rawNotesCtrl.text.trim(),
              title: titleCtrl.text.trim(),
              amountSpent: double.tryParse(amountCtrl.text.trim()),
              currency: currency,
              location: locationCtrl.text.trim(),
              beneficiariesCount: int.tryParse(beneficiariesCtrl.text.trim()),
            );
            setSheetState(() {
              titleCtrl.text = draft.title;
              summaryCtrl.text = draft.summary;
              bodyCtrl.text = draft.body;
            });
          } on AiServiceException catch (e) {
            if (context.mounted) showHzToast(context, e.message);
          } catch (_) {
            if (context.mounted) showHzToast(context, 'نگارش با هوش مصنوعی ناموفق بود.');
          } finally {
            setSheetState(() => drafting = false);
          }
        }

        Future<void> save() async {
          if (titleCtrl.text.trim().isEmpty || summaryCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) {
            showHzToast(context, 'عنوان، خلاصه و متن گزارش را کامل کنید (یا اول با هوش مصنوعی بنویسید).');
            return;
          }
          setSheetState(() => saving = true);
          try {
            if (existing != null) {
              await app.updateDonationReport(
                existing.id,
                title: titleCtrl.text.trim(),
                category: category,
                summary: summaryCtrl.text.trim(),
                body: bodyCtrl.text.trim(),
                amountSpent: double.tryParse(amountCtrl.text.trim()),
                currency: currency,
                imageUrls: imageUrls,
                videoUrl: videoUrl,
                location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                beneficiariesCount: int.tryParse(beneficiariesCtrl.text.trim()),
              );
            } else {
              await app.publishDonationReport(
                title: titleCtrl.text.trim(),
                category: category,
                summary: summaryCtrl.text.trim(),
                body: bodyCtrl.text.trim(),
                amountSpent: double.tryParse(amountCtrl.text.trim()),
                currency: currency,
                imageUrls: imageUrls,
                videoUrl: videoUrl,
                location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                beneficiariesCount: int.tryParse(beneficiariesCtrl.text.trim()),
              );
            }
            if (ctx.mounted) Navigator.of(ctx).pop();
            await onRefresh();
            if (context.mounted) showHzToast(context, existing != null ? 'گزارش ویرایش شد.' : 'گزارش منتشر شد.');
          } catch (_) {
            if (context.mounted) showHzToast(context, 'ذخیره ناموفق بود؛ دوباره تلاش کنید.');
          } finally {
            setSheetState(() => saving = false);
          }
        }

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(existing != null ? 'ویرایش گزارش شفافیت' : 'گزارش شفافیت تازه', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const FlagStripe(width: 46),
              const SizedBox(height: 16),
              _label(theme, 'دسته‌بندی'),
              HzSelectField(
                value: donationCategoryLabel(category),
                icon: Icons.category_outlined,
                hint: 'دسته‌بندی',
                options: DonationCategory.values.map(donationCategoryLabel).toList(),
                theme: theme,
                onChanged: (v) => setSheetState(() => category = DonationCategory.values.firstWhere((c) => donationCategoryLabel(c) == v, orElse: () => DonationCategory.general)),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.aiViolet.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: theme.aiViolet.withValues(alpha: 0.3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.auto_awesome, size: 15, color: theme.aiViolet),
                    const SizedBox(width: 6),
                    Expanded(child: Text('نکات خام را بنویسید — هوش مصنوعی گزارش نهایی را می‌سازد', style: TextStyle(color: theme.textPrimary, fontSize: 11, fontWeight: FontWeight.w800))),
                  ]),
                  const SizedBox(height: 8),
                  _field(theme, rawNotesCtrl, hint: 'مثلاً: با این مبلغ ۵۰ کیسه آرد و روغن برای خانواده‌های بی‌بضاعت روستای… خریداری و توزیع شد…', maxLines: 4),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: drafting ? null : draftWithAi,
                      icon: drafting ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.aiViolet)) : const Icon(Icons.auto_awesome, size: 15),
                      label: Text(drafting ? 'در حال نگارش…' : 'نوشتن با هوش مصنوعی', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(foregroundColor: theme.aiViolet, side: BorderSide(color: theme.aiViolet.withValues(alpha: 0.5)), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              _label(theme, 'عنوان گزارش'),
              _field(theme, titleCtrl, hint: 'عنوان کوتاه و صادقانه'),
              const SizedBox(height: 12),
              _label(theme, 'خلاصه‌ی کوتاه (برای کارت فهرست)'),
              _field(theme, summaryCtrl, hint: 'یک جمله', maxLines: 2),
              const SizedBox(height: 12),
              _label(theme, 'متن کامل گزارش'),
              _field(theme, bodyCtrl, hint: 'گزارش کامل…', maxLines: 6),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label(theme, 'مبلغ مصرف‌شده (اختیاری)'),
                    _field(theme, amountCtrl, hint: '۰', keyboardType: TextInputType.number),
                  ]),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _label(theme, 'واحد پول'),
                    HzSelectField(value: currency, icon: Icons.attach_money, hint: 'واحد', options: kDonationCurrencies, theme: theme, onChanged: (v) => setSheetState(() => currency = v ?? 'USD')),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              _label(theme, 'محل (اختیاری)'),
              _field(theme, locationCtrl, hint: 'مثلاً: دایکندی'),
              const SizedBox(height: 12),
              _label(theme, 'تعداد خانواده/افراد کمک‌شده (اختیاری)'),
              _field(theme, beneficiariesCtrl, hint: '۰', keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _label(theme, 'عکس‌های مستند'),
              if (imageUrls.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final url in imageUrls)
                      Stack(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(url, width: 64, height: 64, fit: BoxFit.cover)),
                        Positioned(
                          top: -6, left: -6,
                          child: InkWell(
                            onTap: () => setSheetState(() => imageUrls.remove(url)),
                            child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: theme.danger, shape: BoxShape.circle), child: const Icon(Icons.close, size: 12, color: Colors.white)),
                          ),
                        ),
                      ]),
                  ]),
                ),
              OutlinedButton.icon(
                onPressed: uploadingImages ? null : pickImages,
                icon: uploadingImages ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_photo_alternate_outlined, size: 16),
                label: Text(uploadingImages ? 'در حال آپلود…' : 'افزودن عکس از گالری', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(foregroundColor: theme.success, side: BorderSide(color: theme.border), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              _label(theme, 'ویدیوی مستند (اختیاری)'),
              if (videoUrl != null && videoUrl!.isNotEmpty)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(videoUrl!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.success, fontSize: 10.5))),
              OutlinedButton.icon(
                onPressed: uploadingVideo ? null : pickVideo,
                icon: uploadingVideo ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.videocam_outlined, size: 16),
                label: Text(uploadingVideo ? 'در حال آپلود…' : 'افزودن ویدیو از گالری', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(foregroundColor: theme.success, side: BorderSide(color: theme.border), padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: saving ? null : save,
                    style: ElevatedButton.styleFrom(backgroundColor: theme.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(existing != null ? 'ذخیره' : 'انتشار گزارش', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(foregroundColor: theme.textSecondary, side: BorderSide(color: theme.border), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('انصراف', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ]),
          ),
        );
      });
    },
  );
}

Widget _label(AppColors theme, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
    );

Widget _field(AppColors theme, TextEditingController ctrl, {String hint = '', int maxLines = 1, TextInputType? keyboardType}) {
  return TextField(
    controller: ctrl,
    maxLines: maxLines,
    keyboardType: keyboardType,
    style: TextStyle(color: theme.textPrimary, fontSize: 12.5),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: theme.textFaint, fontSize: 11.5),
      filled: true, fillColor: theme.bgCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.border)),
    ),
  );
}

// =============================================================================
// تب تنظیمات و آمار
// =============================================================================

class _SettingsStatsTab extends StatefulWidget {
  final AppColors theme;
  final AppState app;
  const _SettingsStatsTab({required this.theme, required this.app});

  @override
  State<_SettingsStatsTab> createState() => _SettingsStatsTabState();
}

class _SettingsStatsTabState extends State<_SettingsStatsTab> {
  late final TextEditingController _totalCtrl;
  late final TextEditingController _familiesCtrl;
  late final TextEditingController _projectsCtrl;
  late String _currency;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.app.donationSettings;
    _totalCtrl = TextEditingController(text: s.totalRaised.toStringAsFixed(0));
    _familiesCtrl = TextEditingController(text: s.familiesHelped.toString());
    _projectsCtrl = TextEditingController(text: s.projectsCompleted.toString());
    _currency = s.currency;
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _familiesCtrl.dispose();
    _projectsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.app.updateDonationSettings(
        totalRaised: double.tryParse(_totalCtrl.text.trim()) ?? 0,
        currency: _currency,
        familiesHelped: int.tryParse(_familiesCtrl.text.trim()) ?? 0,
        projectsCompleted: int.tryParse(_projectsCtrl.text.trim()) ?? 0,
      );
      if (mounted) showHzToast(context, 'آمار کمپین ذخیره شد.');
    } catch (_) {
      if (mounted) showHzToast(context, 'ذخیره ناموفق بود؛ دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [theme.success.withValues(alpha: 0.16), theme.aiTeal.withValues(alpha: 0.08)], begin: Alignment.centerRight, end: Alignment.centerLeft),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.success.withValues(alpha: 0.3)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 15, color: theme.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'چون پرداخت PayPal مستقیم به این اپ وصل نیست، این عددها را با جمع دستیِ پی‌پال + حواله‌های تأییدشده، خودتان به‌روز نگه دارید. این آمار در کارت خانه و صفحه‌ی کمک‌های مالی به کاربران نشان داده می‌شود.',
                style: TextStyle(color: theme.textPrimary, fontSize: 11, height: 1.8, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label(theme, 'مجموع جمع‌آوری‌شده'),
              _field(theme, _totalCtrl, hint: '۰', keyboardType: TextInputType.number),
            ]),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label(theme, 'واحد پول'),
              HzSelectField(value: _currency, icon: Icons.attach_money, hint: 'واحد', options: kDonationCurrencies, theme: theme, onChanged: (v) => setState(() => _currency = v ?? 'USD')),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        _label(theme, 'تعداد خانواده‌های کمک‌شده'),
        _field(theme, _familiesCtrl, hint: '۰', keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        _label(theme, 'تعداد پروژه‌های تکمیل‌شده (شفاخانه/مکتب/پل/سرک)'),
        _field(theme, _projectsCtrl, hint: '۰', keyboardType: TextInputType.number),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined, size: 16),
          label: Text(_saving ? 'در حال ذخیره…' : 'ذخیره‌ی آمار', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: theme.success, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ],
    );
  }
}
