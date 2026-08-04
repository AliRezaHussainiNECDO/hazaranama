-- ============================================================
-- هزاره‌نامه — مسابقه‌ی مقالات (ارسال، دوره‌ی ۳۰ روزه، بررسی هوش
-- مصنوعی، رتبه‌بندی و نشر سه مقاله‌ی برتر با کامنت/ریپلای/ایموجی)
-- ============================================================
-- این اسکریپت سه بخش تازه را می‌سازد:
--   ۱) article_submissions — مقالات ارسالی کاربران (خصوصی؛ فقط خودِ
--      نویسنده و مدیر می‌بینند)، هرکدام با یک دوره‌ی ۳۰ روزه از لحظه‌ی
--      ارسال (submitted_at)، که در اپ محاسبه می‌شود — نیازی به ستون
--      جداگانه نیست.
--   ۲) featured_articles — سه مقاله‌ی برتری که هرماه مدیر انتخاب و
--      منتشر می‌کند؛ این‌ها عمومی‌اند و بقیه‌ی کاربران می‌توانند
--      کامنت/ریپلای/ایموجی بگذارند (دقیقاً هم‌خانواده‌ی الگوی
--      video_comments/video_reactions در فایل artists-videos).
--   ۳) article_comments و article_reactions — برای همان بخش برگزیدگان.
--
-- توجه مهم درباره‌ی «بررسی هوش مصنوعی»: تشخیص اینکه متنی توسط خودِ
-- کاربر نوشته شده یا از هوش مصنوعی/جای دیگر کپی شده، هیچ‌وقت ۱۰۰٪
-- قطعی نیست — Gemini فقط یک «حدس مستدل» با درصد اطمینان برمی‌گرداند
-- (ذخیره در ai_verdict/ai_confidence/ai_notes) تا به مدیر در تصمیم‌گیری
-- کمک کند؛ تصمیم نهاییِ رد صلاحیت یا برگزیدن، همیشه با خودِ مدیر است
-- (نه خودکار).
--
-- اجرا: در Supabase SQL Editor کامل بچسبانید و Run بزنید (idempotent).
-- باید بعد از hazaranama-supabase-schema.sql اجرا شود (از is_admin() و
-- profiles استفاده می‌کند).
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
-- ۵) RLS
-- ------------------------------------------------------------
alter table public.article_submissions enable row level security;
alter table public.featured_articles   enable row level security;
alter table public.article_comments    enable row level security;
alter table public.article_reactions   enable row level security;

-- مقالات ارسالی: فقط خودِ نویسنده و مدیر می‌بینند (خصوصی تا وقتی منتشر نشده)
drop policy if exists "article_submissions_select_own_or_admin" on public.article_submissions;
create policy "article_submissions_select_own_or_admin" on public.article_submissions
  for select using (auth.uid() = author_id or public.is_admin());

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
