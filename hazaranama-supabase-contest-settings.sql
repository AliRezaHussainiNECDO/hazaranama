-- ============================================================
-- هزاره‌نامه — تنظیمات دوره‌ی مسابقه‌ی مقالات (موضوع مشترک + جوایز)
-- ============================================================
-- این اسکریپت یک جدول تک‌ردیفی (singleton) می‌سازد که مدیر از پنل مدیریت
-- (تب «تنظیمات دوره») ویرایشش می‌کند:
--   • topic — عنوان/موضوعی که همه‌ی شرکت‌کنندگان باید مقاله‌شان را روی آن
--     بنویسند (به‌جای اینکه هرکس عنوان دلخواه خودش را انتخاب کند). فرم
--     ارسال مقاله دیگر فیلد «عنوان» آزاد ندارد و همین موضوع را به‌عنوان
--     عنوان مقاله ثبت می‌کند.
--   • prize_first / prize_second / prize_third — جایزه‌ی سه مقام برتر همین
--     دوره، که پیش از ارسال، در صفحه‌ی مسابقه به کاربران نشان داده می‌شود.
--     این با ستون prize روی هر رکورد featured_articles فرق دارد؛ آن یکی
--     جایزه‌ای است که واقعاً بعد از اعلام نتایج برای یک برنده‌ی مشخص ثبت
--     می‌شود (ممکن است دستی و متفاوت هم باشد).
--
-- اجرا: در Supabase SQL Editor کامل بچسبانید و Run بزنید (idempotent).
-- باید بعد از hazaranama-supabase-schema.sql اجرا شود (از is_admin()
-- استفاده می‌کند). نسبت به hazaranama-supabase-articles-contest.sql مستقل
-- است — ترتیب اجرای این دو نسبت به هم اهمیتی ندارد، اما هر دو برای کارکرد
-- کامل بخش «مسابقه‌ی مقالات» لازم‌اند.
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
