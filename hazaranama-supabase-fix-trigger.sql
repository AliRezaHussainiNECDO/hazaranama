-- ============================================================
-- رفع خطای «Database error saving new user» هنگام ثبت‌نام
-- ============================================================
-- این خطا یعنی تریگر handle_new_user (که باید بعد از ساخت هر
-- کاربر تازه در auth.users، یک ردیف در public.profiles بسازد)
-- در پروژه‌ی شما دارد شکست می‌خورد — معمولاً چون نسخه‌ی قدیمی/ناقص
-- این تابع از قبل نصب بوده. این اسکریپت idempotent است (اجرای
-- دوباره‌اش هم مشکلی ایجاد نمی‌کند) و نسخه‌ی درست را جایگزین می‌کند.
--
-- اجرا: در Supabase Dashboard → SQL Editor، همین فایل را کامل
-- بچسبانید و Run بزنید؛ بعد دوباره ثبت‌نام را امتحان کنید.
-- ============================================================

drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();

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
    (case when new.email = 'alireza.necdo@gmail.com' then 'admin' else 'user' end)::public.user_role,
    'active'::public.user_status
  )
  on conflict (id) do nothing;
  return new;
exception when others then
  -- حتی اگر ساخت profile به هر دلیلی شکست بخورد، ثبت‌نام کاربر را
  -- متوقف نکن — فقط خطای واقعی را در Postgres Logs ثبت کن تا بتوانیم
  -- علت دقیق را ببینیم (Dashboard → Logs → Postgres Logs).
  raise log 'handle_new_user failed for %: % (sqlstate=%)', new.email, sqlerrm, sqlstate;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- بررسی سریع: آیا enum ها و جدول profiles واقعاً وجود دارند؟
-- (اگر این کوئری خطا داد، یعنی hazaranama-supabase-schema.sql اصلاً
--  کامل اجرا نشده — آن فایل را از اول کامل اجرا کنید.)
select
  (select count(*) from pg_type where typname = 'user_role') as user_role_enum_exists,
  (select count(*) from pg_type where typname = 'user_status') as user_status_enum_exists,
  (select count(*) from information_schema.tables where table_schema = 'public' and table_name = 'profiles') as profiles_table_exists;
