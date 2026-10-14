import '../models/models.dart';

/// همان ۱۱ بخش هزاره‌نامه + «روایت امروز»، با فیلدهای قابل‌ویرایش هرکدام
/// (دقیقاً معادل SECTIONS + FIELD_MAP در دموی وب).
const List<ContentSection> kSections = [
  ContentSection(
    id: 'dailyStory',
    title: 'روایت امروز',
    description: 'کارت‌های چرخشی صفحه‌ی نخست',
    group: '',
    kind: SectionKind.stories,
    fields: [
      ContentFieldSpec('date', 'برچسب تاریخ'),
      ContentFieldSpec('title', 'عنوان'),
      ContentFieldSpec('desc', 'توضیح کوتاه', multiline: true),
      ContentFieldSpec('full', 'متن کامل', multiline: true),
    ],
  ),
  ContentSection(
    id: 'identity',
    title: 'هویت و تاریخچه',
    description: '۱۳ فصل مستند، از خاستگاه تا امروز',
    group: 'history',
    kind: SectionKind.timeline,
    fields: [
      ContentFieldSpec('era', 'عنوان دوره'),
      ContentFieldSpec('text', 'خلاصه', multiline: true),
      ContentFieldSpec('full', 'متن کامل', multiline: true),
    ],
  ),
  ContentSection(
    id: 'figures',
    title: 'شخصیت‌های برجسته',
    description: '۲۰ چهره‌ی سیاسی، علمی، هنری و ورزشی',
    group: 'history',
    kind: SectionKind.people,
    fields: [
      ContentFieldSpec('name', 'نام'),
      ContentFieldSpec('field', 'شرح کوتاه', multiline: true),
      ContentFieldSpec('category', 'حوزه‌ی فعالیت'),
      ContentFieldSpec('bio', 'زندگی‌نامه‌ی کامل', multiline: true),
    ],
  ),
  ContentSection(
    id: 'genocide',
    title: 'نسل‌کشی هزاره‌ها در تاریخ',
    description: '۵۳ رویداد مستند، از ۱۸۸۸ تا امروز',
    group: 'history',
    kind: SectionKind.incidents,
    fields: [
      ContentFieldSpec('date', 'تاریخ'),
      ContentFieldSpec('title', 'عنوان رویداد'),
      ContentFieldSpec('location', 'محل'),
      ContentFieldSpec('attacker', 'عامل'),
      ContentFieldSpec('deaths', 'تلفات'),
      ContentFieldSpec('text', 'شرح کوتاه (برای کارت فهرست)', multiline: true),
      ContentFieldSpec('full', 'شرح کامل و تفصیلی (برای صفحه‌ی جزئیات)', multiline: true),
    ],
  ),
  ContentSection(
    id: 'culture',
    title: 'فرهنگ و زندگی',
    description: 'آیین‌ها، خوراک، پوشاک و رسوم مردم هزاره',
    group: 'culture',
    kind: SectionKind.grid,
    fields: [
      ContentFieldSpec('name', 'عنوان'),
      ContentFieldSpec('note', 'توضیح کوتاه (برای کارت)', multiline: true),
      ContentFieldSpec('full', 'شرح کامل و تفصیلی (برای صفحه‌ی جزئیات)', multiline: true),
    ],
  ),
  ContentSection(
    id: 'music',
    title: 'موسیقی و شعر',
    description: 'گالری هنرمندان و ویدیوهای دمبوره، فلک و کلام دل',
    group: 'culture',
    kind: SectionKind.artists,
    fields: [],
  ),
  ContentSection(
    id: 'language',
    title: 'زبان و گویش هزارگی',
    description: 'بیش از ۲۰۰۰ واژه‌ی هزارگی با جست‌وجو، الفبا و واژه‌ی روز',
    group: 'culture',
    kind: SectionKind.dictionary,
    fields: [
      ContentFieldSpec('hazaragi', 'واژه هزارگی'),
      ContentFieldSpec('fa', 'معنی فارسی'),
      ContentFieldSpec('en', 'معنی انگلیسی'),
      ContentFieldSpec('cat', 'دسته (مثلاً: خانواده و خویشاوندی)'),
      ContentFieldSpec('tr', 'آوانویسی لاتین (اختیاری)'),
      ContentFieldSpec('example', 'نمونه‌ی کاربرد به هزارگی (اختیاری)'),
      ContentFieldSpec('example_fa', 'معنی نمونه (اختیاری)'),
      ContentFieldSpec('note', 'توضیح (اختیاری)', multiline: true),
      ContentFieldSpec('src', 'منبع (اختیاری)'),
    ],
  ),
  ContentSection(
    id: 'map',
    title: 'نقشه‌ی هزارستان',
    description: 'پراکندگی جغرافیایی مردم هزاره',
    group: 'resources',
    kind: SectionKind.regions,
    fields: [
      ContentFieldSpec('name', 'نام منطقه'),
      ContentFieldSpec('note', 'توضیح کوتاه', multiline: true),
      ContentFieldSpec('full', 'متن کامل و منابع (اختیاری)', multiline: true),
    ],
  ),
  ContentSection(
    id: 'album',
    title: 'آلبوم عکس',
    description: 'تصاویر و مستندات دیداری',
    group: 'resources',
    kind: SectionKind.photos,
    fields: [
      ContentFieldSpec('caption', 'عنوان تصویر'),
      ContentFieldSpec('desc', 'توضیح (اختیاری)', multiline: true),
    ],
  ),
  ContentSection(
    id: 'news',
    title: 'خبرنامه و رویدادها',
    description: 'تازه‌ترین رویدادهای روز',
    group: 'resources',
    kind: SectionKind.news,
    fields: [
      ContentFieldSpec('title', 'عنوان خبر'),
      ContentFieldSpec('date', 'تاریخ'),
      ContentFieldSpec('source', 'منبع خبر (نام رسانه)'),
      ContentFieldSpec('snippet', 'خلاصه (روی کارت خبر دیده می‌شود)', multiline: true),
      ContentFieldSpec('body', 'متن کامل خبر (اختیاری — در صفحه‌ی جزئیات)', multiline: true),
      ContentFieldSpec('url', 'لینک خبر در منبع (اختیاری)'),
    ],
  ),
  ContentSection(
    id: 'library',
    title: 'کتابخانه‌ی دیجیتال',
    description: 'منابع تاریخی، پژوهشی و ادبی',
    group: 'resources',
    kind: SectionKind.books,
    fields: [
      ContentFieldSpec('title', 'عنوان اثر'),
      ContentFieldSpec('author', 'نویسنده'),
      ContentFieldSpec('tag', 'دسته‌بندی'),
      ContentFieldSpec('note', 'معرفی کتاب', multiline: true),
      ContentFieldSpec('year', 'سال نشر'),
      ContentFieldSpec('lang', 'زبان'),
      ContentFieldSpec('read_url', 'لینک خواندن آنلاین (اختیاری)'),
      ContentFieldSpec('buy_url', 'لینک خرید یا صفحه‌ی ناشر (اختیاری)'),
      ContentFieldSpec('file_url', 'فایل PDF برای دانلود داخل اپ (فقط آثار آزاد یا با اجازه‌ی نویسنده)'),
    ],
  ),
  ContentSection(
    id: 'oral',
    title: 'حافظه‌ی جمعی',
    description: 'روایت‌های شفاهی نسل‌ها — فید اجتماعی',
    group: 'resources',
    kind: SectionKind.social,
    fields: [],
  ),
  ContentSection(
    id: 'articleWinners',
    title: 'برگزیدگان مسابقه‌ی مقالات',
    description: 'سه مقاله‌ی برتر هر دوره — با نظر، ریپلای و ایموجی',
    group: 'resources',
    kind: SectionKind.contestWinners,
    fields: [],
  ),
];

ContentSection sectionById(String id) =>
    kSections.firstWhere((s) => s.id == id);

const List<String> kGroupOrder = ['history', 'culture', 'resources'];
const Map<String, String> kGroupLabel = {
  'history': 'هویت و تاریخ',
  'culture': 'فرهنگ و هنر',
  'resources': 'منابع و مستندات',
};
