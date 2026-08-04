/// اطلاعات اتصال پروژه‌ی Supabase شما.
///
/// -----------------------------------------------------------------------
/// نکته‌ی مهم — سیستم تازه‌ی کلیدهای Supabase (۲۰۲۵-۲۰۲۶):
/// Supabase کلیدهای قدیمی JWT (anon / service_role) را با دو نوع کلید تازه
/// جایگزین کرده:
///   • Publishable key  (شروع می‌شود با sb_publishable_...)
///     جایگزین anon key قدیمی — همان دسترسی محدود و همان رفتار RLS را دارد.
///     کاملاً امن است که در اپ موبایل/مرورگر قرار بگیرد و عمومی دیده شود.
///   • Secret key       (شروع می‌شود با sb_secret_...)
///     جایگزین service_role key قدیمی — دسترسی کامل و بدون محدودیت RLS دارد
///     (BYPASSRLS). این کلید هرگز، به هیچ شکل، نباید داخل اپ موبایل/کد
///     کلاینت قرار بگیرد — فقط در سمت سرور (Edge Function، بک‌اند) استفاده
///     می‌شود. در همین پروژه‌ی فلاتر، به‌طور کلی نیازی به این کلید نداریم.
///
/// این دو مقدار را از داشبورد Supabase بردارید:
///   Project Settings → API → Project URL
///   Project Settings → API Keys → Publishable key (نام «default»)
/// -----------------------------------------------------------------------
class SupabaseConfig {
  static const String url = 'https://kyvkqbdigezzywfarhtj.supabase.co';

  /// کلید Publishable — همان چیزی که در سیستم قدیمی «anon key» نامیده می‌شد.
  static const String publishableKey = 'sb_publishable_lzF1wMI5cOYttNydc5eO_Q_mZceilTB';

  /// نام باکت Storage برای عکس‌های پروفایل (باید در داشبورد ساخته شود)
  static const String avatarsBucket = 'avatars';

  /// پیوند بازگشتی بازیابی رمز عبور — وقتی Supabase ایمیل بازیابی می‌فرستد،
  /// این آدرس در پیوند جاسازی می‌شود تا کلیک روی آن به‌جای مرورگر، مستقیم
  /// خودِ اپ را (با یک نشست موقتِ بازیابی) باز کند. باید این آدرس دقیقاً هم
  /// در AndroidManifest.xml/Info.plist (scheme+host) و هم در داشبورد
  /// Supabase → Authentication → URL Configuration → Redirect URLs ثبت شود.
  static const String passwordResetRedirect = 'hazaranama://reset-callback';
}
