import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// این تابع باید top-level (بیرون از هر کلاس) و با همین امضا بماند —
/// Firebase وقتی اپ کاملاً بسته یا در پس‌زمینه است، همین تابع را در یک
/// Isolate جدا صدا می‌زند. خودِ سیستم‌عامل پیام را در نوار اعلان‌ها نشان
/// می‌دهد؛ اینجا فقط جای گسترش‌های بعدی (مثلاً ذخیره‌ی محلی) نگه داشته شده.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// وضعیت ساده‌شده‌ی اجازه‌ی اعلان — بقیه‌ی اپ (مثل AppState) لازم نیست چیزی
/// از Firebase بشناسد، فقط همین سه حالت را می‌بیند.
enum PushPermissionState {
  /// هنوز از کاربر پرسیده نشده — جای مناسب برای نشان دادن توضیح دوستانه.
  notDetermined,

  /// کاربر قبلاً اجازه داده (کامل یا موقت).
  authorized,

  /// کاربر قبلاً رد کرده — دیگر نباید مزاحمش شد.
  denied,
}

/// اتصال اپ به Firebase Cloud Messaging برای پوش نوتیفیکیشن واقعی — حتی
/// وقتی اپ بسته یا در پس‌زمینه است. جدا از سیستم اعلان درون‌اپیِ Realtime
/// (که فقط وقتی اپ باز است کار می‌کند)، این همان توکنی است که سرور
/// (Edge Function روی Supabase) با آن پیام را مستقیم به گوشی کاربر می‌فرستد.
class PushService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _initialized = true;
  }

  /// بدون نمایش هیچ پنجره‌ای، فقط وضعیت فعلی اجازه‌ی اعلان را برمی‌گرداند —
  /// برای این‌که بفهمیم آیا باید پیش از درخواست رسمی، توضیح دوستانه نشان
  /// بدهیم یا کاربر قبلاً تصمیمش را گرفته (قبول/رد کرده).
  static Future<PushPermissionState> getPermissionState() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
        case AuthorizationStatus.provisional:
          return PushPermissionState.authorized;
        case AuthorizationStatus.denied:
          return PushPermissionState.denied;
        case AuthorizationStatus.notDetermined:
          return PushPermissionState.notDetermined;
      }
    } catch (_) {
      return PushPermissionState.notDetermined;
    }
  }

  /// اجازه‌ی نمایش اعلان را از کاربر می‌گیرد (در iOS اجباری، در اندروید ۱۳+
  /// هم لازم است) و در صورت تأیید، توکن دستگاه را برمی‌گرداند.
  static Future<String?> requestPermissionAndGetToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return null;
      return await messaging.getToken();
    } catch (_) {
      // در دستگاه/شبیه‌ساز بدون Google Play Services، getToken شکست می‌خورد؛
      // اپ باید بدون پوش واقعی هم عادی کار کند (اعلان درون‌اپی دست‌نخورده می‌ماند).
      return null;
    }
  }

  static Stream<String> get onTokenRefresh => FirebaseMessaging.instance.onTokenRefresh;
}
