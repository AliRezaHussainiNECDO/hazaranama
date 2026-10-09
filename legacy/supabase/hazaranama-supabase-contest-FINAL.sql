-- ============================================================
-- هزاره‌نامه — فایل نهایی و یکجای «مسابقه‌ی مقالات»
-- ============================================================
-- این فایل، مجموعِ چهار اسکریپت زیر است که در طول توسعه‌ی این بخش نوشته
-- شدند و اینجا به‌ترتیبِ درست کنار هم چسبانده شده‌اند تا فقط با یک بار
-- Run کردن، همه‌چیز آماده شود:
--   ۱) hazaranama-supabase-articles-contest.sql
--      → جدول‌های article_submissions، featured_articles،
--        article_comments، article_reactions + سیاست‌های RLS پایه
--   ۲) hazaranama-supabase-contest-settings.sql
--      → جدول تک‌ردیفی contest_settings (موضوع مشترک + جوایز سه مقام)
--   ۳) hazaranama-supabase-article-quality-score.sql
--      → ستون ai_quality_score روی article_submissions (برای رتبه‌بندی
--        خودکار با هوش مصنوعی)
--   ۴) hazaranama-supabase-contest-round.sql
--      → ستون round_started_at روی contest_settings + به‌روزرسانی نهاییِ
--        سیاست ارسال مقاله تا فقط در پنجره‌ی ۲۸ روزه‌ی دوره‌ی فعال اجازه بدهد
--
-- کاملاً idempotent است — یعنی اگر بخشی از این‌ها را قبلاً اجرا کرده باشید،
-- دوباره اجرای کل این فایل هیچ مشکلی ایجاد نمی‌کند و داده‌ای پاک نمی‌شود.
--
-- پیش‌نیاز: باید قبل از این فایل، hazaranama-supabase-schema.sql را اجرا
-- کرده باشید (چون از تابع is_admin() و جدول profiles استفاده می‌کند).
--
-- اجرا: کل این فایل را در Supabase SQL Editor بچسبانید و یک‌بار Run بزنید.
-- ============================================================


-- ============================================================
-- بخش ۱ از ۴ — hazaranama-supabase-articles-contest.sql
-- (article_submissions، featured_articles، article_comments،
-- article_reactions + سیاست‌های RLS پایه)
-- ============================================================

-- ------------------------------------------------------------
-- ۱) مقالات ارسالی کاربران
-- ------------------------------------------------------------
create table if not exists public.article_submissions (
  id            uuid primary key default uuid_generate_v4(),
  author_id     uuid not null references public.profiles (id) on delete cascade,
  title         text not null,
  body          text not null,
  status        text not null default 'active'
                  check (status in ('active', 'closed', 'disqualified', 'published')),
  ai_verdict    text check (ai_verdict in ('original', 'suspicious', 'likely_ai_or_copied')),
  ai_confidence numeric,
  ai_notes      text,
  submitted_at  timestamptz not null default now()
);

create index if not exists idx_article_submissions_author on public.article_submissions (author_id, submitted_at desc);
create index if not exists idx_article_submissions_status on public.article_submissions (status);

-- ------------------------------------------------------------
-- ۲) برگزیدگان منتشرشده (سه مقام برتر هر دوره)
-- ------------------------------------------------------------
create table if not exists public.featured_articles (
  id            uuid primary key default uuid_generate_v4(),
  submission_id uuid references public.article_submissions (id) on delete set null,
  author_id     uuid references public.profiles (id) on delete set null,
  author_name   text not null,
  author_avatar text,
  title         text not null,
  body          text not null,
  placement     int not null check (placement in (1, 2, 3)),
  month_label   text not null,
  prize         text,
  sort_order    int not null default 0,
  published_at  timestamptz not null default now()
);

create index if not exists idx_featured_articles_published on public.featured_articles (published_at desc);

-- ------------------------------------------------------------
-- ۳) کامنت‌ها + ریپلای روی برگزیدگان (یک سطح، مثل video_comments)
-- ------------------------------------------------------------
create table if not exists public.article_comments (
  id                uuid primary key default uuid_generate_v4(),
  featured_article_id uuid not null references public.featured_articles (id) on delete cascade,
  author_id         uuid not null references public.profiles (id) on delete cascade,
  parent_comment_id uuid references public.article_comments (id) on delete cascade,
  text              text not null,
  created_at        timestamptz not null default now()
);

