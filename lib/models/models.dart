/// نقش کاربر
enum UserRole { admin, editor, user }

/// وضعیت حساب — ثبت‌نام همیشه خودکار «فعال» است؛
/// مسدودسازی فقط ابزار نظارتی مدیر برای تخلف است.
enum UserStatus { active, blocked }

UserRole roleFromString(String s) {
  switch (s) {
    case 'admin':
      return UserRole.admin;
    case 'editor':
      return UserRole.editor;
    default:
      return UserRole.user;
  }
}

String roleLabel(UserRole r) {
  switch (r) {
    case UserRole.admin:
      return 'مدیر';
    case UserRole.editor:
      return 'ویراستار';
    case UserRole.user:
      return 'کاربر';
  }
}

String roleToDbValue(UserRole r) {
  switch (r) {
    case UserRole.admin:
      return 'admin';
    case UserRole.editor:
      return 'editor';
    case UserRole.user:
      return 'user';
  }
}

/// مدل کاربر — هم برای حساب لاگین‌شده و هم برای فهرست کاربران در پنل مدیریت.
class UserProfile {
  final String id;
  String name;
  final String email;
  UserRole role;
  UserStatus status;
  String? avatarPath; // مسیر فایل محلی عکس پروفایل (بعداً: avatar_url در Supabase Storage)
  String country;
  String originProvince;
  String district;
  String tribe;
  String nativeLanguage;
  String bio;
  String joined; // برچسب نمایشی تاریخ عضویت (بعداً: created_at واقعی)
  /// حسابی که با اپل/فیسبوک/شماره ساخته شده و هنوز پروفایل و شرایط را تکمیل نکرده
  bool needsCompletion;

  /// ایمیل داخلی (حساب‌های بی‌ایمیل مثل شماره‌ی تلفن)؛ کاربر می‌تواند ایمیل واقعی بیفزاید
  bool get hasPlaceholderEmail => email.endsWith('@users.hazaranama.com');

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.role = UserRole.user,
    this.status = UserStatus.active,
    this.avatarPath,
    this.country = 'نامشخص',
    this.originProvince = 'نامشخص',
    this.district = 'نامشخص',
    this.tribe = '—',
    this.nativeLanguage = 'نامشخص',
    this.bio = '',
    this.joined = 'امروز',
    this.needsCompletion = false,
  });

  /// کلیدی که پست‌ها/نظرها با آن به این کاربر نسبت داده می‌شوند
  /// (در Supabase واقعی، همان author_id = id خواهد بود).
  String get authorKey => name;
}

/// نوع یک ردیف در تاریخچه‌ی فعالیت کاربر (از ویوی user_activity_log).
enum UserActivityType {
  post,
  postComment,
  videoComment,
  articleSubmission,
  articleComment,
  donationTransfer,
  contactMessage,
  postReaction,
  videoReaction,
  articleReaction,
  commentLike,
}

UserActivityType userActivityTypeFromString(String s) {
  switch (s) {
    case 'post':
      return UserActivityType.post;
    case 'post_comment':
      return UserActivityType.postComment;
    case 'video_comment':
      return UserActivityType.videoComment;
    case 'article_submission':
      return UserActivityType.articleSubmission;
    case 'article_comment':
      return UserActivityType.articleComment;
    case 'donation_transfer':
      return UserActivityType.donationTransfer;
    case 'contact_message':
      return UserActivityType.contactMessage;
    case 'post_reaction':
      return UserActivityType.postReaction;
    case 'video_reaction':
      return UserActivityType.videoReaction;
    case 'article_reaction':
      return UserActivityType.articleReaction;
    default:
      return UserActivityType.commentLike;
  }
}

