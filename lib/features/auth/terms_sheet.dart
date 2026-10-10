import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_logo.dart';
import '../../core/widgets.dart';

const String kTermsText = '''
۱. هدف هزاره‌نامه
هزاره‌نامه یک مرجع دیجیتال برای شناخت، حفظ و گرامی‌داشت تاریخ، فرهنگ و زندگی مردم هزاره است. با ساخت حساب، می‌پذیرید که از این فضا برای همین هدف استفاده کنید.

۲. حافظه‌ی جمعی و محتوای کاربران
هر روایت، خاطره، نظر یا واکنشی که در بخش «حافظه‌ی جمعی» می‌گذارید، عمومی و برای دیگر کاربران قابل مشاهده است. لطفاً از انتشار محتوای توهین‌آمیز، نادرست یا ناقض حقوق دیگران خودداری کنید. مدیر هزاره‌نامه حق حذف محتوای نامناسب و مسدودسازی حساب‌های متخلف را دارد.

۳. اطلاعات ریشه و هویت
بخش «ریشه‌های شما» (کشور، ولایت، ولسوالی، طایفه) اختیاری است و صرفاً برای نگاشت پراکندگی جهانی هزاره‌ها استفاده می‌شود؛ می‌توانید هر زمان آن را از تنظیمات حساب ویرایش یا خالی بگذارید.

۴. حریم خصوصی
ایمیل شما فقط برای ورود و ارتباط ضروری (مثل بازیابی رمز) استفاده می‌شود و در معرض عموم قرار نمی‌گیرد. نام و اطلاعات ریشه‌ی شما ممکن است در بخش‌های عمومی (مثل حافظه‌ی جمعی) به نمایش برسد.

۵. تماس با ما
پیام‌هایی که از طریق «تماس با ما» می‌فرستید، مستقیماً برای مدیر هزاره‌نامه ارسال و ذخیره می‌شود تا بتواند پاسخ دهد.

۶. تغییرات
این شرایط ممکن است در آینده به‌روزرسانی شود؛ ادامه‌ی استفاده از اپ به‌معنای پذیرش نسخه‌ی تازه خواهد بود.
''';

Future<bool?> showTermsSheet(BuildContext context, AppColors theme) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TermsSheetContent(theme: theme),
  );
}

class _TermsSheetContent extends StatelessWidget {
  final AppColors theme;
  const _TermsSheetContent({required this.theme});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.bgElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(children: [
            const SizedBox(height: 10),
            Container(width: 42, height: 5, decoration: BoxDecoration(color: theme.border, borderRadius: BorderRadius.circular(999)))
                .animate().fadeIn(duration: 250.ms),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
              child: Row(children: [
                HzBadge(theme: theme, size: 40, filled: true, child: const Icon(Icons.gavel_outlined, color: Colors.white, size: 17)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('شرایط و قوانین هزاره‌نامه', style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    const FlagStripe(width: 44),
                  ]),
                ),
              ]),
            ).animate(delay: 60.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
                children: [
                  Text(kTermsText, style: TextStyle(color: theme.textSecondary, fontSize: 12.5, height: 2)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => openContentUrl(context, 'https://hazaranama.pages.dev/privacy/'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.open_in_new, size: 13, color: theme.blue),
                        const SizedBox(width: 6),
                        Text('مشاهده‌ی کامل سیاست حریم خصوصی و حذف حساب', style: TextStyle(color: theme.blue, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
              child: HzPrimaryButton(
                theme: theme,
                label: 'خواندم و می‌پذیرم',
                icon: Icons.check_circle_outline,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ]),
        );
      },
    );
  }
}
