-- ============================================================
-- هزاره‌نامه — دوره‌ی مشترک مسابقه‌ی مقالات (۲۸ روز ارسال + ۲ روز نمایش)
-- ============================================================
-- این اسکریپت زمان‌بندی مسابقه را از «هر مقاله ۳۰ روز جداگانه» به «یک دوره‌ی
-- مشترک برای همه» تغییر می‌دهد:
--   • round_started_at — تاریخی که مدیر با دکمه‌ی «شروع دوره‌ی تازه» در پنل
--     مدیریت ثبت می‌کند. از همان لحظه:
--       - ۲۸ روز اول: پنجره‌ی ارسال مقاله باز است.
--       - روز ۲۸ (round_started_at + 28 days): مهلت ارسال تمام می‌شود و
--         رتبه‌بندی خودکار با هوش مصنوعی باید اجرا شود.
--       - ۲ روز آخر (تا round_started_at + 30 days): فقط برای خواندن و
--         نظردادن روی برگزیدگان است؛ محدودیت خاصی در دیتابیس ندارد.
--
-- علاوه بر ستون تازه، سیاست INSERT روی article_submissions هم به‌روز
-- می‌شود تا ارسال مقاله را فقط در پنجره‌ی ۲۸ روزه‌ی دوره‌ی فعال اجازه بدهد —
-- این یک لایه‌ی امنیتی سمت سرور است، جدا از اعتبارسنجی سمت اپ.
--
-- اجرا: در Supabase SQL Editor کامل بچسبانید و Run بزنید (idempotent).
-- باید بعد از هر دو فایل hazaranama-supabase-articles-contest.sql و
-- hazaranama-supabase-contest-settings.sql اجرا شود (به جدول‌های هر دو نیاز دارد).
-- ============================================================

alter table public.contest_settings
  add column if not exists round_started_at timestamptz;

-- سیاست قبلیِ ارسال مقاله را با نسخه‌ای که پنجره‌ی ۲۸ روزه را هم بررسی می‌کند جایگزین کن
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