String userActivityTypeLabel(UserActivityType t) {
  switch (t) {
    case UserActivityType.post:
      return 'پست تازه در حافظه‌ی جمعی';
    case UserActivityType.postComment:
      return 'نظر روی یک پست';
    case UserActivityType.videoComment:
      return 'نظر روی یک ویدیو';
    case UserActivityType.articleSubmission:
      return 'ارسال مقاله برای مسابقه';
    case UserActivityType.articleComment:
      return 'نظر روی یک مقاله‌ی برگزیده';
    case UserActivityType.donationTransfer:
      return 'اعلام حمایت مالی';
    case UserActivityType.contactMessage:
      return 'پیام به پشتیبانی';
    case UserActivityType.postReaction:
      return 'واکنش روی یک پست';
    case UserActivityType.videoReaction:
      return 'واکنش روی یک ویدیو';
    case UserActivityType.articleReaction:
      return 'واکنش روی یک مقاله';
    case UserActivityType.commentLike:
      return 'لایک یک نظر';
  }
}

/// یک ردیف در تاریخچه‌ی فعالیت یک کاربر — از ویوی user_activity_log که
/// همه‌ی کارهای او (پست، کامنت، واکنش، مقاله، حواله، پیام) را یکجا می‌آورد.
class UserActivityEntry {
  final String userId;
  final UserActivityType type;
  final String refId;
  final String summary;
  final DateTime occurredAt;

  UserActivityEntry({
    required this.userId,
    required this.type,
    required this.refId,
    required this.summary,
    required this.occurredAt,
  });
}

/// یک بخش از هزاره‌نامه (هویت، شخصیت‌ها، نسل‌کشی، فرهنگ، …)
enum SectionKind {
  timeline, // هویت و تاریخچه
  people, // شخصیت‌های برجسته
  incidents, // نسل‌کشی هزاره‌ها
  grid, // فرهنگ و زندگی
  tracks, // (قدیمی — دیگر استفاده نمی‌شود، برای سازگاری نگه داشته شده)
  dictionary, // زبان و گویش
  regions, // نقشه‌ی هزارستان
  photos, // آلبوم عکس
  news, // خبرنامه
  books, // کتابخانه‌ی دیجیتال
  stories, // روایت امروز (صفحه‌ی نخست)
  social, // حافظه‌ی جمعی (از posts/comments می‌آید، نه content_items)
  artists, // موسیقی و شعر — گالری هنرمندان و ویدیو (از artists/artist_videos می‌آید)
  contestWinners, // برگزیدگان مسابقه‌ی مقالات (از featured_articles می‌آید)
}

class ContentSection {
  final String id;
  final String title;
  final String description;
  final String group; // 'history' | 'culture' | 'resources' | ''
  final SectionKind kind;
  final List<ContentFieldSpec> fields; // برای فرم افزودن/ویرایش در پنل مدیریت

  const ContentSection({
    required this.id,
    required this.title,
    required this.description,
    required this.group,
    required this.kind,
    required this.fields,
  });
}

/// تعریف یک فیلد قابل‌ویرایش برای فرم پویا در پنل مدیریت
/// (معادل FIELD_MAP در دموی وب)
class ContentFieldSpec {
  final String key;
  final String label;
  final bool multiline;
  const ContentFieldSpec(this.key, this.label, {this.multiline = false});
}

/// یک آیتم محتوا درون یک بخش. چون هر بخش فیلدهای متفاوتی دارد،
/// از یک Map پویا استفاده می‌کنیم — دقیقاً مثل ستون jsonb در Supabase.
class ContentItem {
  final String id;
  final Map<String, dynamic> fields;
  double? mapX; // فقط برای kind == regions
  double? mapY;
  String? imageUrl; // عکس اختیاری این آیتم (ستون image_url در Supabase)
  String? videoUrl; // لینک ویدیوی اختیاری این آیتم (ستون video_url در Supabase)

  ContentItem({required this.id, required this.fields, this.mapX, this.mapY, this.imageUrl, this.videoUrl});

  dynamic operator [](String key) => fields[key];
  void operator []=(String key, dynamic value) => fields[key] = value;

  String _s(String k) => (fields[k] ?? '').toString().trim();

  /// اعتبار عکس (نام عکاس و مجوز) — برای عکس‌های Wikimedia Commons و مانند آن
  String get imageCredit => _s('img_credit');

  /// صفحه‌ی اصلی عکس (مثلاً صفحه‌ی فایل در Commons)
  String get imagePage => _s('img_page');

