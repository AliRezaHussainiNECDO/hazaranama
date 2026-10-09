-- ============================================================
-- هزاره‌نامه — طرح دیتابیس Supabase (Postgres)
-- این فایل را می‌توانید مستقیماً در Supabase SQL Editor اجرا کنید
-- یا بعداً از طریق Claude Code به‌عنوان مایگریشن اجرا کنید.
-- ============================================================

-- ------------------------------------------------------------
-- 0) افزونه‌های پایه
-- ------------------------------------------------------------
create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- 1) enum ها
-- ------------------------------------------------------------
create type user_role as enum ('admin', 'editor', 'user');
create type user_status as enum ('active', 'blocked');

-- ------------------------------------------------------------
-- 2) profiles
-- یک ردیف برای هر کاربر؛ به auth.users متصل است (که خودِ Supabase
-- می‌سازد). این جدول همان چیزی است که در UsersPage/UserDetailModal
-- در دمو نشان دادیم.
-- ------------------------------------------------------------
create table public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  name            text not null,
  email           text not null,  -- کپی از auth.users.email؛ چون کلاینت به auth.users دسترسی مستقیم ندارد
  avatar_url      text,
  role            user_role not null default 'user',
  status          user_status not null default 'active',   -- تأیید خودکار؛ فقط برای تخلف مسدود می‌شود
  country         text,        -- کشور محل سکونت فعلی (متنی، آزاد)
  origin_province text,        -- ولایت/منطقه‌ی اصلی نیاکان (متنی، آزاد)
  district        text,        -- ولسوالی (متنی، آزاد)
  tribe           text,        -- طایفه (اختیاری)
  native_language text,        -- هزارگی / دری / سایر
  bio             text,        -- یادداشت کوتاه درباره‌ی ریشه‌ها
  terms_accepted_at timestamptz,  -- زمان پذیرش شرایط و قوانین هنگام ثبت‌نام
  created_at      timestamptz not null default now()
);

-- هر کاربر تازه‌ثبت‌نام‌شده در auth.users باید خودکار یک profile بگیرد
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name, email, role, status)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.email,
    (case when new.email = 'alireza.necdo@gmail.com' then 'admin' else 'user' end)::user_role,
    'active'::user_status
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- نکته‌ی امنیتی مهم: سیاست RLS پایین‌تر به هر کاربر اجازه می‌دهد ردیف
-- profile خودش را ویرایش کند (برای تغییر نام/عکس/ریشه‌ها) — اما بدون این
-- تریگر، همان کاربر می‌توانست با یک درخواست مستقیم به API (نه از طریق
-- اپ) ستون role یا status خودش را هم تغییر بدهد. این تریگر آن راه را می‌بندد:
create function public.prevent_privilege_escalation()
returns trigger as $$
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') then
    new.role := old.role;
    new.status := old.status;
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger before_profile_update_guard
  before update on public.profiles
  for each row execute procedure public.prevent_privilege_escalation();

-- ------------------------------------------------------------
-- 3) sections
-- همان ۱۱ بخش ثابت هزاره‌نامه + روایت امروز، به‌عنوان مرجع.
-- خودِ ردیف‌های این جدول را ادمین معمولاً دستکاری نمی‌کند،
-- فقط محتوای داخل content_items را.
-- ------------------------------------------------------------
create table public.sections (
  id          text primary key,   -- 'identity' | 'figures' | 'genocide' | ... | 'dailyStory'
  title       text not null,
  description text,
  icon_name   text,               -- نام آیکون lucide-react برای رندر در فرانت‌اند
  group_name  text,               -- 'history' | 'culture' | 'resources' | null
  kind        text not null,      -- 'timeline' | 'people' | 'incidents' | 'grid' | 'tracks' | ...
  sort_order  int not null default 0
);

-- ------------------------------------------------------------
-- 4) content_items
-- محتوای واقعی هر بخش. چون هر بخش فیلدهای متفاوتی دارد (دقیقاً
-- مطابق FIELD_MAP در دمو)، از jsonb برای «fields» استفاده می‌کنیم
-- تا فرم‌های افزودن/ویرایش در پنل مدیریت پویا بمانند.
-- ------------------------------------------------------------
create table public.content_items (
  id          uuid primary key default uuid_generate_v4(),
  section_id  text not null references public.sections (id) on delete cascade,
  fields      jsonb not null default '{}'::jsonb,   -- مثلا: {"era": "...", "text": "...", "full": "..."}
  image_url   text,
  sort_order  int not null default 0,
  created_by  uuid references public.profiles (id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index idx_content_items_section on public.content_items (section_id, sort_order);
-- جست‌وجوی متنی سریع درون fields (برای بخش جستجوی سراسری اپ)
create index idx_content_items_fields_gin on public.content_items using gin (fields);

-- ------------------------------------------------------------
-- 5) posts / comments / reactions  →  «حافظه‌ی جمعی»
-- ------------------------------------------------------------
create table public.posts (
  id         uuid primary key default uuid_generate_v4(),
  author_id  uuid not null references public.profiles (id) on delete cascade,
  text       text not null,
  created_at timestamptz not null default now()
);

create table public.comments (
  id         uuid primary key default uuid_generate_v4(),
  post_id    uuid not null references public.posts (id) on delete cascade,
  author_id  uuid not null references public.profiles (id) on delete cascade,
  text       text not null,
  created_at timestamptz not null default now()
);

create table public.reactions (
  id         uuid primary key default uuid_generate_v4(),
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  emoji      text not null,               -- '❤️' | '👏' | '🙏' | '🔥' | '😢'
  created_at timestamptz not null default now(),
  unique (post_id, user_id, emoji)        -- هر کاربر برای هر ایموجی فقط یک‌بار روی هر پست
);

create index idx_comments_post on public.comments (post_id);
create index idx_reactions_post on public.reactions (post_id);

-- ------------------------------------------------------------
-- 6) Row Level Security — دقیقاً همان مدل «مدیر/کاربر» دمو
-- ------------------------------------------------------------
alter table public.profiles      enable row level security;
alter table public.sections      enable row level security;
alter table public.content_items enable row level security;
alter table public.posts         enable row level security;
alter table public.comments      enable row level security;
alter table public.reactions     enable row level security;

