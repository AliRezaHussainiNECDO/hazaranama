-- ============================================================
-- هزاره‌نامه — تنظیمات Storage برای عکس پروفایل
-- این را در Supabase SQL Editor، بعد از فایل schema اصلی، اجرا کنید.
-- (ساخت خودِ باکت را هم می‌توانید از داشبورد Storage انجام دهید؛
--  این اسکریپت هر دو راه را نشان می‌دهد.)
-- ============================================================

-- ۱) ساخت باکت (اگر از طریق داشبورد نساخته‌اید)
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- ۲) همه می‌توانند عکس‌های پروفایل را ببینند (باکت عمومی است)
create policy "avatars_public_read"
on storage.objects for select
using (bucket_id = 'avatars');

-- ۳) هر کاربر فقط می‌تواند در پوشه‌ی خودش (به نام user id) آپلود کند
-- قرارداد نام‌گذاری فایل در کد: avatars/<user_id>/<filename>
create policy "avatars_owner_insert"
on storage.objects for insert
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars_owner_update"
on storage.objects for update
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars_owner_delete"
on storage.objects for delete
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