create index if not exists idx_article_comments_article on public.article_comments (featured_article_id, created_at);
create index if not exists idx_article_comments_parent on public.article_comments (parent_comment_id);

-- ------------------------------------------------------------
-- ۴) واکنش ایموجی روی برگزیدگان (مثل video_reactions)
-- ------------------------------------------------------------
create table if not exists public.article_reactions (
  id         uuid primary key default uuid_generate_v4(),
  featured_article_id uuid not null references public.featured_articles (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  emoji      text not null,
  created_at timestamptz not null default now(),
  unique (featured_article_id, user_id, emoji)
);

create index if not exists idx_article_reactions_article on public.article_reactions (featured_article_id);

-- ------------------------------------------------------------
-- ۵) RLS پایه
-- ------------------------------------------------------------
alter table public.article_submissions enable row level security;
alter table public.featured_articles   enable row level security;
alter table public.article_comments    enable row level security;
alter table public.article_reactions   enable row level security;

-- مقالات ارسالی: فقط خودِ نویسنده و مدیر می‌بینند (خصوصی تا وقتی منتشر نشده)
drop policy if exists "article_submissions_select_own_or_admin" on public.article_submissions;
create policy "article_submissions_select_own_or_admin" on public.article_submissions
  for select using (auth.uid() = author_id or public.is_admin());

-- توجه: سیاست INSERT اینجا موقتاً ساخته می‌شود؛ در بخش ۴ این فایل
-- (hazaranama-supabase-contest-round.sql) با نسخه‌ی نهایی (که پنجره‌ی
-- ۲۸ روزه را هم بررسی می‌کند) جایگزین خواهد شد — همان چیزی که در پایان
-- این فایل باقی می‌ماند.
drop policy if exists "article_submissions_insert_own" on public.article_submissions;
create policy "article_submissions_insert_own" on public.article_submissions
  for insert with check (auth.uid() = author_id and
    (select status from public.profiles where id = auth.uid()) = 'active');

-- ویرایش وضعیت/رتبه/نتیجه‌ی هوش مصنوعی فقط با مدیر (برای جلوگیری از
-- دستکاری بعد از ارسال)
drop policy if exists "article_submissions_admin_update" on public.article_submissions;
create policy "article_submissions_admin_update" on public.article_submissions
  for update using (public.is_admin());

-- نویسنده تا وقتی مقاله‌اش هنوز «فعال» است می‌تواند خودش حذفش کند؛ مدیر همیشه
drop policy if exists "article_submissions_delete_own_or_admin" on public.article_submissions;
create policy "article_submissions_delete_own_or_admin" on public.article_submissions
  for delete using ((auth.uid() = author_id and status = 'active') or public.is_admin());

-- برگزیدگان: خواندن برای همه؛ نوشتن فقط مدیر
drop policy if exists "featured_articles_select_all" on public.featured_articles;
create policy "featured_articles_select_all" on public.featured_articles for select using (true);
drop policy if exists "featured_articles_admin_insert" on public.featured_articles;
create policy "featured_articles_admin_insert" on public.featured_articles for insert with check (public.is_admin());
drop policy if exists "featured_articles_admin_update" on public.featured_articles;
create policy "featured_articles_admin_update" on public.featured_articles for update using (public.is_admin());
drop policy if exists "featured_articles_admin_delete" on public.featured_articles;
create policy "featured_articles_admin_delete" on public.featured_articles for delete using (public.is_admin());

-- کامنت‌ها: خواندن برای همه؛ کاربر فعال کامنت/ریپلای خودش را می‌سازد؛ حذف خودش یا مدیر
drop policy if exists "article_comments_select_all" on public.article_comments;
create policy "article_comments_select_all" on public.article_comments for select using (true);
drop policy if exists "article_comments_insert_own" on public.article_comments;
create policy "article_comments_insert_own" on public.article_comments
  for insert with check (auth.uid() = author_id and
    (select status from public.profiles where id = auth.uid()) = 'active');
