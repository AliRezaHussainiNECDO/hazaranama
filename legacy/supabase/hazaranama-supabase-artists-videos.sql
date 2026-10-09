-- ============================================================
-- هزاره‌نامه — گالری هنرمندان و ویدیوهای موسیقی/شعر (مثل یوتیوب داخلی)
-- ============================================================
-- این اسکریپت بخش «موسیقی و شعر» را از یک فهرست ساده‌ی متنی به یک
-- گالری کامل تبدیل می‌کند: برای هر خواننده/هنرمند یک پروفایل با
-- ویدیوهای قابل‌پخش در خود اپ، شمارنده‌ی بازدید، کامنت + ریپلای،
-- و واکنش ایموجی (دقیقاً هم‌خانواده‌ی جدول reactions موجود برای پست‌ها).
--
-- اجرا: در Supabase SQL Editor کامل بچسبانید و Run بزنید (idempotent).
-- باید بعد از hazaranama-supabase-schema.sql اجرا شود (از is_admin() و
-- profiles استفاده می‌کند).
-- ============================================================

-- ------------------------------------------------------------
-- ۱) هنرمندان
-- ------------------------------------------------------------
create table if not exists public.artists (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  bio         text,
  avatar_url  text,
  cover_url   text,
  sort_order  int not null default 0,
  created_by  uuid references public.profiles (id),
  created_at  timestamptz not null default now()
);

-- ------------------------------------------------------------
-- ۲) ویدیوهای هر هنرمند
-- ------------------------------------------------------------
create table if not exists public.artist_videos (
  id            uuid primary key default uuid_generate_v4(),
  artist_id     uuid not null references public.artists (id) on delete cascade,
  title         text not null,
  description   text,
  video_url     text not null,
  thumbnail_url text,
  views_count   int not null default 0,
  sort_order    int not null default 0,
  created_by    uuid references public.profiles (id),
  created_at    timestamptz not null default now()
);

create index if not exists idx_artist_videos_artist on public.artist_videos (artist_id, sort_order);

-- ------------------------------------------------------------
-- ۳) کامنت‌ها + ریپلای (یک سطح، با parent_comment_id به خودِ جدول)
-- ------------------------------------------------------------
create table if not exists public.video_comments (
  id                uuid primary key default uuid_generate_v4(),
  video_id          uuid not null references public.artist_videos (id) on delete cascade,
  author_id         uuid not null references public.profiles (id) on delete cascade,
  parent_comment_id uuid references public.video_comments (id) on delete cascade,
  text              text not null,
  created_at        timestamptz not null default now()
);

create index if not exists idx_video_comments_video on public.video_comments (video_id, created_at);
create index if not exists idx_video_comments_parent on public.video_comments (parent_comment_id);

-- ------------------------------------------------------------
-- ۴) واکنش ایموجی روی ویدیو (هم‌خانواده‌ی reactions پست‌ها)
-- ------------------------------------------------------------
create table if not exists public.video_reactions (
  id         uuid primary key default uuid_generate_v4(),
  video_id   uuid not null references public.artist_videos (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  emoji      text not null,
  created_at timestamptz not null default now(),
  unique (video_id, user_id, emoji)
);

create index if not exists idx_video_reactions_video on public.video_reactions (video_id);

-- ------------------------------------------------------------
-- ۵) افزایش امن شمارنده‌ی بازدید — از طریق RPC تا race condition نداشته باشد
-- ------------------------------------------------------------
create or replace function public.increment_video_views(p_video_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.artist_videos set views_count = views_count + 1 where id = p_video_id;
$$;

grant execute on function public.increment_video_views(uuid) to authenticated, anon;

-- ------------------------------------------------------------
-- ۶) باکت Storage برای آواتار/کاور هنرمند + فایل ویدیو + تامبنیل
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('artist-media', 'artist-media', true)
on conflict (id) do nothing;

drop policy if exists "artist_media_public_read" on storage.objects;
create policy "artist_media_public_read"
on storage.objects for select
using (bucket_id = 'artist-media');

drop policy if exists "artist_media_admin_insert" on storage.objects;
create policy "artist_media_admin_insert"
on storage.objects for insert
with check (bucket_id = 'artist-media' and public.is_admin());

drop policy if exists "artist_media_admin_update" on storage.objects;
create policy "artist_media_admin_update"
on storage.objects for update
using (bucket_id = 'artist-media' and public.is_admin());

drop policy if exists "artist_media_admin_delete" on storage.objects;
create policy "artist_media_admin_delete"
on storage.objects for delete
using (bucket_id = 'artist-media' and public.is_admin());

-- ------------------------------------------------------------
-- ۷) RLS
-- ------------------------------------------------------------
alter table public.artists         enable row level security;
alter table public.artist_videos   enable row level security;
alter table public.video_comments  enable row level security;
alter table public.video_reactions enable row level security;

-- هنرمندان: خواندن برای همه؛ نوشتن فقط مدیر
drop policy if exists "artists_select_all" on public.artists;
create policy "artists_select_all" on public.artists for select using (true);
drop policy if exists "artists_admin_insert" on public.artists;
create policy "artists_admin_insert" on public.artists for insert with check (public.is_admin());
drop policy if exists "artists_admin_update" on public.artists;
create policy "artists_admin_update" on public.artists for update using (public.is_admin());
drop policy if exists "artists_admin_delete" on public.artists;
create policy "artists_admin_delete" on public.artists for delete using (public.is_admin());

-- ویدیوها: خواندن برای همه؛ نوشتن فقط مدیر
drop policy if exists "artist_videos_select_all" on public.artist_videos;
create policy "artist_videos_select_all" on public.artist_videos for select using (true);
drop policy if exists "artist_videos_admin_insert" on public.artist_videos;
create policy "artist_videos_admin_insert" on public.artist_videos for insert with check (public.is_admin());
drop policy if exists "artist_videos_admin_update" on public.artist_videos;
create policy "artist_videos_admin_update" on public.artist_videos for update using (public.is_admin());
drop policy if exists "artist_videos_admin_delete" on public.artist_videos;
create policy "artist_videos_admin_delete" on public.artist_videos for delete using (public.is_admin());

-- کامنت‌ها: خواندن برای همه؛ کاربر فعال کامنت/ریپلای خودش را می‌سازد؛ حذف خودش یا مدیر
drop policy if exists "video_comments_select_all" on public.video_comments;
create policy "video_comments_select_all" on public.video_comments for select using (true);
drop policy if exists "video_comments_insert_own" on public.video_comments;
create policy "video_comments_insert_own" on public.video_comments
  for insert with check (auth.uid() = author_id and
    (select status from public.profiles where id = auth.uid()) = 'active');
drop policy if exists "video_comments_delete_own_or_admin" on public.video_comments;
create policy "video_comments_delete_own_or_admin" on public.video_comments
  for delete using (auth.uid() = author_id or public.is_admin());

-- واکنش ایموجی: کاربر فعال فقط واکنش خودش را اضافه/حذف می‌کند
drop policy if exists "video_reactions_select_all" on public.video_reactions;
create policy "video_reactions_select_all" on public.video_reactions for select using (true);
drop policy if exists "video_reactions_insert_own" on public.video_reactions;
create policy "video_reactions_insert_own" on public.video_reactions
  for insert with check (auth.uid() = user_id and
    (select status from public.profiles where id = auth.uid()) = 'active');
drop policy if exists "video_reactions_delete_own" on public.video_reactions;
create policy "video_reactions_delete_own" on public.video_reactions
  for delete using (auth.uid() = user_id);