  /// لینک‌های بیرونی آیتم: [(برچسب، نشانی)] — خواندن، خرید، منبع خبر…
  List<(String, String)> get links {
    final out = <(String, String)>[];
    void add(String key, String label) {
      final u = _s(key);
      if (u.startsWith('http')) out.add((_s('${key}_label').isNotEmpty ? _s('${key}_label') : label, u));
    }
    add('read_url', 'خواندن آنلاین');
    add('buy_url', 'خرید / صفحه‌ی ناشر');
    add('url', 'خواندن کامل خبر');
    add('src_url', 'دیدن منبع');
    return out;
  }
}

/// یک پیام «تماس با ما» از یک کاربر به مدیر
enum MessageStatus { newMsg, read, replied }

MessageStatus messageStatusFromString(String s) {
  switch (s) {
    case 'replied':
      return MessageStatus.replied;
    case 'read':
      return MessageStatus.read;
    default:
      return MessageStatus.newMsg;
  }
}

String messageStatusLabel(MessageStatus s) {
  switch (s) {
    case MessageStatus.replied:
      return 'پاسخ داده‌شده';
    case MessageStatus.read:
      return 'خوانده‌شده';
    case MessageStatus.newMsg:
      return 'تازه';
  }
}

class ContactMessage {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String userCountry;
  final String userOriginProvince;
  final String? userAvatar;
  final String message;
  final MessageStatus status;
  final String? adminReply;
  final String createdAtLabel;

  ContactMessage({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userCountry,
    required this.userOriginProvince,
    this.userAvatar,
    required this.message,
    required this.status,
    this.adminReply,
    required this.createdAtLabel,
  });
}

/// یک گزارش کاربر درباره‌ی محتوا یا کاربر دیگر (پست، کامنت یا پروفایل) —
/// بخش «گزارش‌ها»ی پنل مدیریت این‌ها را برای بررسی/اقدام فهرست می‌کند.
/// این الزام گوگل‌پلی/اپل برای محتوای کاربرساخته است: راهی برای گزارش‌دادن
/// محتوای نامناسب که تیم اپ بتواند رسیدگی کند.
class ContentReport {
  final String id;
  final String reporterId;
  final String reporterName;
  final String targetType; // post | comment | user
  final String targetId;
  final String? targetOwnerId;
  final String? targetPreview;
  final String reason;
  final String? note;
  final String status; // pending | reviewed | dismissed
  final String createdAtLabel;

  ContentReport({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.targetType,
    required this.targetId,
    this.targetOwnerId,
    this.targetPreview,
    required this.reason,
    this.note,
    required this.status,
    required this.createdAtLabel,
  });
}

/// یک کاربر که شما مسدودش کرده‌اید — دیگر پست/کامنتش را در فید نمی‌بینید.
/// جدا از مسدودسازی سراسری ادمین (UserStatus.blocked روی کل حساب).
class BlockedUser {
  final String id; // شناسه‌ی ردیف blocked_users (برای لغو مسدودی)
  final String blockedId;
  final String blockedName;
  final String? blockedAvatarUrl;
  final String createdAtLabel;

  BlockedUser({
    required this.id,
    required this.blockedId,
    required this.blockedName,
    this.blockedAvatarUrl,
    required this.createdAtLabel,
  });
}

/// یک پست در «حافظه‌ی جمعی» — فید اجتماعی به سبک اینستاگرام/فیسبوک: متن،
/// عکس (چندتایی) یا یک ویدیو، شمارنده‌ی سبک نظرها (خودِ نظرها جدا لود می‌شوند)،
/// و واکنش‌های ایموجی (که ❤️ نقش «لایک» را بازی می‌کند).
class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  String text;
  List<String> imageUrls;
  String? videoUrl;
  String? videoThumbnailUrl;
  final DateTime createdAt;
  final String createdAtLabel;
  final Map<String, int> reactions; // emoji -> count
  final Map<String, bool> myReactions; // emoji -> آیا خودم زده‌ام
  int commentsCount;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.text,
    List<String>? imageUrls,
    this.videoUrl,
    this.videoThumbnailUrl,
    required this.createdAt,
    this.createdAtLabel = '',
    Map<String, int>? reactions,
    Map<String, bool>? myReactions,
    this.commentsCount = 0,
  })  : imageUrls = imageUrls ?? [],
        reactions = reactions ?? {},
        myReactions = myReactions ?? {};

  String get authorInitial => authorName.isNotEmpty ? authorName[0] : '؟';
  int get totalReactions => reactions.values.fold(0, (a, b) => a + b);
  bool get likedByMe => myReactions['❤️'] ?? false;
  bool get hasImages => imageUrls.isNotEmpty;
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasMedia => hasImages || hasVideo;
}

