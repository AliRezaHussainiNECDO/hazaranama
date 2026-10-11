import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/backend_config.dart';

/// کلاینت سبکِ API هزاره‌نامه روی Cloudflare Workers.
///
/// عمداً همان شکل رابط برنامه‌نویسی Supabase را تقلید می‌کند
/// (`from().select().eq().order()`، `auth.signInWithPassword`، `storage.from().upload`،
/// `functions.invoke`، `rpc`) تا کدِ سرویس‌ها تقریباً بدون تغییر بماند؛ ولی همه‌چیز
/// به Worker خودِ هزاره‌نامه (D1 + R2 + Workers AI) می‌رود، نه Supabase.
class HzBackend {
  HzBackend._(this.baseUrl);

  static HzBackend? _instance;
  static HzBackend get instance {
    final i = _instance;
    if (i == null) throw StateError('HzBackend.initialize() هنوز صدا زده نشده است.');
    return i;
  }

  final String baseUrl;
  late final HzAuth auth = HzAuth._(this);
  late final HzStorage storage = HzStorage._(this);
  late final HzFunctions functions = HzFunctions._(this);
  final http.Client _http = http.Client();

  HzBackend get client => this;

  static Future<HzBackend> initialize({String? url}) async {
    final b = HzBackend._((url ?? BackendConfig.apiUrl).replaceAll(RegExp(r'/+$'), ''));
    _instance = b;
    await b.auth._restore();
    return b;
  }

  Map<String, String> _headers({bool json = true}) => {
        if (json) 'content-type': 'application/json',
        if (auth._session != null) 'authorization': 'Bearer ${auth._session!.accessToken}',
      };

  /// درخواست POST با JSON؛ خطاهای سرور به [HzHttpException] تبدیل می‌شوند.
  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await _http
        .post(Uri.parse('$baseUrl$path'), headers: _headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 60));
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    String message = 'خطای سرور (${res.statusCode})';
    String code = 'error';
    if (data is Map && data['error'] is Map) {
      message = (data['error']['message'] ?? message).toString();
      code = (data['error']['code'] ?? code).toString();
    } else if (data is Map && data['error'] != null) {
      message = data['error'].toString();
    }
    throw HzHttpException(res.statusCode, message, code, data);
  }

  HzQuery from(String table) => HzQuery._(this, table);

  Future<dynamic> rpc(String name, {Map<String, dynamic>? params}) async {
    final data = await post('/rpc/$name', params ?? const {});
    return data is Map ? data['data'] : data;
  }
}

class HzHttpException implements Exception {
  final int status;
  final String message;
  final String code;
  final dynamic details;
  HzHttpException(this.status, this.message, this.code, this.details);
  @override
  String toString() => message;
}

/// معادل PostgrestException — خطای جدول/پرس‌وجو.
class PostgrestException implements Exception {
  final String message;
  final String? code;
  PostgrestException({required this.message, this.code});
  @override
  String toString() => message;
}

// =====================================================================
// پرس‌وجو
// =====================================================================

class HzQuery implements Future<dynamic> {
  HzQuery._(this._b, this._table) {
    // اجرا در میکروتسک بعدی — بعد از این‌که همه‌ی متدهای زنجیره‌ای (eq/order/…) اعمال شدند.
    // حتی اگر نتیجه await نشود، درخواست فرستاده می‌شود (مثل setDisplayName).
    _future = Future<dynamic>.microtask(_execute);
    _future.catchError((_) => null); // خطای await‌نشده نباید «Unhandled» گزارش شود
  }

  final HzBackend _b;
  final String _table;
  late final Future<dynamic> _future;

  String _action = 'select';
  String? _select;
  bool _returning = false;
  final List<List<dynamic>> _filters = [];
  final List<List<dynamic>> _order = [];
  int? _limit;
  dynamic _values;
  String? _onConflict;
  String? _single;

  HzQuery select([String columns = '*']) {
    if (_action == 'select') {
      _select = columns;
    } else {
      _returning = true;
      _select = columns;
    }
    return this;
  }

  HzQuery insert(dynamic values) {
    _action = 'insert';
    _values = values;
    return this;
  }

