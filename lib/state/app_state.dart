import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:http/http.dart' show ClientException;
import '../services/hz_backend.dart' show AuthChangeEvent, AuthException, AuthState, PostgrestException;
import '../core/app_colors.dart';
import '../core/donor_tiers.dart';
import '../core/section_style.dart' show kHazaragiGlossaryCount;
import '../models/models.dart';
import '../services/push_service.dart';
import '../services/backend_service.dart';

enum AuthStage { checking, welcome, login, register, forgot, resetPassword, app }

/// وضعیت سراسری برنامه — حالا هر خواندن/نوشتنی واقعاً از سرور هزاره‌نامه (Cloudflare) می‌آید.
/// شکل بیرونی این کلاس (فیلدها و اسم متدها) عمداً همان چیزی مانده که
/// صفحات UI از قبل با آن کار می‌کردند؛ فقط داخلش به‌جای دیتای mock،
/// به BackendService وصل شده است.
class AppState extends ChangeNotifier {
  final BackendService _service = BackendService();

  AuthStage stage = AuthStage.checking;
  bool isDark = true;

  UserProfile? currentUser;
  bool adminPreviewAsUser = false;

  String? avatarPath;
  String displayName = '';

  Map<String, List<ContentItem>> content = {};
  List<UserProfile> users = [];
  List<Post> posts = [];
  bool postsLoadingMore = false;
  bool postsHasMore = true;
  List<ContactMessage> myMessages = [];
  List<ContactMessage> allMessages = []; // فقط مدیر
  List<Artist> artists = []; // گالری هنرمندان موسیقی و شعر
  List<ArticleSubmission> myArticles = []; // مقالات ارسالی خودِ کاربر در مسابقه
  List<ArticleSubmission> allArticleSubmissions = []; // همه‌ی مقالات — فقط مدیر
  List<FeaturedArticle> featuredArticles = []; // برگزیدگان منتشرشده‌ی مسابقه
  ContestSettings contestSettings = ContestSettings(topic: 'در حال بارگذاری موضوع مسابقه…'); // موضوع مشترک + جوایز
  List<DonationTransfer> myDonationTransfers = []; // حواله‌های ارسالی خودِ کاربر
  List<DonationTransfer> allDonationTransfers = []; // همه‌ی حواله‌ها — فقط مدیر
  List<DonationReport> donationReports = []; // گزارش‌های شفافیت — عمومی
  DonationSettings donationSettings = DonationSettings(); // آمار کلی کمپین
  List<DonorRankEntry> donorLeaderboard = []; // فهرست عمومی کمک‌کنندگان
  final Map<String, UserRole> _roleById = {}; // کش سبک نقش همه‌ی کاربران — برای حلقه‌ی مقام در فید/کامنت/مقاله/پیام
  List<UserActivityEntry> recentActivity = []; // آخرین فعالیت‌های همه‌ی کاربران — صفحه‌ی نخست پنل مدیریت
  List<BlockedUser> blockedUsers = []; // کاربرانی که خودِ کاربر مسدود کرده — پست/کامنتشان را نمی‌بیند
  List<ContentReport> contentReports = []; // فقط مدیر — گزارش‌های محتوا/کاربر برای بررسی
  int todayVisitCount = 0; // شمار واقعی نشست‌های امروز — کارت «بازدید امروز»
  List<double> visitTrend = []; // شمار بازدید ۷ روز گذشته — نمودار ریز همان کارت

  // ================= اعلان‌های درون‌اپی =================
  List<AppNotification> notifications = [];
  AppNotification? incomingToast; // آخرین اعلانی که همین الان از Realtime رسیده — برای نمایش بنر پویا
  NotificationSubscription? _notificationsChannel;
  String? _pushToken; // توکن فعلی FCM این دستگاه — برای پاک‌سازی هنگام خروج
  StreamSubscription<String>? _pushTokenRefreshSub;
  String? _pendingPushUserId; // کاربری که منتظر تصمیمش درباره‌ی اجازه‌ی اعلان هستیم

  /// وقتی true است یعنی هنوز از کاربر درباره‌ی اجازه‌ی اعلان پرسیده نشده —
  /// UI باید کارت توضیح دوستانه را نشان بدهد (پیش از پنجره‌ی رسمی سیستم‌عامل).
  bool showNotificationPermissionSheet = false;

  int get unreadNotificationCount => notifications.where((n) => !n.isRead).length;

  /// جمعِ دلاریِ تقریبیِ کمک‌های تأییدشده‌ی خودِ کاربر — پایه‌ی مقام و حلقه‌ی
  /// دور عکس پروفایل (به‌روزرسانی می‌شود چون myDonationTransfers هنگام ورود
  /// و بعد از هر اعلام کمک تازه بارگذاری/به‌روز می‌شود).
  double get myDonationTotalUsd => myDonationTransfers
      .where((t) => t.status == DonationTransferStatus.confirmed)
      .fold(0.0, (s, t) => s + (t.confirmedAmount ?? t.amount) * usdRateFor(t.currency));

  AppColors get colors => isDark ? AppColors.dark : AppColors.light;