/// یک نظر (یا ریپلای، اگر parentId مقدار داشته باشد) زیر یک پست — هم‌خانواده‌ی
/// VideoComment/ArticleComment، به‌علاوه‌ی لایک روی خودِ نظر.
class PostComment {
  final String id;
  final String postId;
  final String? parentId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String text;
  final String createdAtLabel;
  final List<PostComment> replies;
  int likeCount;
  bool likedByMe;

  PostComment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.text,
    required this.createdAtLabel,
    List<PostComment>? replies,
    this.likeCount = 0,
    this.likedByMe = false,
  }) : replies = replies ?? [];
}

/// یک هنرمند/خواننده در گالری «موسیقی و شعر» — با آواتار، کاور و بیوگرافی،
/// و مجموعه‌ای از ویدیوهای قابل‌پخش در خود اپ.
class Artist {
  final String id;
  String name;
  String bio;
  String? avatarUrl;
  String? coverUrl;
  int videoCount; // فقط برای نمایش در کارت گالری؛ از سرور شمرده می‌شود
  String category; // گروه گالری (مثلاً «اساتید و پیشکسوتان…»)
  String imageCredit; // نام عکاس و مجوز (عکس‌های Wikimedia Commons)
  String imagePage;

  Artist({
    required this.id,
    required this.name,
    this.bio = '',
    this.avatarUrl,
    this.coverUrl,
    this.videoCount = 0,
    this.category = '',
    this.imageCredit = '',
    this.imagePage = '',
  });
}

/// یک ویدیوی موسیقی/شعر متعلق به یک هنرمند — قابل‌پخش در خود اپ،
/// با شمارنده‌ی بازدید واقعی.
class ArtistVideo {
  final String id;
  final String artistId;
  String title;
  String description;
  final String videoUrl;
  String? thumbnailUrl;
  int viewsCount;
  final String createdAtLabel;

  ArtistVideo({
    required this.id,
    required this.artistId,
    required this.title,
    this.description = '',
    required this.videoUrl,
    this.thumbnailUrl,
    this.viewsCount = 0,
    this.createdAtLabel = '',
  });
}

/// یک کامنت (یا ریپلای، اگر parentId مقدار داشته باشد) زیر یک ویدیو —
/// دقیقاً مثل بخش نظرهای یوتیوب.
class VideoComment {
  final String id;
  final String videoId;
  final String? parentId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String text;
  final String createdAtLabel;
  final List<VideoComment> replies;

  VideoComment({
    required this.id,
    required this.videoId,
    this.parentId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.text,
    required this.createdAtLabel,
    List<VideoComment>? replies,
  }) : replies = replies ?? [];
}

/// وضعیت یک مقاله‌ی ارسالی در مسابقه‌ی مقالات.
enum ArticleStatus { active, closed, disqualified, published }

ArticleStatus articleStatusFromString(String s) {
  switch (s) {
    case 'closed':
      return ArticleStatus.closed;
    case 'disqualified':
      return ArticleStatus.disqualified;
    case 'published':
      return ArticleStatus.published;
    default:
      return ArticleStatus.active;
  }
}

/// نتیجه‌ی کمکیِ بررسی اصالت متن توسط هوش مصنوعی — هیچ‌وقت حکم قطعی نیست،
/// فقط برای کمک به تصمیم مدیر ذخیره می‌شود.
enum AiArticleVerdict { none, original, suspicious, likelyAiOrCopied }