  HzQuery upsert(dynamic values, {String? onConflict}) {
    _action = 'upsert';
    _values = values;
    _onConflict = onConflict;
    return this;
  }

  HzQuery update(Map<String, dynamic> values) {
    _action = 'update';
    _values = values;
    return this;
  }

  HzQuery delete() {
    _action = 'delete';
    return this;
  }

  HzQuery _f(String col, String op, dynamic v) {
    _filters.add([col, op, v]);
    return this;
  }

  HzQuery eq(String col, dynamic v) => _f(col, 'eq', v);
  HzQuery neq(String col, dynamic v) => _f(col, 'neq', v);
  HzQuery lt(String col, dynamic v) => _f(col, 'lt', v);
  HzQuery lte(String col, dynamic v) => _f(col, 'lte', v);
  HzQuery gt(String col, dynamic v) => _f(col, 'gt', v);
  HzQuery gte(String col, dynamic v) => _f(col, 'gte', v);
  HzQuery inFilter(String col, List<dynamic> v) => _f(col, 'in', v);

  HzQuery match(Map<String, dynamic> m) {
    m.forEach((k, v) => _f(k, 'eq', v));
    return this;
  }

  HzQuery order(String column, {bool ascending = true}) {
    _order.add([column, ascending]);
    return this;
  }

  HzQuery limit(int n) {
    _limit = n;
    return this;
  }

  HzQuery single() {
    _single = 'single';
    return this;
  }

  HzQuery maybeSingle() {
    _single = 'maybe';
    return this;
  }

  Future<dynamic> _execute() async {
    try {
      final data = await _b.post('/db', {
        'table': _table,
        'action': _action,
        'select': _select,
        'returning': _returning,
        'filters': _filters,
        'order': _order,
        'limit': _limit,
        'values': _values,
        'onConflict': _onConflict,
        'single': _single,
      });
      return data is Map ? data['data'] : null;
    } on HzHttpException catch (e) {
      throw PostgrestException(message: e.message, code: e.code);
    }
  }

  // ---- Future ----
  @override
  Stream<dynamic> asStream() => _future.asStream();
  @override
  Future<dynamic> catchError(Function onError, {bool Function(Object error)? test}) => _future.catchError(onError, test: test);
  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) => _future.then(onValue, onError: onError);
  @override
  Future<dynamic> timeout(Duration timeLimit, {FutureOr<dynamic> Function()? onTimeout}) =>
      _future.timeout(timeLimit, onTimeout: onTimeout);
  @override
  Future<dynamic> whenComplete(FutureOr<void> Function() action) => _future.whenComplete(action);
}

// =====================================================================
// احراز هویت
// =====================================================================

class User {
  final String id;
  final String? email;
  const User({required this.id, this.email});
}

class Session {
  final String accessToken;
  final int expiresAt;
  final User user;
  const Session({required this.accessToken, required this.expiresAt, required this.user});

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'expires_at': expiresAt,
        'user': {'id': user.id, 'email': user.email},
      };

  static Session? fromJson(dynamic j) {
    if (j is! Map) return null;
    final u = j['user'];
    final token = j['access_token'] ?? (j['session'] is Map ? j['session']['access_token'] : null);
    final exp = j['expires_at'] ?? (j['session'] is Map ? j['session']['expires_at'] : null);
    if (u is! Map || token == null) return null;
    return Session(
      accessToken: token as String,
      expiresAt: (exp as num?)?.toInt() ?? 0,
      user: User(id: u['id'] as String, email: u['email'] as String?),
    );
  }
}

class AuthResponse {
  final User? user;
  final Session? session;
  const AuthResponse({this.user, this.session});
}

enum AuthChangeEvent { signedIn, signedOut, passwordRecovery, userUpdated }

class AuthState {
  final AuthChangeEvent event;
  final Session? session;
  const AuthState(this.event, this.session);
}

class AuthException implements Exception {
  final String message;
  final int? statusCode;
  const AuthException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class UserAttributes {
  final String? password;
  const UserAttributes({this.password});
}

enum OtpType { recovery }

class HzAuth {
  HzAuth._(this._b);
  final HzBackend _b;
  static const _key = 'hz_session_v1';

  Session? _session;
  final _changes = StreamController<AuthState>.broadcast();

