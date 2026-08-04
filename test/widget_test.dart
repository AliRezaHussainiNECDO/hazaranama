// تست اسموک ساده — نسخه‌ی پیش‌فرض فلاتر (که به یک ویجت شمارنده‌ی ناموجود
// به نام MyApp اشاره می‌کرد) با یک تست واقعی برای این پروژه جایگزین شد.
//
// تست کامل HazaranamaApp نیاز به مقداردهی اولیه‌ی Supabase و فراهم‌کردن
// AppState از طریق Provider دارد (دقیقاً مثل main.dart)؛ برای یک تست
// اسموک سبک و بدون وابستگی به شبکه، همینجا فقط یکی از ویجت‌های پایه‌ی
// مشترک اپ (FlagStripe) را رندر و بررسی می‌کنیم.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazaranama/core/widgets.dart';

void main() {
  testWidgets('FlagStripe بدون خطا رندر می‌شود', (WidgetTester tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(home: Scaffold(body: Center(child: FlagStripe(width: 60)))),
      ),
    );

    expect(find.byType(FlagStripe), findsOneWidget);
  });
}