-- تابع کمکی: آیا کاربر جاری مدیر است؟
create function public.is_admin()
returns boolean as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$ language sql security definer stable;

-- profiles: همه می‌توانند فهرست عمومی را ببینند (نام/آواتار)،
-- ولی خودِ کاربر فقط پروفایل خودش را ویرایش می‌کند؛
-- تغییر role/status فقط با ادمین.
create policy "profiles_select_all" on public.profiles
  for select using (true);

create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

create policy "profiles_admin_full" on public.profiles
  for all using (public.is_admin());

-- sections: خواندن برای همه آزاد؛ نوشتن فقط ادمین
create policy "sections_select_all" on public.sections
  for select using (true);

create policy "sections_admin_write" on public.sections
  for insert with check (public.is_admin());
create policy "sections_admin_update" on public.sections
  for update using (public.is_admin());
create policy "sections_admin_delete" on public.sections
  for delete using (public.is_admin());

-- content_items: خواندن برای همه آزاد؛ نوشتن/ویرایش/حذف فقط ادمین
create policy "content_select_all" on public.content_items
  for select using (true);

create policy "content_admin_insert" on public.content_items
  for insert with check (public.is_admin());
create policy "content_admin_update" on public.content_items
  for update using (public.is_admin());
create policy "content_admin_delete" on public.content_items
  for delete using (public.is_admin());

-- posts: همه می‌خوانند؛ کاربر لاگین‌شده پست خودش را می‌سازد؛
-- خودش می‌تواند پاک کند، یا ادمین برای نظارت.
create policy "posts_select_all" on public.posts
  for select using (true);

create policy "posts_insert_own" on public.posts
  for insert with check (auth.uid() = author_id and
    (select status from public.profiles where id = auth.uid()) = 'active');

create policy "posts_delete_own_or_admin" on public.posts
  for delete using (auth.uid() = author_id or public.is_admin());

-- comments: مشابه posts
create policy "comments_select_all" on public.comments
  for select using (true);

create policy "comments_insert_own" on public.comments
  for insert with check (auth.uid() = author_id and
    (select status from public.profiles where id = auth.uid()) = 'active');

create policy "comments_delete_own_or_admin" on public.comments
  for delete using (auth.uid() = author_id or public.is_admin());

-- reactions: کاربر فقط واکنش خودش را اضافه/حذف می‌کند
create policy "reactions_select_all" on public.reactions
  for select using (true);

create policy "reactions_insert_own" on public.reactions
  for insert with check (auth.uid() = user_id and
    (select status from public.profiles where id = auth.uid()) = 'active');

create policy "reactions_delete_own" on public.reactions
  for delete using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- 7) داده‌ی اولیه‌ی sections (همان ۱۱ بخش + روایت امروز)
-- ------------------------------------------------------------
insert into public.sections (id, title, description, icon_name, group_name, kind, sort_order) values
  ('dailyStory', 'روایت امروز',            'کارت‌های چرخشی صفحه‌ی نخست',        'Sparkles',   null,        'stories',   0),
  ('identity',   'هویت و تاریخچه',         'ده فصل مستند، از خاستگاه تا امروز', 'Landmark',   'history',   'timeline',  1),
  ('figures',    'شخصیت‌های برجسته',        'چهره‌های سیاسی، علمی و ورزشی',      'Users',      'history',   'people',    2),
  ('genocide',   'نسل‌کشی هزاره‌ها در تاریخ', 'رویدادهای مستند ۲۰۰۱ تا ۲۰۲۶',      'History',    'history',   'incidents', 3),
  ('culture',    'فرهنگ و زندگی',          'آیین‌ها، خوراک و پوشاک',            'Sparkles',   'culture',   'grid',      4),
  ('music',      'موسیقی و شعر',            'دمبوره، فلک و کلام دل',             'Music2',     'culture',   'tracks',    5),
  ('language',   'زبان و گویش هزارگی',      'واژه‌ها و اصطلاحات زنده',           'Languages',  'culture',   'dictionary',6),
  ('map',        'نقشه‌ی هزارستان',          'پراکندگی جغرافیایی مردم هزاره',    'MapPin',     'resources', 'regions',   7),
  ('album',      'آلبوم عکس',               'تصاویر و مستندات دیداری',          'Image',      'resources', 'photos',    8),
  ('news',       'خبرنامه و رویدادها',       'تازه‌ترین رویدادهای روز',           'Newspaper',  'resources', 'news',      9),
  ('library',    'کتابخانه‌ی دیجیتال',       'منابع تاریخی، پژوهشی و ادبی',       'BookOpen',   'resources', 'books',     10),
  ('oral',       'حافظه‌ی جمعی',            'فید اجتماعی روایت‌های شفاهی',       'Mic2',       'resources', 'social',    11);

-- ------------------------------------------------------------
-- نکته‌ی مهم درباره‌ی «oral» / حافظه‌ی جمعی:
-- این بخش دیگر در content_items ذخیره نمی‌شود، بلکه مستقیماً
-- از جدول‌های posts / comments / reactions می‌آید (چون ساختار
-- اجتماعی دارد، نه محتوای ثابت).
-- ------------------------------------------------------------
