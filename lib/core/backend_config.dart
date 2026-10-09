/// اطلاعات اتصال به بک‌اند هزاره‌نامه روی Cloudflare.
///
/// همه‌چیز (حساب کاربری، پایگاه‌داده D1، فایل‌ها در R2، دستیار هوشمند Workers AI)
/// از طریق یک Worker با نشانی زیر سرویس داده می‌شود؛ هیچ کلید مخفی‌ای داخل اپ نیست —
/// امنیت با نشست JWT هر کاربر و قوانین دسترسیِ سمت سرور تأمین می‌شود.
/// کد سرور: پوشه‌ی cloudflare/api در همین مخزن.
class BackendConfig {
  /// نشانی Worker (می‌توان بعداً یک دامنه‌ی اختصاصی مثل api.example.org جایگزینش کرد).
  static const String apiUrl = String.fromEnvironment(
    'HZ_API_URL',
    defaultValue: 'https://hazaranama-api.alireza-necdo.workers.dev',
  );

  /// نام «سطل» فایل‌های عکس پروفایل.
  static const String avatarsBucket = 'avatars';

  /// دیگر استفاده نمی‌شود (بازیابی رمز با کد مدیر انجام می‌شود)؛ برای سازگاری نگه داشته شده.
  static const String passwordResetRedirect = 'hazaranama://reset-callback';
}
