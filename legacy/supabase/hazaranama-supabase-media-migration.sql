-- ============================================================
-- هزاره‌نامه — افزودن پشتیبانی عکس/ویدیو به همه‌ی بخش‌های محتوا
-- ============================================================
-- این اسکریپت:
--   ۱) ستون video_url را به content_items اضافه می‌کند (image_url از
--      قبل در schema اصلی وجود داشت، فقط استفاده نمی‌شد).
--   ۲) باکت Storage تازه‌ای به نام content-media می‌سازد — برای عکس‌های
--      محتوای بخش‌ها (جدا از باکت avatars که فقط برای عکس پروفایل است).
--   ۳) سیاست‌های RLS: خواندن برای همه آزاد (باکت عمومی)، نوشتن/ویرایش/
--      حذف فقط برای مدیر — دقیقاً هم‌راستا با سیاست‌های content_items.
--
-- اجرا: در Supabase SQL Editor کامل بچسبانید و Run بزنید (idempotent —
-- اجرای دوباره هم مشکلی ایجاد نمی‌کند).
-- ============================================================

-- ۱) ستون ویدیو
alter table public.content_items add column if not exists video_url text;

-- ۲) باکت Storage برای عکس‌های محتوا
insert into storage.buckets (id, name, public)
values ('content-media', 'content-media', true)
on conflict (id) do nothing;

-- ۳) خواندن برای همه آزاد (باکت عمومی است)
drop policy if exists "content_media_public_read" on storage.objects;
create policy "content_media_public_read"
on storage.objects for select
using (bucket_id = 'content-media');

-- نوشتن/ویرایش/حذف فقط برای مدیر (همان تابع is_admin() که در schema اصلی ساخته شد)
drop policy if exists "content_media_admin_insert" on storage.objects;
create policy "content_media_admin_insert"
on storage.objects for insert
with check (bucket_id = 'content-media' and public.is_admin());

drop policy if exists "content_media_admin_update" on storage.objects;
create policy "content_media_admin_update"
on storage.objects for update
using (bucket_id = 'content-media' and public.is_admin());

drop policy if exists "content_media_admin_delete" on storage.objects;
create policy "content_media_admin_delete"
on storage.objects for delete
using (bucket_id = 'content-media' and public.is_admin());
