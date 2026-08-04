/// ابزار تبدیل تاریخ میلادی به تاریخ رسمی افغانستان (هجری خورشیدی) با نام
/// ماه‌های افغانی (حمل تا حوت) — بدون وابستگی به هیچ پکیج بیرونی، تا از
/// ریسک ناسازگاری نسخه جلوگیری شود. همه‌ی برچسب‌های تاریخ/زمان واقعی در
/// برنامه (پست‌ها، کامنت‌ها، پیام‌ها، ویدیوها) از همین فایل عبور می‌کنند.
library;

const List<String> kAfghanMonths = [
  'حمل', 'ثور', 'جوزا', 'سرطان', 'اسد', 'سنبله',
  'میزان', 'عقرب', 'قوس', 'جدی', 'دلو', 'حوت',
];

class AfghanDate {
  final int year;
  final int month; // ۱ تا ۱۲
  final int day;
  const AfghanDate(this.year, this.month, this.day);

  String get monthName => kAfghanMonths[month - 1];
}

/// تبدیل تاریخ میلادی به تاریخ خورشیدی افغانستان، با الگوریتم استاندارد
/// تبدیل ژولین (همان الگوریتمی که در بیشتر کتابخانه‌های تقویم جلالی/شمسی
/// استفاده می‌شود). صحت آن با چند رویداد شناخته‌شده‌ی تاریخی راستی‌آزمایی
/// شده است (مثلاً ۸ مه ۲۰۲۱ ⇦ ۱۸ ثور ۱۴۰۰).
AfghanDate gregorianToAfghan(DateTime g) {
  final gy = g.year, gm = g.month, gd = g.day;
  const gDaysInMonth = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy2 = gm > 2 ? gy + 1 : gy;
  int jdn = 355666 +
      (365 * gy) +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) +
      gd +
      gDaysInMonth[gm - 1];
  int jy = -1595 + (33 * (jdn ~/ 12053));
  jdn %= 12053;
  jy += 4 * (jdn ~/ 1461);
  jdn %= 1461;
  if (jdn > 365) {
    jy += (jdn - 1) ~/ 365;
    jdn = (jdn - 1) % 365;
  }
  int jm, jd;
  if (jdn < 186) {
    jm = 1 + (jdn ~/ 31);
    jd = 1 + (jdn % 31);
  } else {
    jm = 7 + ((jdn - 186) ~/ 30);
    jd = 1 + ((jdn - 186) % 30);
  }
  return AfghanDate(jy, jm, jd);
}

const List<String> _faDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

/// تبدیل هر رشته‌ی حاوی رقم لاتین به ارقام فارسی/دری (مثلاً «2024» ⇦ «۲۰۲۴»).
String toFaDigits(Object n) {
  return n.toString().split('').map((c) {
    final d = int.tryParse(c);
    return d == null ? c : _faDigits[d];
  }).join();
}

/// برچسب کامل تاریخ خورشیدی افغانستان، مثل «۱۸ ثور ۱۴۰۰».
String afghanDateLabel(DateTime g) {
  final a = gregorianToAfghan(g);
  return '${toFaDigits(a.day)} ${a.monthName} ${toFaDigits(a.year)}';
}

/// برچسب عددی و فشرده‌ی تاریخ خورشیدی افغانستان، مثل «۱۴۰۰/۰۲/۱۸».
String afghanDateLabelShort(DateTime g) {
  final a = gregorianToAfghan(g);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${toFaDigits(a.year)}/${toFaDigits(two(a.month))}/${toFaDigits(two(a.day))}';
}
