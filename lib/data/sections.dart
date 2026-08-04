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
    description: '۱۰ فصل مستند، از خاستگاه تا امروز',
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
    description: '۴۳ رویداد مستند، از ۱۸۹۰ تا امروز',
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
    description: 'آیین‌ها، خوراک و پوشاک',
    group: 'culture',
    kind: SectionKind.grid,
    fields: [
      ContentFieldSpec('name', 'عنوان'),
      ContentFieldSpec('note', 'توضیح', multiline: true),
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
    description: 'واژه‌ها و اصطلاحات زنده',
    group: 'culture',
    kind: SectionKind.dictionary,
    fields: [
      ContentFieldSpec('hazaragi', 'واژه هزارگی'),
      ContentFieldSpec('fa', 'معنی فارسی'),
      ContentFieldSpec('en', 'معنی انگلیسی'),
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
      ContentFieldSpec('note', 'توضیح', multiline: true),
    ],
  ),
  ContentSection(
    id: 'album',
    title: 'آلبوم عکس',
    description: 'تصاویر و مستندات دیداری',
    group: 'resources',
    kind: SectionKind.photos,
    fields: [ContentFieldSpec('caption', 'عنوان تصویر')],
  ),
  ContentSection(
    id: 'news',
    title: 'خبرنامه و رویدادها',
    description: 'تازه‌ترین رویدادهای روز',
    group: 'resources',
    kind: SectionKind.news,
    fields: [
      ContentFieldSpec('date', 'تاریخ'),
      ContentFieldSpec('title', 'عنوان خبر'),
      ContentFieldSpec('snippet', 'خلاصه', multiline: true),
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