AiArticleVerdict aiVerdictFromString(String? s) {
  switch (s) {
    case 'original':
      return AiArticleVerdict.original;
    case 'suspicious':
      return AiArticleVerdict.suspicious;
    case 'likely_ai_or_copied':
      return AiArticleVerdict.likelyAiOrCopied;
    default:
      return AiArticleVerdict.none;
  }
}

/// تنظیمات مشترکِ دوره‌ی فعلی مسابقه‌ی مقالات — یک رکورد تکی که مدیر از پنل
/// مدیریت ویرایش می‌کند: عنوان/موضوعی که همه‌ی شرکت‌کنندگان باید روی همان
/// بنویسند (به‌جای انتخاب عنوان دلخواه)، جایزه‌ی سه مقام برتر همین دوره، و
/// تاریخ آغاز دوره — که کل زمان‌بندی مسابقه از روی همان محاسبه می‌شود:
/// ۲۸ روز اول برای ارسال مقاله (و پس از آن، لحظه‌ی رتبه‌بندی خودکار)، و
/// ۲ روز آخر برای اینکه کاربران برگزیدگان را بخوانند و نظر بدهند.
class ContestSettings {
  String topic;
  String? prizeFirst;
  String? prizeSecond;
  String? prizeThird;
  DateTime? roundStartedAt;

  ContestSettings({
    required this.topic,
    this.prizeFirst,
    this.prizeSecond,
    this.prizeThird,
    this.roundStartedAt,
  });

  static const submissionDays = 28;
  static const totalRoundDays = 30;

  bool get hasActiveRound => roundStartedAt != null;

  /// روز ۲۸: پایان مهلت ارسال مقاله، و لحظه‌ای که رتبه‌بندی باید انجام شود.
  DateTime? get submissionDeadline => roundStartedAt?.add(const Duration(days: submissionDays));

  /// روز ۳۰: پایان کامل دوره (شامل ۲ روز نمایش/نظردهی روی برگزیدگان).
  DateTime? get roundEndsAt => roundStartedAt?.add(const Duration(days: totalRoundDays));

  bool get submissionsOpen => hasActiveRound && DateTime.now().isBefore(submissionDeadline!);

  /// یعنی مهلت ارسال تمام شده و باید رتبه‌بندی (با هوش مصنوعی) اجرا شود.
  bool get rankingDue => hasActiveRound && !submissionsOpen;

  Duration get timeUntilDeadline {
    if (!hasActiveRound) return Duration.zero;
    final d = submissionDeadline!.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }
}

/// یک مقاله‌ی ارسالی کاربر در مسابقه‌ی مقالات — تا وقتی منتشر نشود،
/// فقط خودِ نویسنده و مدیر آن را می‌بینند.
class ArticleSubmission {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  String title;
  String body;
  ArticleStatus status;
  AiArticleVerdict aiVerdict;
  double? aiConfidence;
  // نمره‌ی کیفیت محتوا/نگارش که هوش مصنوعی می‌دهد (۰ تا ۱۰۰)، جدا از اصالت؛
  // مبنای رتبه‌بندی خودکار برای انتخاب سه مقام برتر.
  double? aiQualityScore;
  String? aiNotes;
  final DateTime submittedAt;
  // اگر این مقاله به‌عنوان برگزیده منتشر شده باشد، رتبه‌اش اینجا پر می‌شود
  // (از جدول featured_articles خوانده می‌شود، نه ستونی روی خودِ این جدول).
  int? placement;

  ArticleSubmission({
    required this.id,
    required this.authorId,
    this.authorName = '',
    this.authorAvatar,
    required this.title,
    required this.body,
    required this.status,
    this.aiVerdict = AiArticleVerdict.none,
    this.aiConfidence,
    this.aiQualityScore,
    this.aiNotes,
    required this.submittedAt,
    this.placement,
  });
  // توجه: دوره‌ی داوری دیگر جداگانه برای هر مقاله محاسبه نمی‌شود — همه‌ی
  // مقالات یک دوره‌ی مشترک دارند که از ContestSettings.roundStartedAt
  // خوانده می‌شود (نگاه کنید به ContestSettings در همین فایل).
}