  AppState() {
    _service.authChanges.listen((AuthState data) {
      // وقتی کاربر روی پیوند «بازیابی رمز عبور» ایمیل‌شده کلیک می‌کند و اپ از
      // طریق کد بازیابی وارد می‌شود، سرور یک نشست موقتِ بازیابی می‌سازد و
      // دقیقاً همین رویداد را می‌فرستد — این‌جا کاربر را به صفحه‌ی «تنظیم رمز
      // تازه» می‌بریم (نه صفحه‌ی اصلی اپ، چون هنوز رمز تازه تنظیم نشده).
      if (data.event == AuthChangeEvent.passwordRecovery) {
        stage = AuthStage.resetPassword;
        notifyListeners();
      }
    });
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_service.authUser != null) {
      await _loadSessionUser();
    } else {
      stage = AuthStage.welcome;
      notifyListeners();
    }
  }

  Future<void> _loadSessionUser() async {
    final authUser = _service.authUser;
    if (authUser == null) {
      stage = AuthStage.welcome;
      notifyListeners();
      return;
    }
    try {
      startupError = null;
      currentUser = await _service.fetchProfile(authUser.id);
      displayName = currentUser!.name;
      avatarPath = currentUser!.avatarPath;
      content = await _service.fetchAllContent();
      posts = await _service.fetchPosts(authUser.id);
      postsHasMore = posts.length >= 15;
      artists = await _service.fetchArtists();
      myDonationTransfers = await _service.fetchMyDonationTransfers(authUser.id);
      if (currentUser!.role == UserRole.admin) {
        users = await _service.fetchAllProfiles();
      }
      stage = AuthStage.app;
      // شمارنده‌ی «بازدید امروز» — یک بار در هر نشست، بدون این‌که جلوی ورود را بگیرد
      unawaited(_service.incrementDailyVisit().catchError((_) {}));
      unawaited(_initNotifications());
      unawaited(_maybeAskNotificationPermission(authUser.id));
      // نقش‌ی همه‌ی کاربران + فهرست کمک‌کنندگان — برای هر کاربری (نه فقط مدیر)
      // تا حلقه‌ی مقام درست دور عکس پروفایل بقیه‌ی کاربران هم در فید، کامنت‌ها،
      // مقاله و پیام‌ها نمایش داده شود؛ خطای احتمالی نباید جلوی ورود را بگیرد.
      unawaited(_loadRoleAndDonorCaches());
      unawaited(loadBlockedUsers());
    } catch (e) {
      if (_isTransientError(e)) {
        // اینترنت یا سرور موقتاً در دسترس نیست: کاربر را بیرون نینداز؛
        // صفحه‌ی بارگذاری پیام و دکمه‌ی «تلاش دوباره» نشان می‌دهد.
        startupError = 'اتصال به سرور برقرار نشد. اینترنت را بررسی کنید و دوباره تلاش کنید.';
        stage = AuthStage.checking;
        notifyListeners();
        return;
      }
      // نشست نامعتبر یا پروفایل حذف‌شده؛ کاربر را دوباره به ورود برگردان
      await _service.signOut();
      stage = AuthStage.welcome;
    }
    notifyListeners();
  }

  /// پیام خطای راه‌اندازی (قطعی اینترنت/سرور) — صفحه‌ی بارگذاری نشانش می‌دهد.
  String? startupError;

  Future<void> retryStartup() async {
    startupError = null;
    notifyListeners();
    await _loadSessionUser();
  }

  bool _isTransientError(Object e) {
    if (e is TimeoutException || e is ClientException) return true;
    final m = e.toString();
    if (e is PostgrestException) return m.startsWith('خطای سرور (5');
    return m.contains('SocketException') || m.contains('Failed host lookup') || m.contains('XMLHttpRequest') || m.contains('Connection');
  }

  void toggleTheme() {
    isDark = !isDark;
    notifyListeners();
  }

  void goTo(AuthStage s) {
    stage = s;
    notifyListeners();
  }

  // ================= AUTH =================

  /// ورود با ایمیل/رمز. در صورت خطا پیام فارسی برمی‌گرداند، در صورت موفقیت null.
  Future<String?> signIn({required String email, required String password}) async {
    try {
      await _service.signIn(email: email, password: password);
      await _loadSessionUser();
      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (_) {
      return 'خطایی رخ داد؛ اتصال اینترنت را بررسی کنید و دوباره تلاش کنید.';
    }
  }

  /// ثبت‌نام دومرحله‌ای؛ حساب بلافاصله فعال می‌شود (به‌شرطی که «تأیید ایمیل»
  /// در تنظیمات Supabase Auth غیرفعال باشد — در راهنمای SETUP توضیح داده شده).
  Future<String?> signUp({
    required String email, required String password, required String name,
    String country = 'نامشخص', String originProvince = 'نامشخص', String district = 'نامشخص',
    String tribe = '—', String nativeLanguage = 'نامشخص', String bio = '',
  }) async {
    try {
      final res = await _service.signUp(email: email, password: password, name: name);
      final user = res.user;
      if (user == null) return 'ثبت‌نام ناتمام ماند؛ دوباره تلاش کنید.';
      // ردیف پایه‌ی profile با تریگر ساخته شده؛ حالا اطلاعات ریشه را تکمیل می‌کنیم
      if (res.session != null) {
        await _service.updateProfileFields(user.id, {
          'country': country, 'origin_province': originProvince, 'district': district,
          'tribe': tribe, 'native_language': nativeLanguage, 'bio': bio,
          'terms_accepted_at': DateTime.now().toIso8601String(),
        });
        await _loadSessionUser();
        return null;
      }
      return 'حساب ساخته شد؛ لطفاً با همین ایمیل و رمز وارد شوید.';
    } on AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (_) {
      return 'خطایی رخ داد؛ اتصال اینترنت را بررسی کنید و دوباره تلاش کنید.';
    }
  }

  Future<String> resetPasswordForEmail(String email) => _service.resetPasswordForEmail(email);

  /// تأیید کد ۶ رقمیِ بازیابی — جایگزینِ قابل‌اعتمادِ کلیک روی پیوند ایمیل
  /// (نگاه کنید به توضیح در BackendService.verifyRecoveryOtp). در صورت
  /// موفقیت، Supabase یک نشست موقتِ بازیابی می‌سازد؛ رویداد passwordRecovery
  /// در listener بالای همین کلاس هم شلیک می‌شود، اما برای اطمینان stage را
  /// همین‌جا هم مستقیم به resetPassword تغییر می‌دهیم.
  Future<String?> verifyRecoveryOtp({required String email, required String token}) async {
    try {
      await _service.verifyRecoveryOtp(email: email, token: token);
      stage = AuthStage.resetPassword;
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (_) {
      return 'کد وارد‌شده نامعتبر است یا منقضی شده؛ یک کد تازه درخواست دهید.';
    }
  }

  /// مرحله‌ی نهایی بازیابی رمز — وقتی کاربر از طریق پیوند ایمیل‌شده وارد
  /// صفحه‌ی «تنظیم رمز تازه» شده (نشست موقتِ بازیابی از قبل فعال است، پس
  /// برخلاف [changePassword] نیازی به تأیید رمز فعلی نیست). عمداً stage را
  /// این‌جا تغییر نمی‌دهد — فقط رمز را تنظیم می‌کند تا UI بتواند پیش از
  /// انتقال به اپ، یک لحظه‌ی کوتاهِ «موفقیت» را نشان بدهد؛ برای ورود واقعی
  /// به اپ بعداً [completeRecoveryLogin] صدا زده می‌شود.
  Future<String?> updatePasswordFromRecovery(String newPassword) async {
    try {
      await _service.updatePassword(newPassword);
      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (_) {
      return 'تنظیم رمز تازه ناموفق بود؛ دوباره تلاش کنید یا پیوند بازیابی تازه‌ای درخواست دهید.';
    }
  }

  /// پس از نمایش انیمیشن موفقیت در صفحه‌ی «تنظیم رمز تازه»، همان نشست موقتِ
  /// بازیابی را برای بارگذاری کامل پروفایل/محتوا استفاده می‌کند — کاربر
  /// بی‌درنگ، بدون نیاز به ورود دوباره با رمز تازه، وارد اپ می‌شود.
  Future<void> completeRecoveryLogin() => _loadSessionUser();

  Future<void> logout() async {
    await _stopNotificationsRealtime();
    for (final sub in _pushSubs) {
      await sub.cancel();
    }
    _pushSubs.clear();
    notificationOpener = null;
    pendingNotificationTarget = null;
    adminRequestedPage = null;
    await PushService.unsubscribeFromAll();
    await _pushTokenRefreshSub?.cancel();
    _pushTokenRefreshSub = null;
    if (_pushToken != null) {
      await _service.unregisterDeviceToken(_pushToken!).catchError((_) {});
      _pushToken = null;
    }
    showNotificationPermissionSheet = false;
    _pendingPushUserId = null;
    await _service.signOut();
    currentUser = null;
    adminPreviewAsUser = false;
    content = {};
    users = [];
    posts = [];
    postsHasMore = true;
    postsLoadingMore = false;
    artists = [];
    myArticles = [];
    allArticleSubmissions = [];
    myDonationTransfers = [];
    allDonationTransfers = [];
    donorLeaderboard = [];
    _roleById.clear();
    notifications = [];
    blockedUsers = [];
    contentReports = [];
    incomingToast = null;
    stage = AuthStage.welcome;
    notifyListeners();
  }

  /// حذف کامل و برگشت‌ناپذیر حساب کاربری — پس از تأیید کاربر در UI فراخوانی
  /// می‌شود. در صورت موفقیت، دقیقاً همان پاک‌سازی وضعیت محلی «logout» را انجام
  /// می‌دهد (چون دیگر نشستی برای این حساب معنا ندارد) و کاربر را به صفحه‌ی
  /// خوش‌آمدگویی برمی‌گرداند. خروجی: null یعنی موفق، غیر آن پیام خطای فارسی است.
  Future<String?> deleteAccount() async {
    if (currentUser == null) return 'ابتدا وارد شوید.';
    try {
      await _service.deleteAccount();
    } catch (e) {
      return 'حذف حساب ناموفق بود؛ دوباره تلاش کنید یا از طریق «تماس با ما» با ما در ارتباط باشید.';
    }
    // حساب دیگر روی سرور وجود ندارد؛ حتی اگر پاک‌سازی محلی (مثلاً signOut) با
    // خطای شبکه مواجه شود، کاربر نباید در وضعیت واردشده‌ی نامعتبر بماند.
    try {
      await logout();
    } catch (_) {
      currentUser = null;
      stage = AuthStage.welcome;
      notifyListeners();
    }
    return null;
  }

  String _translateAuthError(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login credentials')) return 'ایمیل یا رمز عبور نادرست است.';
    if (m.contains('already registered') || m.contains('already exists')) return 'این ایمیل قبلاً ثبت شده است.';
    if (m.contains('email not confirmed')) return 'ایمیل هنوز تأیید نشده است.';
    if (m.contains('password should be at least')) return 'رمز عبور باید حداقل ۶ نویسه باشد.';
    if (m.contains('should be different from the old password') || m.contains('different from the old')) {
      return 'رمز تازه باید با رمز قبلی‌تان متفاوت باشد.';
    }
    if (m.contains('auth session missing') || m.contains('session') && m.contains('expired')) {
      return 'نشست بازیابی منقضی شده؛ دوباره از ابتدا پیوند بازیابی درخواست دهید.';
    }
    if (m.contains('token has expired') || m.contains('otp') && m.contains('expired') || m.contains('token') && m.contains('invalid')) {
      return 'کد وارد‌شده نادرست یا منقضی است؛ کد تازه‌ای درخواست دهید.';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'درخواست‌های زیاد در زمان کوتاه؛ کمی صبر کنید و دوباره تلاش کنید.';
    }
    if (m.contains('network') || m.contains('timeout') || m.contains('failed host lookup')) {
      return 'خطا در اتصال اینترنت؛ دوباره تلاش کنید.';
    }
    // پیام خام سرور معمولاً انگلیسی است — به‌جای نشان‌دادنش به کاربر
    // فارسی‌زبان، یک پیام عمومی و قابل‌فهم برمی‌گردانیم.
    return 'خطایی رخ داد؛ دوباره تلاش کنید.';
  }

  void toggleAdminPreview() {
    adminPreviewAsUser = !adminPreviewAsUser;
    notifyListeners();
  }

  void setDisplayName(String name) {
    displayName = name;
    if (currentUser != null) {
      _service.updateProfileFields(currentUser!.id, {'name': name});
    }
    notifyListeners();
  }

  Future<void> uploadAvatar(XFile file) async {
    if (currentUser == null) return;
    final url = await _service.uploadAvatar(currentUser!.id, file);
    avatarPath = url;
    notifyListeners();
  }

  /// ویرایش پروفایل از صفحه‌ی «تنظیمات» — همان فیلدهایی که در ثبت‌نام پر شده بودند.
  Future<void> updateMyProfile({
    required String name, required String country, required String originProvince,
    required String district, required String tribe, required String nativeLanguage, required String bio,
  }) async {
    if (currentUser == null) return;
    await _service.updateProfileFields(currentUser!.id, {
      'name': name, 'country': country, 'origin_province': originProvince,
      'district': district, 'tribe': tribe, 'native_language': nativeLanguage, 'bio': bio,
    });
    currentUser!.name = name;
    currentUser!.country = country;
    currentUser!.originProvince = originProvince;
    currentUser!.district = district;
    currentUser!.tribe = tribe;
    currentUser!.nativeLanguage = nativeLanguage;
    currentUser!.bio = bio;
    displayName = name;
    notifyListeners();
  }

  /// تغییر رمز عبور — رمز فعلی را دوباره تأیید می‌کنیم تا مطمئن شویم خودِ
  /// کاربر است (نه کسی که فقط به نشست بازِ او دسترسی موقت دارد).
  Future<String?> changePassword({required String currentPassword, required String newPassword}) async {
    if (currentUser == null) return 'ابتدا وارد شوید.';
    try {
      await _service.signIn(email: currentUser!.email, password: currentPassword);
      await _service.updatePassword(newPassword);
      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e.message);
    } catch (_) {
      return 'رمز فعلی نادرست است یا خطایی رخ داد.';
    }
  }

  /// فقط مدیر: کد ۸ رقمیِ بازیابی رمز برای یک کاربر (جایگزین ایمیل خودکار).
  Future<String> createRecoveryCode(String userId) => _service.createRecoveryCode(userId);

  // ---------------- تماس با ما ----------------

  Future<void> loadMyMessages() async {
    if (currentUser == null) return;
    myMessages = await _service.fetchMessagesForUser(currentUser!.id);
    notifyListeners();
  }

  Future<void> sendContactMessage(String text) async {
    if (currentUser == null || text.trim().isEmpty) return;
    await _service.sendMessage(currentUser!.id, text.trim());
    await loadMyMessages();
  }

  Future<void> loadAllMessages() async {
    allMessages = await _service.fetchAllMessages();
    notifyListeners();
  }

  Future<void> replyToMessage(String messageId, String reply) async {
    if (reply.trim().isEmpty) return;
    await _service.replyToMessage(messageId, reply.trim());
    await loadAllMessages();
  }

  Future<void> markMessageRead(String messageId) async {
    await _service.markMessageRead(messageId);
    await loadAllMessages();
  }

  // ---------------- گزارش محتوا و مسدودسازی کاربر ----------------

  bool isBlocked(String userId) => blockedUsers.any((b) => b.blockedId == userId);

  /// فید بدون پست/کامنتِ کاربرانی که خودِ کاربر مسدود کرده — همه‌جا به‌جای
  /// posts خام، همین را برای نمایش استفاده کنید.
  List<Post> get visiblePosts => blockedUsers.isEmpty ? posts : posts.where((p) => !isBlocked(p.authorId)).toList();

  Future<void> loadBlockedUsers() async {
    if (currentUser == null) return;
    blockedUsers = await _service.fetchBlockedUsers(currentUser!.id);
    notifyListeners();
  }

  Future<void> blockUser({required String userId, required String name, String? avatarUrl}) async {
    if (currentUser == null || userId == currentUser!.id) return;
    await _service.blockUser(blockerId: currentUser!.id, blockedId: userId, blockedName: name, blockedAvatarUrl: avatarUrl);
    await loadBlockedUsers();
  }

  Future<void> unblockUser(String userId) async {
    if (currentUser == null) return;
    await _service.unblockUser(blockerId: currentUser!.id, blockedId: userId);
    await loadBlockedUsers();
  }

  /// خروجی: null یعنی گزارش با موفقیت ثبت شد.
  Future<String?> reportContent({
    required String targetType,
    required String targetId,
    String? targetOwnerId,
    String? targetPreview,
    required String reason,
    String? note,
  }) async {
    if (currentUser == null) return 'ابتدا وارد شوید.';
    try {
      await _service.reportContent(
        reporterId: currentUser!.id,
        targetType: targetType,
        targetId: targetId,
        targetOwnerId: targetOwnerId,
        targetPreview: targetPreview,
        reason: reason,
        note: note,
      );
      return null;
    } catch (_) {
      return 'ثبت گزارش ناموفق بود؛ دوباره تلاش کنید.';
    }
  }

  // ---- فقط مدیر ----

  Future<void> loadContentReports() async {
    contentReports = await _service.fetchContentReports();
    notifyListeners();
  }

  Future<void> resolveReport(String id, String status) async {
    await _service.updateReportStatus(id, status);
    await loadContentReports();
  }

  // ---------------- محتوای بخش‌ها (برای پنل مدیریت) ----------------

  Future<void> addContentItem(String sectionId, Map<String, dynamic> fields, {String? imageUrl, String? videoUrl}) async {
    final item = await _service.addContentItem(sectionId, fields, imageUrl: imageUrl, videoUrl: videoUrl);
    content[sectionId] ??= [];
    content[sectionId]!.add(item);
    notifyListeners();
  }

  Future<void> updateContentItem(String sectionId, String itemId, Map<String, dynamic> fields, {String? imageUrl, String? videoUrl}) async {
    await _service.updateContentItem(itemId, fields, imageUrl: imageUrl, videoUrl: videoUrl);
    final item = content[sectionId]?.firstWhere((i) => i.id == itemId);
    item?.fields.addAll(fields);
    if (imageUrl != null) item?.imageUrl = imageUrl;
    if (videoUrl != null) item?.videoUrl = videoUrl;
    notifyListeners();
  }

  /// آپلود عکس یک آیتم محتوا (از «مدیریت محتوا») و برگرداندن URL عمومی آن.
  Future<String> uploadContentImage(XFile file) => _service.uploadContentImage(file);

  Future<void> deleteContentItem(String sectionId, String itemId) async {
    await _service.deleteContentItem(itemId);
    content[sectionId]?.removeWhere((i) => i.id == itemId);
    notifyListeners();
  }

  // ---------------- کاربران (پنل مدیریت) ----------------

  Future<void> toggleUserStatus(String userId) async {
    final u = users.firstWhere((u) => u.id == userId);
    final goingActive = u.status == UserStatus.blocked;
    await _service.setUserStatus(userId, goingActive);
    u.status = goingActive ? UserStatus.active : UserStatus.blocked;
    notifyListeners();
  }

  /// فقط مدیر — رفرش دستیِ فهرست کاربران (برای پول‌تودریفرش صفحه‌ی کاربران).
  Future<void> loadUsers() async {
    if (currentUser?.role != UserRole.admin) return;
    users = await _service.fetchAllProfiles();
    notifyListeners();
  }

  Future<void> updateUserRole(String userId, UserRole role) async {
    await _service.updateUserRole(userId, role);
    final u = users.firstWhere((u) => u.id == userId);
    u.role = role;
    notifyListeners();
  }

  /// تاریخچه‌ی کامل فعالیت یک کاربر — برای پرونده‌ی کاربر در پنل مدیریت.
  Future<List<UserActivityEntry>> fetchUserActivity(String userId) => _service.fetchUserActivity(userId);

  /// جمعِ دلاریِ تقریبیِ کمک‌های تأییدشده‌ی یک کاربر دلخواه — از donorLeaderboard
  /// که از قبل بارگذاری شده (برای حلقه‌ی مقام در فهرست/پرونده‌ی کاربران).
  double donorTotalForUser(String userId) {
    for (final e in donorLeaderboard) {
      if (e.userId == userId) return e.totalUsd;
    }
    return 0;
  }

  /// نقش یک کاربر دلخواه از روی آی‌دی‌اش — برای مدیر که فهرست کامل users
  /// لود شده مستقیم از آن‌جا، برای بقیه از کش سبک نقش‌ها که هنگام ورود
  /// برای همه‌ی کاربران (نه فقط مدیر) بارگذاری می‌شود.
  UserRole? roleForUserId(String userId) {
    if (currentUser?.id == userId) return currentUser!.role;
    for (final u in users) {
      if (u.id == userId) return u.role;
    }
    return _roleById[userId];
  }

  /// مقام مؤثر یک کاربر دلخواه برای حلقه‌ی دور عکس پروفایل — همان منطق
  /// [donorTierForUser] اما فقط با آی‌دی کاربر (فید، کامنت‌ها، مقاله، پیام‌ها).
  DonorTier? donorTierForUserId(String userId) => donorTierByRole(roleForUserId(userId), donorTotalForUser(userId));

  // ---------------- حافظه‌ی جمعی ----------------

  Future<void> loadPosts() async {
    if (currentUser == null) return;
    posts = await _service.fetchPosts(currentUser!.id);
    postsHasMore = posts.length >= 15;
    notifyListeners();
  }

  /// بارگذاری پست‌های قدیمی‌تر برای اسکرول بی‌نهایت.
  Future<void> loadMorePosts() async {
    if (currentUser == null || postsLoadingMore || !postsHasMore || posts.isEmpty) return;
    postsLoadingMore = true;
    notifyListeners();
    final more = await _service.fetchMorePosts(currentUser!.id, posts.last.createdAt);
    posts.addAll(more);
    postsHasMore = more.length >= 15;
    postsLoadingMore = false;
    notifyListeners();
  }

  Future<void> publishPost({
    required String text,
    List<String> imageUrls = const [],
    String? videoUrl,
    String? videoThumbnailUrl,
  }) async {
    if (currentUser == null) return;
    if (text.trim().isEmpty && imageUrls.isEmpty && (videoUrl == null || videoUrl.isEmpty)) return;
    final post = await _service.publishPost(
      currentUser!.id,
      text: text.trim(),
      imageUrls: imageUrls,
      videoUrl: videoUrl,
      videoThumbnailUrl: videoThumbnailUrl,
    );
    posts.insert(0, post);
    notifyListeners();
  }

  Future<void> toggleReaction(String postId, String emoji) async {
    if (currentUser == null) return;
    final post = posts.firstWhere((p) => p.id == postId);
    final already = post.myReactions[emoji] ?? false;
    if (already) {
      await _service.removeReaction(postId, currentUser!.id, emoji);
    } else {
      await _service.addReaction(postId, currentUser!.id, emoji);
    }
    final current = post.reactions[emoji] ?? 0;
    final next = current + (already ? -1 : 1);
    if (next <= 0) {
      post.reactions.remove(emoji);
    } else {
      post.reactions[emoji] = next;
    }
    post.myReactions[emoji] = !already;
    notifyListeners();
  }

  Future<List<PostComment>> fetchPostComments(String postId) => _service.fetchPostComments(postId, currentUser?.id);

  Future<void> addPostComment(String postId, String text, {String? parentId}) async {
    if (currentUser == null || text.trim().isEmpty) return;
    await _service.addPostComment(postId, currentUser!.id, text.trim(), parentId: parentId);
    final post = posts.where((p) => p.id == postId).cast<Post?>().firstWhere((_) => true, orElse: () => null);
    if (post != null) {
      post.commentsCount += 1;
      notifyListeners();
    }
  }

  Future<void> deletePostComment(String id, String postId) async {
    await _service.deletePostComment(id);
    final post = posts.where((p) => p.id == postId).cast<Post?>().firstWhere((_) => true, orElse: () => null);
    if (post != null && post.commentsCount > 0) {
      post.commentsCount -= 1;
      notifyListeners();
    }
  }

  Future<void> togglePostCommentLike(String commentId, bool currentlyLiked) async {
    if (currentUser == null) return;
    await _service.togglePostCommentLike(commentId, currentUser!.id, currentlyLiked);
  }

  Future<void> deletePost(String postId) async {
    await _service.deletePost(postId);
    posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  /// آپلود یک عکس برای پست تازه و برگرداندن URL عمومی آن.
  Future<String> uploadPostImage(XFile file) {
    if (currentUser == null) throw Exception('ابتدا وارد شوید.');
    return _service.uploadPostImage(currentUser!.id, file);
  }

  /// آپلود یک ویدیو برای پست تازه و برگرداندن URL عمومی آن.
  Future<String> uploadPostVideo(XFile file) {
    if (currentUser == null) throw Exception('ابتدا وارد شوید.');
    return _service.uploadPostVideo(currentUser!.id, file);
  }

  List<Post> get myPosts => posts.where((p) => p.authorId == currentUser?.id).toList();

  int get myReactionsReceived => myPosts.fold(0, (sum, p) => sum + p.totalReactions);

  // ================= موسیقی و شعر: گالری هنرمندان و ویدیو =================

  Future<void> loadArtists() async {
    artists = await _service.fetchArtists();
    notifyListeners();
  }

  /// آپلود یک عکس (آواتار هنرمند، کاور، یا تامبنیل ویدیو) و برگرداندن URL آن.
  Future<String> uploadArtistImage(XFile file) => _service.uploadArtistImage(file);

  /// آپلود یک فایل ویدیو و برگرداندن URL عمومی آن.
  Future<String> uploadArtistVideoFile(XFile file) => _service.uploadArtistVideoFile(file);

  Future<void> addArtist(String name, {String bio = '', String? avatarUrl, String? coverUrl}) async {
    final artist = await _service.addArtist(name, bio: bio, avatarUrl: avatarUrl, coverUrl: coverUrl);
    artists.add(artist);
    notifyListeners();
  }

  Future<void> updateArtist(String id, {String? name, String? bio, String? avatarUrl, String? coverUrl}) async {
    await _service.updateArtist(id, name: name, bio: bio, avatarUrl: avatarUrl, coverUrl: coverUrl);
    final a = artists.firstWhere((a) => a.id == id);
    if (name != null) a.name = name;
    if (bio != null) a.bio = bio;
    if (avatarUrl != null) a.avatarUrl = avatarUrl;
    if (coverUrl != null) a.coverUrl = coverUrl;
    notifyListeners();
  }

  Future<void> deleteArtist(String id) async {
    await _service.deleteArtist(id);
    artists.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  Future<List<ArtistVideo>> fetchArtistVideos(String artistId) => _service.fetchArtistVideos(artistId);

  Future<ArtistVideo> addVideo(String artistId, {required String title, String description = '', required String videoUrl, String? thumbnailUrl}) async {
    final video = await _service.addVideo(artistId, title: title, description: description, videoUrl: videoUrl, thumbnailUrl: thumbnailUrl);
    final a = artists.where((a) => a.id == artistId).cast<Artist?>().firstWhere((_) => true, orElse: () => null);
    if (a != null) {
      a.videoCount += 1;
      notifyListeners();
    }
    return video;
  }

  Future<void> updateVideo(String id, {String? title, String? description, String? thumbnailUrl}) {
    return _service.updateVideo(id, title: title, description: description, thumbnailUrl: thumbnailUrl);
  }

  Future<void> deleteVideo(String id, String artistId) async {
    await _service.deleteVideo(id);
    final a = artists.where((a) => a.id == artistId).cast<Artist?>().firstWhere((_) => true, orElse: () => null);
    if (a != null && a.videoCount > 0) {
      a.videoCount -= 1;
      notifyListeners();
    }
  }

  /// افزایش شمارنده‌ی بازدید — یک‌بار در شروع هر پخش صدا زده می‌شود.
  Future<void> incrementVideoViews(String videoId) => _service.incrementVideoViews(videoId);

  Future<List<VideoComment>> fetchVideoComments(String videoId) => _service.fetchVideoComments(videoId);

  Future<void> addVideoComment(String videoId, String text, {String? parentId}) async {
    if (currentUser == null || text.trim().isEmpty) return;
    await _service.addVideoComment(videoId, currentUser!.id, text.trim(), parentId: parentId);
  }

  Future<void> deleteVideoComment(String id) => _service.deleteVideoComment(id);

  Future<Map<String, dynamic>> fetchVideoReactions(String videoId) =>
      _service.fetchVideoReactions(videoId, currentUser?.id);

  Future<void> toggleVideoReaction(String videoId, String emoji, bool currentlyMine) async {
    if (currentUser == null) return;
    if (currentlyMine) {
      await _service.removeVideoReaction(videoId, currentUser!.id, emoji);
    } else {
      await _service.addVideoReaction(videoId, currentUser!.id, emoji);
    }
  }

  // ================= مسابقه‌ی مقالات =================

  Future<void> loadContestSettings() async {
    contestSettings = await _service.fetchContestSettings();
    notifyListeners();
  }

  Future<void> updateContestSettings({required String topic, String? prizeFirst, String? prizeSecond, String? prizeThird}) async {
    await _service.updateContestSettings(topic: topic, prizeFirst: prizeFirst, prizeSecond: prizeSecond, prizeThird: prizeThird);
    await loadContestSettings();
  }

  /// شروع دوره‌ی تازه‌ی مسابقه (تاریخ آغاز = همین لحظه؛ ۲۸ روز پنجره‌ی ارسال باز می‌شود).
  Future<void> startNewContestRound() async {
    await _service.startNewContestRound();
    await loadContestSettings();
  }

  Future<void> loadMyArticles() async {
    if (currentUser == null) return;
    myArticles = await _service.fetchMySubmissions(currentUser!.id);
    notifyListeners();
  }

  Future<void> submitArticle({required String title, required String body}) async {
    if (currentUser == null) return;
    final article = await _service.submitArticle(currentUser!.id, title: title, body: body);
    myArticles.insert(0, article);
    notifyListeners();
  }

  /// فقط مدیر — همه‌ی مقالات ارسالی همه‌ی کاربران.
  Future<void> loadAllArticleSubmissions() async {
    allArticleSubmissions = await _service.fetchAllSubmissions();
    notifyListeners();
  }

  Future<void> saveArticleAiReview(String id, {required String verdict, required double confidence, required double qualityScore, required String notes}) async {
    await _service.saveArticleAiReview(id, verdict: verdict, confidence: confidence, qualityScore: qualityScore, notes: notes);
    await loadAllArticleSubmissions();
  }

  Future<void> updateSubmissionStatus(String id, String status) async {
    await _service.updateSubmissionStatus(id, status);
    await loadAllArticleSubmissions();
  }

  Future<void> deleteSubmission(String id) async {
    await _service.deleteSubmission(id);
    allArticleSubmissions.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  Future<void> publishFeaturedArticle({
    String? submissionId,
    String? authorId,
    required String authorName,
    String? authorAvatar,
    required String title,
    required String body,
    required int placement,
    required String monthLabel,
    String? prize,
  }) async {
    await _service.publishFeaturedArticle(
      submissionId: submissionId,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      title: title,
      body: body,
      placement: placement,
      monthLabel: monthLabel,
      prize: prize,
    );
    await loadFeaturedArticles();
    if (submissionId != null) await loadAllArticleSubmissions();
  }

  Future<void> loadFeaturedArticles() async {
    featuredArticles = await _service.fetchFeaturedArticles();
    notifyListeners();
  }

  Future<void> updateFeaturedArticle(String id, {String? title, String? body, String? monthLabel, String? prize, int? placement}) async {
    await _service.updateFeaturedArticle(id, title: title, body: body, monthLabel: monthLabel, prize: prize, placement: placement);
    await loadFeaturedArticles();
  }

  Future<void> deleteFeaturedArticle(String id) async {
    await _service.deleteFeaturedArticle(id);
    featuredArticles.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  Future<List<ArticleComment>> fetchArticleComments(String articleId) => _service.fetchArticleComments(articleId);

  Future<void> addArticleComment(String articleId, String text, {String? parentId}) async {
    if (currentUser == null || text.trim().isEmpty) return;
    await _service.addArticleComment(articleId, currentUser!.id, text.trim(), parentId: parentId);
  }

  Future<void> deleteArticleComment(String id) => _service.deleteArticleComment(id);

  Future<Map<String, dynamic>> fetchArticleReactions(String articleId) =>
      _service.fetchArticleReactions(articleId, currentUser?.id);

  Future<void> toggleArticleReaction(String articleId, String emoji, bool currentlyMine) async {
    if (currentUser == null) return;
    if (currentlyMine) {
      await _service.removeArticleReaction(articleId, currentUser!.id, emoji);
    } else {
      await _service.addArticleReaction(articleId, currentUser!.id, emoji);
    }
  }

  // ================= کمک‌های مالی =================

  Future<void> loadDonationSettings() async {
    donationSettings = await _service.fetchDonationSettings();
    notifyListeners();
  }

  Future<void> updateDonationSettings({
    required double totalRaised,
    required String currency,
    required int familiesHelped,
    required int projectsCompleted,
  }) async {
    await _service.updateDonationSettings(
      totalRaised: totalRaised,
      currency: currency,
      familiesHelped: familiesHelped,
      projectsCompleted: projectsCompleted,
    );
    await loadDonationSettings();
  }

  Future<void> loadMyDonationTransfers() async {
    if (currentUser == null) return;
    myDonationTransfers = await _service.fetchMyDonationTransfers(currentUser!.id);
    notifyListeners();
  }

  Future<void> submitDonationTransfer({
    required String senderName,
    required String senderCountry,
    String? senderContact,
    required double amount,
    required String currency,
    String? transferReference,
    String? note,
    required DonationCategory category,
    DonationMethod method = DonationMethod.bankTransfer,
  }) async {
    if (currentUser == null) return;
    final t = await _service.submitDonationTransfer(
      currentUser!.id,
      senderName: senderName,
      senderCountry: senderCountry,
      senderContact: senderContact,
      amount: amount,
      currency: currency,
      transferReference: transferReference,
      note: note,
      category: category,
      method: method,
    );
    myDonationTransfers.insert(0, t);
    notifyListeners();
  }

  /// فهرست عمومیِ کمک‌کنندگان — برای صفحه‌ی «فهرست کمک‌کنندگان».
  Future<void> loadDonorLeaderboard() async {
    donorLeaderboard = await _service.fetchDonorLeaderboard();
    notifyListeners();
  }

  /// نقش‌ی همه‌ی کاربران + فهرست کمک‌کنندگان را برای هر کاربری که وارد
  /// می‌شود بارگذاری می‌کند (نه فقط مدیر) — پایه‌ی [roleForUserId] و
  /// [donorTierForUserId] برای نمایش درست حلقه‌ی مقام در فید/کامنت‌ها/
  /// مقاله/پیام‌ها. خطا اینجا بی‌سروصدا نادیده گرفته می‌شود چون نباید جلوی
  /// ورود به برنامه را بگیرد.
  Future<void> _loadRoleAndDonorCaches() async {
    try {
      final results = await Future.wait([
        _service.fetchAllUserRoles(),
        _service.fetchDonorLeaderboard(),
      ]);
      _roleById
        ..clear()
        ..addAll(results[0] as Map<String, UserRole>);
      donorLeaderboard = results[1] as List<DonorRankEntry>;
      notifyListeners();
    } catch (_) {
      // بی‌اهمیت — حلقه‌ی مقام برای بقیه‌ی کاربران فقط تا لود بعدی پیش‌فرض می‌ماند
    }
  }

  /// فقط مدیر — همه‌ی حواله‌های ارسالی همه‌ی کاربران.
  Future<void> loadAllDonationTransfers() async {
    allDonationTransfers = await _service.fetchAllDonationTransfers();
    notifyListeners();
  }

  /// فقط مدیر — آخرین فعالیت‌های واقعی همه‌ی کاربران، برای صفحه‌ی نخست پنل مدیریت.
  Future<void> loadRecentActivity({int limit = 8}) async {
    recentActivity = await _service.fetchRecentActivity(limit: limit);
    notifyListeners();
  }

  /// فقط مدیر — شمار واقعی بازدیدهای امروز + روند ۷ روز گذشته، برای کارت
  /// «بازدید امروز» در صفحه‌ی نخست پنل مدیریت.
  Future<void> loadTodayVisitCount() async {
    final results = await Future.wait([
      _service.fetchTodayVisitCount(),
      _service.fetchVisitTrend(),
    ]);
    todayVisitCount = results[0] as int;
    visitTrend = results[1] as List<double>;
    notifyListeners();
  }

  /// فهرست اعلان‌های خودِ کاربر جاری — برای ناقوس/صندوق اعلان‌ها.
  Future<void> loadNotifications() async {
    if (currentUser == null) return;
    notifications = await _service.fetchNotifications(currentUser!.id);
    notifyListeners();
  }

  /// یک بار در هر نشست: اعلان‌های موجود را می‌گیرد، سپس از همان نقطه (زمان سرور)
  /// به‌طور دوره‌ای اعلان‌های تازه را می‌پرسد؛ و پوش‌های رسیده را هم وصل می‌کند —
  /// پوشِ رسیده وقتی اپ باز است فوراً فهرست را تازه می‌کند و لمس روی پوش،
  /// صفحه‌ی مربوط (پست، پیام، کمک مالی…) را باز می‌کند.
  Future<void> _initNotifications() async {
    if (currentUser == null) return;
    try {
      await loadNotifications();
    } catch (_) {}
    if (currentUser == null) return;
    final newest = notifications.isEmpty ? null : notifications.first.createdAt.toUtc().toIso8601String();
    _notificationsChannel = _service.subscribeToNotifications(
      currentUser!.id,
      (n) {
        notifications.insert(0, n);
        incomingToast = n;
        notifyListeners();
        // کار تازه برای مدیر رسید: نشان‌های عددی پنل را هم تازه کن
        if (n.type.startsWith('admin_')) unawaited(loadAdminInbox());
      },
      sinceIso: newest,
      knownIds: notifications.map((n) => n.id),
    );
    _pushSubs.add(PushService.onForegroundMessage.listen((_) => _notificationsChannel?.pollNow()));
    _pushSubs.add(PushService.onOpenedFromPush.listen((m) => _openFromPush(m.data)));
    final initial = await PushService.initialMessage();
    if (initial != null) _openFromPush(initial.data);
  }

  final List<StreamSubscription> _pushSubs = [];

  void _openFromPush(Map<String, dynamic> data) {
    _requestOpen(NotificationTarget(
      type: (data['type'] ?? '').toString(),
      refType: (data['ref_type'] ?? '').toString().isEmpty ? null : data['ref_type'].toString(),
      refId: (data['ref_id'] ?? '').toString().isEmpty ? null : data['ref_id'].toString(),
    ));
    _notificationsChannel?.pollNow();
  }

  /// صفحه‌ای که باید برای یک اعلان باز شود — MainShell آن را اجرا می‌کند.
  /// اگر پوش پیش از آماده‌شدن رابط کاربری لمس شده باشد، اینجا منتظر می‌ماند.
  NotificationTarget? pendingNotificationTarget;
  void Function(NotificationTarget target)? notificationOpener;

  void _requestOpen(NotificationTarget t) {
    final opener = notificationOpener;
    if (opener != null) {
      opener(t);
    } else {
      pendingNotificationTarget = t;
    }
  }

  void attachNotificationOpener(void Function(NotificationTarget target) opener) {
    notificationOpener = opener;
    final pending = pendingNotificationTarget;
    pendingNotificationTarget = null;
    if (pending != null) opener(pending);
  }

  /// صفحه‌ای از پنل مدیریت که باید باز شود (مثلاً با لمس اعلان «پیام تازه»).
  String? adminRequestedPage;
  void requestAdminPage(String page) {
    adminPreviewAsUser = false;
    adminRequestedPage = page;
    notifyListeners();
  }

  String? consumeAdminRequestedPage() {
    final p = adminRequestedPage;
    adminRequestedPage = null;
    return p;
  }

  /// پستی که در فید نیست را می‌گیرد و به فهرست اضافه می‌کند (برای باز کردن از اعلان).
  Future<bool> ensurePostLoaded(String id) async {
    if (posts.any((p) => p.id == id)) return true;
    final post = await _service.fetchPostById(id, currentUser?.id);
    if (post == null) return false;
    posts = [...posts, post];
    notifyListeners();
    return true;
  }

  /// شمار مطالب هر بخش — یک منبع برای اپ کاربران و پنل مدیر تا عددها همه‌جا یکی باشد.
  /// (موسیقی = شمار هنرمندان؛ زبان = واژه‌های پایگاه‌داده + واژه‌نامه‌ی داخل اپ)
  int sectionItemCount(String id) {
    if (id == 'music') return artists.length;
    final n = content[id]?.length ?? 0;
    return id == 'language' ? n + kHazaragiGlossaryCount : n;
  }

  // ---------------- مدیر: صندوق کارهای در انتظار ----------------
  int get pendingMessagesCount => allMessages.where((m) => m.status == MessageStatus.newMsg).length;
  int get pendingDonationsCount => allDonationTransfers.where((d) => d.status == DonationTransferStatus.pending).length;
  int get pendingReportsCount => contentReports.where((r) => r.status == 'pending').length;
  int get activeSubmissionsCount => allArticleSubmissions.where((a) => a.status == ArticleStatus.active).length;

  /// همه‌ی صف‌های بررسی مدیر را یک‌جا تازه می‌کند (نشان‌های عددی منو و نمای کلی).
  Future<void> loadAdminInbox() async {
    if (currentUser?.role != UserRole.admin) return;
    await Future.wait([
      loadAllMessages().catchError((_) {}),
      loadAllDonationTransfers().catchError((_) {}),
      loadContentReports().catchError((_) {}),
      loadAllArticleSubmissions().catchError((_) {}),
    ]);
  }

  // ---------------- مدیر: اعلان همگانی و وضعیت پوش ----------------
  Future<Map<String, dynamic>> fetchPushStatus() => _service.fetchPushStatus();
  Future<int> sendBroadcast({required String title, required String body, bool adminsOnly = false}) =>
      _service.sendBroadcast(title: title, body: body, adminsOnly: adminsOnly);

  Future<void> _stopNotificationsRealtime() async {
    final channel = _notificationsChannel;
    _notificationsChannel = null;
    if (channel != null) {
      await _service.removeChannel(channel);
    }
  }

  /// پیش از درخواست رسمی پوش، وضعیت فعلی را چک می‌کند: اگر کاربر قبلاً اجازه
  /// داده، بی‌سروصدا توکن را ثبت می‌کند؛ اگر رد کرده، دیگر مزاحمش نمی‌شود؛
  /// و فقط وقتی هنوز چیزی مشخص نیست، کارت توضیح دوستانه را نشان می‌دهد تا
  /// خودِ کاربر با آگاهی تصمیم بگیرد (به‌جای این‌که پنجره‌ی سیستم‌عامل ناگهانی
  /// و بدون توضیح ظاهر شود) — هم رعایت قوانین اپ‌استور/پلی‌استور، هم UX بهتر.
  Future<void> _maybeAskNotificationPermission(String userId) async {
    try {
      final state = await PushService.getPermissionState();
      switch (state) {
        case PushPermissionState.authorized:
          await _registerPushToken(userId);
          break;
        case PushPermissionState.denied:
          break; // قبلاً رد کرده — دیگر نپرس
        case PushPermissionState.notDetermined:
          _pendingPushUserId = userId;
          showNotificationPermissionSheet = true;
          notifyListeners();
          break;
      }
    } catch (_) {
      // بدون Firebase یا بدون Google Play Services — مشکلی نیست
    }
  }

  /// کاربر روی «اجازه می‌دهم» در کارت توضیح دوستانه زده — همین الان پنجره‌ی
  /// رسمی سیستم‌عامل را نشان بده و در صورت تأیید، توکن را ثبت کن.
  Future<void> grantNotificationPermission() async {
    showNotificationPermissionSheet = false;
    notifyListeners();
    final userId = _pendingPushUserId;
    _pendingPushUserId = null;
    if (userId != null) {
      await _registerPushToken(userId);
    }
  }

  /// کاربر فعلاً نمی‌خواهد — کارت را کنار می‌گذاریم بدون این‌که پنجره‌ی
  /// سیستم‌عامل باز شود؛ در نشست بعدی دوباره می‌توان (با احترام) پرسید.
  void declineNotificationPermissionSheet() {
    showNotificationPermissionSheet = false;
    _pendingPushUserId = null;
    notifyListeners();
  }

  /// اجازه‌ی اعلان می‌گیرد، توکن FCM دستگاه را می‌گیرد و در Supabase ثبت
  /// می‌کند — پایه‌ی پوش نوتیفیکیشن واقعی. اگر Firebase تنظیم نشده باشد یا
  /// کاربر اجازه ندهد، بی‌سروصدا رد می‌شود؛ بقیه‌ی اپ عادی کار می‌کند.
  Future<void> _registerPushToken(String userId) async {
    try {
      final token = await PushService.requestPermissionAndGetToken();
      if (token != null) {
        _pushToken = token;
        await _service.registerDeviceToken(userId, token);
        await PushService.subscribeToAll();
      }
      _pushTokenRefreshSub?.cancel();
      _pushTokenRefreshSub = PushService.onTokenRefresh.listen((newToken) {
        _pushToken = newToken;
        _service.registerDeviceToken(userId, newToken).catchError((_) {});
      });
    } catch (_) {
      // بدون Firebase یا بدون Google Play Services — مشکلی نیست
    }
  }

  /// بعد از این‌که بنر پویا نمایش داده و کنار زده شد، صدا زده می‌شود تا دوباره
  /// برای همان اعلان تکرار نشود.
  void clearIncomingToast() {
    incomingToast = null;
    notifyListeners();
  }

  Future<void> markNotificationRead(String id) async {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx == -1 || notifications[idx].isRead) return;
    notifications[idx].isRead = true;
    notifyListeners();
    await _service.markNotificationRead(id);
  }

  Future<void> markAllNotificationsRead() async {
    if (currentUser == null || unreadNotificationCount == 0) return;
    for (final n in notifications) {
      n.isRead = true;
    }
    notifyListeners();
    await _service.markAllNotificationsRead(currentUser!.id);
  }

  /// نام نمایشی کاربر از روی آی‌دی‌اش (برای فید فعالیت/کارت‌های کوچک) —
  /// اگر پروفایلش هنوز لود نشده باشد، یک نام عمومی برمی‌گرداند.
  String userNameById(String userId) {
    for (final u in users) {
      if (u.id == userId) return u.name;
    }
    if (currentUser?.id == userId) return currentUser!.name;
    return 'یک کاربر';
  }

  String? userAvatarById(String userId) {
    for (final u in users) {
      if (u.id == userId) return u.avatarPath;
    }
    return null;
  }

  Future<void> updateDonationTransferStatus(String id, String status, {double? confirmedAmount}) async {
    await _service.updateDonationTransferStatus(id, status, confirmedAmount: confirmedAmount);
    await loadAllDonationTransfers();
  }

  Future<void> loadDonationReports() async {
    donationReports = await _service.fetchDonationReports();
    notifyListeners();
  }

  Future<void> publishDonationReport({
    required String title,
    required DonationCategory category,
    required String summary,
    required String body,
    double? amountSpent,
    required String currency,
    List<String> imageUrls = const [],
    String? videoUrl,
    String? location,
    int? beneficiariesCount,
  }) async {
    await _service.publishDonationReport(
      title: title,
      category: category,
      summary: summary,
      body: body,
      amountSpent: amountSpent,
      currency: currency,
      imageUrls: imageUrls,
      videoUrl: videoUrl,
      location: location,
      beneficiariesCount: beneficiariesCount,
      createdBy: currentUser?.id,
    );
    await loadDonationReports();
  }

  Future<void> updateDonationReport(
    String id, {
    String? title,
    DonationCategory? category,
    String? summary,
    String? body,
    double? amountSpent,
    String? currency,
    List<String>? imageUrls,
    String? videoUrl,
    String? location,
    int? beneficiariesCount,
  }) async {
    await _service.updateDonationReport(
      id,
      title: title,
      category: category,
      summary: summary,
      body: body,
      amountSpent: amountSpent,
      currency: currency,
      imageUrls: imageUrls,
      videoUrl: videoUrl,
      location: location,
      beneficiariesCount: beneficiariesCount,
    );
    await loadDonationReports();
  }

  Future<void> deleteDonationReport(String id) async {
    await _service.deleteDonationReport(id);
    donationReports.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  /// آپلود یک عکس مستند برای گزارش شفافیت و برگرداندن URL آن.
  Future<String> uploadDonationImage(XFile file) => _service.uploadDonationImage(file);

  /// آپلود یک فایل ویدیوی مستند برای گزارش شفافیت و برگرداندن URL آن.
  Future<String> uploadDonationVideoFile(XFile file) => _service.uploadDonationVideoFile(file);
}
