import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/hz_backend.dart';
import 'services/push_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // اتصال به بک‌اند هزاره‌نامه روی Cloudflare (نشست ذخیره‌شده‌ی قبلی هم بازیابی می‌شود)
  await HzBackend.initialize();

  // اگر فایل‌های تنظیمات Firebase (google-services.json / GoogleService-Info.plist)
  // هنوز در پروژه نباشند، initialize شکست می‌خورد — اپ باید بدون پوش واقعی هم
  // بالا بیاید (فقط اعلان درون‌اپی کار می‌کند).
  try {
    await PushService.initialize();
  } catch (_) {}

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const HazaranamaApp(),
    ),
  );
}
