import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'features/auth/welcome_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/sections/section_detail_screen.dart';
import 'features/community/post_widgets.dart';
import 'core/app_logo.dart';

class HazaranamaApp extends StatelessWidget {
  const HazaranamaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'هزاره‌نامه',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => _WebFrame(
        child: Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox()),
      ),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Vazirmatn', // اگر فونت را اضافه نکردید، فلاتر خودکار به فونت پیش‌فرض برمی‌گردد
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E5FA8)),
        // گذار نرم و مدرن میان صفحه‌ها
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        }),
      ),
      onGenerateRoute: (settings) {
        if (settings.name == '/section') {
          final sectionId = settings.arguments as String;
          return MaterialPageRoute(builder: (_) => SectionDetailScreen(sectionId: sectionId));
        }
        if (settings.name == '/post') {
          final postId = settings.arguments as String;
          return MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId));
        }
        return null;
      },
      home: const _AuthGate(),
    );
  }
}

/// بر اساس AuthStage در AppState، صفحه‌ی درست را نشان می‌دهد —
/// معادل ماشین‌حالت stage در HazaranamaWithAuth در دموی وب.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final stage = context.watch<AppState>().stage;
    // جابه‌جایی میان خوش‌آمد، ورود، ثبت‌نام و خودِ اپ با محوشدن و بزرگ‌نمایی نرم
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween<double>(begin: 0.97, end: 1).animate(anim), child: child),
      ),
      child: KeyedSubtree(key: ValueKey(stage), child: _screenFor(stage)),
    );
  }

  Widget _screenFor(AuthStage stage) {
    switch (stage) {
      case AuthStage.checking:
        return const _CheckingScreen();
      case AuthStage.welcome:
        return const WelcomeScreen();
      case AuthStage.login:
        return const LoginScreen();
      case AuthStage.register:
        return const RegisterScreen();
      case AuthStage.forgot:
        return const ForgotPasswordScreen();
      case AuthStage.resetPassword:
        return const ResetPasswordScreen();
      case AuthStage.app:
        return const MainShell();
    }
  }
}

class _CheckingScreen extends StatelessWidget {
  const _CheckingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().colors;
    return Scaffold(
      backgroundColor: theme.bg,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AnimatedAppLogo(size: 84),
          const SizedBox(height: 18),
          Text('در حال بارگذاری…', style: TextStyle(color: theme.textFaint, fontSize: 12))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 700.ms)
              .then()
              .fade(begin: 1, end: 0.4, duration: 700.ms),
        ]),
      ),
    );
  }
}


/// در نسخه‌ی وب روی نمایشگرهای عریض (دسکتاپ)، اپ که برای موبایل طراحی شده
/// در یک ستون وسط با عرض گوشی نمایش داده می‌شود تا دکمه‌ها و کارت‌ها به
/// پهنای کل صفحه کشیده نشوند. MediaQuery هم بازنویسی می‌شود تا ویجت‌هایی
/// که اندازه‌ی صفحه را می‌خوانند، عرض واقعیِ ستون را ببینند.
class _WebFrame extends StatelessWidget {
  final Widget child;
  const _WebFrame({required this.child});

  static const double _maxWidth = 520;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    final mq = MediaQuery.of(context);
    if (mq.size.width <= _maxWidth + 80) return child;
    final theme = context.watch<AppState>().colors;
    return ColoredBox(
      color: Color.lerp(theme.bg, Colors.black, 0.35)!,
      child: Center(
        child: Container(
          width: _maxWidth,
          height: mq.size.height,
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 40)],
          ),
          clipBehavior: Clip.hardEdge,
          child: MediaQuery(
            data: mq.copyWith(size: Size(_maxWidth, mq.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