  /// برای UI‌هایی که فقط می‌خواهند بدانند واردشده‌اند یا نه.
  final ValueNotifier<bool> signedIn = ValueNotifier(false);

  User? get currentUser => _session?.user;
  Session? get currentSession => _session;
  Stream<AuthState> get onAuthStateChange => _changes.stream;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final s = Session.fromJson(jsonDecode(raw));
      if (s != null && s.expiresAt * 1000 > DateTime.now().millisecondsSinceEpoch) {
        _session = s;
        signedIn.value = true;
      } else {
        await prefs.remove(_key);
      }
    } catch (_) {
      // حافظه‌ی محلی در دسترس نیست (مثلاً حالت خصوصی مرورگر) — بدون نشست ادامه می‌دهیم
    }
  }

  /// «مرا به خاطر بسپار»: اگر خاموش باشد، نشست فقط تا بسته شدن اپ می‌ماند و روی دستگاه ذخیره نمی‌شود.
  bool persistSession = true;

  Future<void> _setSession(Session? s, AuthChangeEvent event) async {
    _session = s;
    signedIn.value = s != null;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (s == null || !persistSession) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, jsonEncode(s.toJson()));
      }
    } catch (_) {}
    _changes.add(AuthState(event, s));
  }

  Future<AuthResponse> _authCall(String path, Map<String, dynamic> body, AuthChangeEvent event) async {
    try {
      final data = await _b.post(path, body);
      final s = Session.fromJson({
        'user': data['user'],
        'access_token': data['session']?['access_token'],
        'expires_at': data['session']?['expires_at'],
      });
      if (s == null) throw const AuthException('پاسخ نامعتبر از سرور.');
      await _setSession(s, event);
      return AuthResponse(user: s.user, session: s);
    } on HzHttpException catch (e) {
      throw AuthException(e.message, statusCode: e.status);
    }
  }

  Future<AuthResponse> signUp({required String email, required String password, Map<String, dynamic>? data}) =>
      _authCall('/auth/signup', {'email': email, 'password': password, 'name': data?['name']}, AuthChangeEvent.signedIn);

  Future<AuthResponse> signInWithPassword({required String email, required String password}) =>
      _authCall('/auth/login', {'email': email, 'password': password}, AuthChangeEvent.signedIn);

  Future<void> signOut() => _setSession(null, AuthChangeEvent.signedOut);

  /// کد ورود یک‌بارمصرفی که پس از ورود با فیسبوک/ایکس برگشته را به نشست تبدیل می‌کند.
  Future<AuthResponse> exchangeOAuthCode(String code) => _authCall('/auth/oauth/exchange', {'code': code}, AuthChangeEvent.signedIn);

  /// افزودن ایمیل واقعی به حساب بی‌ایمیل (شماره/اپل) — نشست با ایمیل تازه نو می‌شود
  Future<AuthResponse> setAccountEmail(String email) => _authCall('/auth/set-email', {'email': email}, AuthChangeEvent.userUpdated);

  /// ورود بومی اپل (iOS): identityToken به سرور می‌رود و آن‌جا با کلیدهای اپل بررسی می‌شود.
  Future<AuthResponse> appleNativeSignIn(String identityToken, String name) =>
      _authCall('/auth/apple/native', {'identity_token': identityToken, 'name': name}, AuthChangeEvent.signedIn);

  /// کدام روش‌های ورود اجتماعی روی سرور فعال‌اند
  Future<Map<String, bool>> oauthProviders() async {
    try {
      final res = await http.get(Uri.parse('${_b.baseUrl}/auth/oauth/providers')).timeout(const Duration(seconds: 12));
      final j = jsonDecode(res.body);
      if (j is Map) return {for (final e in j.entries) e.key.toString(): e.value == true};
    } catch (_) {}
    return const {};
  }

  String oauthStartUrl(String provider, String redirect) =>
      '${_b.baseUrl}/auth/oauth/$provider/start?redirect=${Uri.encodeComponent(redirect)}';

  Future<AuthResponse> updateUser(UserAttributes attrs) async {
    if (_session == null) throw const AuthException('Auth session missing');
    return _authCall('/auth/update', {'password': attrs.password}, AuthChangeEvent.userUpdated);
  }

  /// بدون سرویس ایمیل: درخواست برای مدیر ثبت می‌شود و مدیر یک کد ۸ رقمی می‌سازد.
  /// درخواست کد بازیابی. خروجی: «email» اگر کد به ایمیل فرستاده شد، «admin» اگر
  /// مدیر باید کد را بسازد (وقتی ایمیل روی سرور تنظیم نشده).
  Future<String> resetPasswordForEmail(String email, {String? redirectTo}) async {
    try {
      final data = await _b.post('/auth/recover', {'email': email});
      return (data is Map && data['via'] == 'email') ? 'email' : 'admin';
    } on HzHttpException catch (e) {
      throw AuthException(e.message, statusCode: e.status);
    }
  }

  Future<AuthResponse> verifyOTP({required OtpType type, required String email, required String token}) =>
      _authCall('/auth/verify-recovery', {'email': email, 'token': token}, AuthChangeEvent.passwordRecovery);
}