/// یکی از سه مقاله‌ی برتر منتشرشده‌ی هر دوره — عمومی، با کامنت/ریپلای/ایموجی.
class FeaturedArticle {
  final String id;
  final String? submissionId;
  final String? authorId;
  String authorName;
  String? authorAvatar;
  String title;
  String body;
  int placement; // ۱ تا ۳
  String monthLabel;
  String? prize;
  final String publishedAtLabel;

  FeaturedArticle({
    required this.id,
    this.submissionId,
    this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.title,
    required this.body,
    required this.placement,
    required this.monthLabel,
    this.prize,
    this.publishedAtLabel = '',
  });
}

/// یک کامنت (یا ریپلای) زیر یک مقاله‌ی برگزیده — هم‌خانواده‌ی VideoComment.
class ArticleComment {
  final String id;
  final String articleId;
  final String? parentId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String text;
  final String createdAtLabel;
  final List<ArticleComment> replies;

  ArticleComment({
    required this.id,
    required this.articleId,
    this.parentId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.text,
    required this.createdAtLabel,
    List<ArticleComment>? replies,
  }) : replies = replies ?? [];
}

// ============================================================
// حمایت مالی از پروژه‌ی هزاره‌نامه (نه خیریه) — محتوا، زیرساخت، آموزش و آرشیو
// ============================================================

/// دسته‌بندی مصرف کمک مالی — هم برای دسته‌بندی حواله‌های ارسالی و هم برای
/// دسته‌بندی گزارش‌های شفافیت استفاده می‌شود.
enum DonationCategory { family, hospital, school, roadsBridges, general }

DonationCategory donationCategoryFromString(String? s) {
  switch (s) {
    case 'family':
      return DonationCategory.family;
    case 'hospital':
      return DonationCategory.hospital;
    case 'school':
      return DonationCategory.school;
    case 'roads':
      return DonationCategory.roadsBridges;
    default:
      return DonationCategory.general;
  }
}

String donationCategoryToDbValue(DonationCategory c) {
  switch (c) {
    case DonationCategory.family:
      return 'family';
    case DonationCategory.hospital:
      return 'hospital';
    case DonationCategory.school:
      return 'school';
    case DonationCategory.roadsBridges:
      return 'roads';
    case DonationCategory.general:
      return 'general';
  }
}

String donationCategoryLabel(DonationCategory c) {
  switch (c) {
    case DonationCategory.family:
      return 'محتوا و پژوهش';
    case DonationCategory.hospital:
      return 'سرور و زیرساخت';
    case DonationCategory.school:
      return 'آموزش و زبان هزارگی';
    case DonationCategory.roadsBridges:
      return 'آرشیو موسیقی و روایت‌ها';
    case DonationCategory.general:
      return 'توسعه‌ی عمومی هزاره‌نامه';
  }
}

/// وضعیت بررسی یک حواله‌ی ارسالی توسط مدیر.
enum DonationTransferStatus { pending, confirmed, rejected }

/// کانالی که کاربر از طریق آن کمک مالی فرستاده — چون خودِ پرداخت همیشه
/// بیرون از اپ انجام می‌شود، این فقط برای تفکیک نمایشی و آماری است.
enum DonationMethod { paypal, bankTransfer }

DonationMethod donationMethodFromString(String? s) => s == 'paypal' ? DonationMethod.paypal : DonationMethod.bankTransfer;

String donationMethodToDbValue(DonationMethod m) => m == DonationMethod.paypal ? 'paypal' : 'bank_transfer';

String donationMethodLabel(DonationMethod m) => m == DonationMethod.paypal ? 'پی‌پال' : 'حواله';

DonationTransferStatus donationTransferStatusFromString(String s) {
  switch (s) {
    case 'confirmed':
      return DonationTransferStatus.confirmed;
    case 'rejected':
      return DonationTransferStatus.rejected;
    default:
      return DonationTransferStatus.pending;
  }
}