drop policy if exists "article_comments_delete_own_or_admin" on public.article_comments;
create policy "article_comments_delete_own_or_admin" on public.article_comments
  for delete using (auth.uid() = author_id or public.is_admin());

-- واکنش ایموجی: کاربر فعال فقط واکنش خودش را اضافه/حذف می‌کند
drop policy if exists "article_reactions_select_all" on public.article_reactions;
create policy "article_reactions_select_all" on public.article_reactions for select using (true);
drop policy if exists "article_reactions_insert_own" on public.article_reactions;
create policy "article_reactions_insert_own" on public.article_reactions
  for insert with check (auth.uid() = user_id and
    (select status from public.profiles where id = auth.uid()) = 'active');
drop policy if exists "article_reactions_delete_own" on public.article_reactions;
create policy "article_reactions_delete_own" on public.article_reactions
  for delete using (auth.uid() = user_id);


-- ============================================================
-- بخش ۲ از ۴ — hazaranama-supabase-contest-settings.sql
-- (contest_settings: موضوع مشترک + جوایز سه مقام)
-- ============================================================

create table if not exists public.contest_settings (
  id           int primary key default 1,
  topic        text not null default 'موضوع این دوره هنوز از سوی مدیریت تعیین نشده است',
  prize_first  text,
  prize_second text,
  prize_third  text,
  updated_at   timestamptz not null default now(),
  constraint contest_settings_singleton check (id = 1)
);

-- ردیف پیش‌فرض؛ اگر از قبل وجود داشته باشد دست‌نخورده می‌ماند.
insert into public.contest_settings (id)
values (1)
on conflict (id) do nothing;

alter table public.contest_settings enable row level security;

-- خواندن برای همه (باید در صفحه‌ی مسابقه و فرم ارسال، پیش از ورود هم قابل‌دیدن باشد)
drop policy if exists "contest_settings_select_all" on public.contest_settings;
create policy "contest_settings_select_all" on public.contest_settings for select using (true);

-- نوشتن/ویرایش فقط مدیر (upsert از اپ هم به insert و هم به update نیاز دارد)
drop policy if exists "contest_settings_admin_insert" on public.contest_settings;
create policy "contest_settings_admin_insert" on public.contest_settings
  for insert with check (public.is_admin());

drop policy if exists "contest_settings_admin_update" on public.contest_settings;
create policy "contest_settings_admin_update" on public.contest_settings
  for update using (public.is_admin());


-- ============================================================
-- بخش ۳ از ۴ — hazaranama-supabase-article-quality-score.sql
-- (ai_quality_score روی article_submissions)
-- ============================================================

alter table public.article_submissions
  add column if not exists ai_quality_score numeric;


-- ============================================================
-- بخش ۴ از ۴ — hazaranama-supabase-contest-round.sql
-- (round_started_at روی contest_settings + سیاست نهاییِ ارسال مقاله)
-- ============================================================

alter table public.contest_settings
  add column if not exists round_started_at timestamptz;

-- سیاست ارسال مقاله را با نسخه‌ی نهایی جایگزین کن — این آخرین و درستِ آن است
-- (فقط در پنجره‌ی ۲۸ روزه‌ی دوره‌ی فعال اجازه‌ی ارسال می‌دهد).
drop policy if exists "article_submissions_insert_own" on public.article_submissions;
create policy "article_submissions_insert_own" on public.article_submissions
  for insert with check (
    auth.uid() = author_id
    and (select status from public.profiles where id = auth.uid()) = 'active'
    and exists (
      select 1 from public.contest_settings cs
      where cs.id = 1
        and cs.round_started_at is not null
        and now() < cs.round_started_at + interval '28 days'
    )
  );

-- ============================================================
-- پایان — بعد از اجرای موفق این فایل، از پنل مدیریت → «مسابقه‌ی مقالات» →
-- تب «موضوع و جوایز»، موضوع این دوره و جوایز را تنظیم کنید و روی «شروع
-- دوره‌ی تازه» بزنید تا پنجره‌ی ۲۸ روزه‌ی ارسال باز شود.
-- ============================================================
