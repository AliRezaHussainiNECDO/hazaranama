-- ============================================================
-- هزاره‌نامه — شمارنده‌ی واقعیِ «بازدید امروز» برای صفحه‌ی نخست پنل مدیریت
-- ============================================================
-- این اسکریپت یک جدول تک‌ردیف-به-ازای-هر-روز می‌سازد که هر بار اپ باز
-- می‌شود (یک بار در هر نشست، نه هر بار که صفحه عوض می‌شود) با فراخوانی
-- تابع increment_daily_visit() یک واحد به شمارنده‌ی همان روز اضافه می‌کند.
-- کاملاً بی‌نام (anonymous) است — هیچ user_id ذخیره نمی‌شود، فقط شمارش.
--
-- اجرا: در Supabase SQL Editor کامل بچسبانید و Run بزنید (idempotent).
-- باید بعد از hazaranama-supabase-schema.sql اجرا شود (از is_admin() استفاده
-- می‌کند).
-- ============================================================

create table if not exists public.daily_visits (
  day   date primary key,
  count int  not null default 0
);

alter table public.daily_visits enable row level security;

-- فقط مدیر می‌تواند شمارنده‌ها را بخواند (برای نمودار/آمار پنل مدیریت)
drop policy if exists "daily_visits_admin_select" on public.daily_visits;
create policy "daily_visits_admin_select" on public.daily_visits
  for select using (public.is_admin());

-- افزایش امن شمارنده — با اختیارات سازنده اجرا می‌شود تا هر کاربر واردشده
-- (حتی غیرمدیر) بتواند صدایش بزند، بدون اینکه مستقیم به جدول دسترسی نوشتن
-- داشته باشد و بدون race condition بین نشست‌های هم‌زمان.
create or replace function public.increment_daily_visit()
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.daily_visits (day, count)
  values (current_date, 1)
  on conflict (day) do update set count = public.daily_visits.count + 1;
$$;

grant execute on function public.increment_daily_visit() to authenticated;

-- =============================================================================
-- پایان — بعد از اجرای این اسکریپت، کارت «بازدید امروز» در صفحه‌ی نخست
-- پنل مدیریت عدد واقعیِ شمارِ نشست‌های همان روز را نشان می‌دهد.
-- =============================================================================