/// اعلام یک حواله‌ی مالی (به‌روش سنتی/بانکی) توسط یک کاربر — چون خودِ حواله
/// بیرون از اپ انجام می‌شود، این رکورد فقط جزئیات ارسال‌کننده را برای تطبیق
/// و تأیید دستیِ مدیر نگه می‌دارد.
class DonationTransfer {
  final String id;
  final String userId;
  String senderName;
  String senderCountry;
  String? senderContact;
  double amount;
  String currency;
  String? transferReference;
  String? note;
  DonationCategory category;
  DonationTransferStatus status;
  DonationMethod method;
  final DateTime submittedAt;
  double? confirmedAmount;

  DonationTransfer({
    required this.id,
    required this.userId,
    required this.senderName,
    required this.senderCountry,
    this.senderContact,
    required this.amount,
    this.currency = 'USD',
    this.transferReference,
    this.note,
    this.category = DonationCategory.general,
    this.status = DonationTransferStatus.pending,
    this.method = DonationMethod.bankTransfer,
    required this.submittedAt,
    this.confirmedAmount,
  });
}

/// یک گزارش شفافیت — چگونگیِ مصرف واقعیِ بخشی از کمک‌های جمع‌شده، همراه با
/// عکس/ویدیوی مستند، تا کاربران به شفافیت مصرف کمک‌های خود اطمینان کنند.
class DonationReport {
  final String id;
  String title;
  DonationCategory category;
  String summary;
  String body;
  double? amountSpent;
  String currency;
  List<String> imageUrls;
  String? videoUrl;
  String? location;
  int? beneficiariesCount;
  final String publishedAtLabel;
  final DateTime publishedAt;

  DonationReport({
    required this.id,
    required this.title,
    this.category = DonationCategory.general,
    required this.summary,
    required this.body,
    this.amountSpent,
    this.currency = 'USD',
    List<String>? imageUrls,
    this.videoUrl,
    this.location,
    this.beneficiariesCount,
    this.publishedAtLabel = '',
    required this.publishedAt,
  }) : imageUrls = imageUrls ?? [];
}

/// آمار کلیِ کمپین کمک‌های مالی — چون پرداخت‌های PayPal بیرون از اپ و بدون
/// اتصال خودکار انجام می‌شوند، این عددها را مدیر از پنل مدیریت به‌روز نگه
/// می‌دارد تا کاربران روند و تأثیر واقعی کمک‌ها را ببینند.
class DonationSettings {
  double totalRaised;
  String currency;
  int familiesHelped;
  int projectsCompleted;
  DateTime? updatedAt;

  DonationSettings({
    this.totalRaised = 0,
    this.currency = 'USD',
    this.familiesHelped = 0,
    this.projectsCompleted = 0,
    this.updatedAt,
  });
}

/// یک ردیف در فهرست عمومیِ کمک‌کنندگان — جمعِ دلاریِ تقریبیِ کمک‌های
/// تأییدشده‌ی یک کاربر (از ویوی donor_leaderboard در Supabase).
class DonorRankEntry {
  final String userId;
  final String name;
  final String? avatarPath;
  final double totalUsd;
  final int donationCount;
  final DateTime? lastDonationAt;

  DonorRankEntry({
    required this.userId,
    required this.name,
    this.avatarPath,
    required this.totalUsd,
    required this.donationCount,
    this.lastDonationAt,
  });
}

/// یک اعلانِ درون‌اپی — از جدول notifications در Supabase؛ به‌صورت خودکار با
/// trigger روی رویدادهای مهم (کامنت/ریپلای، تأیید/رد کمک مالی، تغییر وضعیت
/// مقاله، برگزیده‌شدن مقاله، پاسخ پشتیبانی) برای کاربر مقصد ساخته می‌شود.
class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final String? refId;
  final String? refType;
  bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.refId,
    this.refType,
    this.isRead = false,
    required this.createdAt,
  });
}


/// مقصد یک اعلان — برای باز کردن صفحه‌ی مربوط با لمس اعلان یا پوش.
class NotificationTarget {
  final String type;
  final String? refType;
  final String? refId;
  const NotificationTarget({required this.type, this.refType, this.refId});
}


/// یک فایل قابل دانلود کتاب (یک جلد)
class BookFile {
  final String url;
  final String name;
  final int? size;
  const BookFile({required this.url, required this.name, this.size});
}