// =====================================================================
// فایل‌ها (R2)
// =====================================================================

class FileOptions {
  final bool upsert;
  final String? contentType;
  const FileOptions({this.upsert = false, this.contentType});
}

class HzStorage {
  HzStorage._(this._b);
  final HzBackend _b;
  HzBucket from(String bucket) => HzBucket._(_b, bucket);
}

class HzBucket {
  HzBucket._(this._b, this.bucket);
  final HzBackend _b;
  final String bucket;

  Uri _uri(String path) => Uri.parse('${_b.baseUrl}/storage/$bucket/${Uri.encodeComponent(path).replaceAll('%2F', '/')}');

  String getPublicUrl(String path) => '${_b.baseUrl}/media/$bucket/${Uri.encodeComponent(path).replaceAll('%2F', '/')}';

  Future<String> uploadBinary(String path, Uint8List bytes, {FileOptions fileOptions = const FileOptions()}) async {
    final res = await _b._http
        .put(_uri(path), headers: {
          ..._b._headers(json: false),
          'content-type': fileOptions.contentType ?? 'application/octet-stream',
        }, body: bytes)
        .timeout(const Duration(minutes: 10));
    _b._decode(res);
    return '$bucket/$path';
  }

  /// آپلود جریانی از فایل روی دیسک (موبایل) تا ویدیوهای بزرگ یکجا در حافظه بارگذاری نشوند.
  Future<String> upload(String path, File file, {FileOptions fileOptions = const FileOptions()}) async {
    final req = http.StreamedRequest('PUT', _uri(path));
    req.headers.addAll(_b._headers(json: false));
    req.headers['content-type'] = fileOptions.contentType ?? _guessType(path);
    req.contentLength = await file.length();
    unawaited(file.openRead().listen(req.sink.add, onDone: req.sink.close, onError: req.sink.addError).asFuture<void>());
    final streamed = await _b._http.send(req).timeout(const Duration(minutes: 10));
    _b._decode(await http.Response.fromStream(streamed));
    return '$bucket/$path';
  }

  static String _guessType(String path) {
    final ext = path.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'gif': 'image/gif', 'webp': 'image/webp',
      'heic': 'image/heic', 'mp4': 'video/mp4', 'mov': 'video/quicktime', 'webm': 'video/webm', 'm4v': 'video/mp4',
    };
    return map[ext] ?? 'application/octet-stream';
  }
}

// =====================================================================
// توابع سرور (دستیار هوشمند، حذف حساب)
// =====================================================================

class FunctionResponse {
  final dynamic data;
  final int status;
  const FunctionResponse({this.data, this.status = 200});
}

class FunctionException implements Exception {
  final int status;
  final dynamic details;
  const FunctionException({required this.status, this.details});
}

class HzFunctions {
  HzFunctions._(this._b);
  final HzBackend _b;

  Future<FunctionResponse> invoke(String name, {Map<String, dynamic>? body}) async {
    try {
      final data = await _b.post('/functions/$name', body ?? const {});
      return FunctionResponse(data: data);
    } on HzHttpException catch (e) {
      throw FunctionException(status: e.status, details: e.details is Map && e.details['error'] is Map ? {'error': e.details['error']['message']} : e.details);
    }
  }
}
