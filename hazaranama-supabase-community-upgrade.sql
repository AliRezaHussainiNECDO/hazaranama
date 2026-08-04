-- =============================================================================
-- هزاره‌نامه — ارتقای «حافظه‌ی جمعی» به فید کامل عکس/ویدیو + ریپلای + لایک
-- =============================================================================
-- این فایل جدول‌های موجود posts/comments/reactions (که در
-- hazaranama-supabase-schema.sql ساخته شده‌اند) را گسترش می‌دهد تا فید
-- «حافظه‌ی جمعی» به سبک اینستاگرام/فیسبوک شود: پست با عکس/ویدیو، نظرهای
-- تودرتو (ریپلای)، لایک روی خودِ نظرها، و شمارنده‌ی سبک نظرها روی هر پست.
-- کاملاً idempotent است — هر چندبار هم اجرا شود مشکلی پیش نمی‌آید.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- ۱) رسانه (عکس/ویدیو) روی پست‌ها
-- -----------------------------------------------------------------------------
alter table public.posts add column if not exists image_urls text[] not null default '{}';
alter table public.posts add column if not exists video_url text;
alter table public.posts add column if not exists video_thumbnail_url text;
alter table public.posts add column if not exists comments_count integer not null default 0;

-- -----------------------------------------------------------------------------
-- ۲) ریپلای روی نظرها — هم‌خانواده‌ی video_comments/article_comments
-- -----------------------------------------------------------------------------
alter table public.comments add column if not exists parent_comment_id uuid references public.comments (id) on delete cascade;
create index if not exists idx_comments_parent on public.comments (parent_comment_id);

-- -----------------------------------------------------------------------------
-- ۳) لایک روی خودِ نظرها (مثل لایک زیر کامنت در اینستاگرام/فیسبوک)
-- -----------------------------------------------------------------------------
create table if not exists public.comment_likes (
  id         uuid primary key default uuid_generate_v4(),
  comment_id uuid not null references public.comments (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (comment_id, user_id)
);
create index if not exists idx_comment_likes_comment on public.comment_likes (comment_id);

alter table public.comment_likes enable row level security;

drop policy if exists "comment_likes_select_all" on public.comment_likes;
create policy "comment_likes_select_all" on public.comment_likes for select using (true);

drop policy if exists "comment_likes_insert_own" on public.comment_likes;
create policy "comment_likes_insert_own" on public.comment_likes
  for insert with check (auth.uid() = user_id and
    (select status from public.profiles where id = auth.uid()) = 'active');

drop policy if exists "comment_likes_delete_own" on public.comment_likes;
create policy "comment_likes_delete_own" on public.comment_likes
  for delete using (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- ۴) شمارنده‌ی خودکار نظرها روی هر پست — فید اصلی سبک می‌ماند چون دیگر لازم
-- نیست همه‌ی نظرها را برای شمردن، به هر پست embed کنیم.
-- -----------------------------------------------------------------------------
create or replace function public.bump_post_comments_count() returns trigger as $$
begin
  if tg_op = 'INSERT' then
    update public.posts set comments_count = comments_count + 1 where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update public.posts set comments_count = greatest(comments_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trg_bump_post_comments_count on public.comments;
create trigger trg_bump_post_comments_count
  after insert or delete on public.comments
  for each row execute function public.bump_post_comments_count();

-- بازمحاسبه‌ی شمارنده برای رکوردهای احتمالی موجود پیش از این ارتقا
update public.posts p set comments_count = (
  select count(*) from public.comments c where c.post_id = p.id
);

-- -----------------------------------------------------------------------------
-- ۵) باکت Storage برای عکس/ویدیوی پست‌های کاربران — برخلاف باکت‌های دیگر اپ
-- (که فقط مدیر می‌نویسد)، اینجا هر کاربرِ فعال خودش می‌نویسد؛ دقیقاً مثل باکت
-- avatars: هرکس فقط داخل پوشه‌ی خودش (به نام user id) اجازه‌ی نوشتن دارد
-- (قرارداد مسیر در کد فلاتر: post-media/<user_id>/<filename>).
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('post-media', 'post-media', true)
on conflict (id) do nothing;

drop policy if exists "post_media_public_read" on storage.objects;
create policy "post_media_public_read"
on storage.objects for select
using (bucket_id = 'post-media');

drop policy if exists "post_media_owner_insert" on storage.objects;
create policy "post_media_owner_insert"
on storage.objects for insert
with check (bucket_id = 'post-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "post_media_owner_update" on storage.objects;
create policy "post_media_owner_update"
on storage.objects for update
using (bucket_id = 'post-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "post_media_owner_delete" on storage.objects;
create policy "post_media_owner_delete"
on storage.objects for delete
using (bucket_id = 'post-media' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));
