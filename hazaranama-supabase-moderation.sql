-- =============================================================================
-- هزاره‌نامه — گزارش محتوا و مسدودسازی کاربر (کاربر-به-کاربر)
-- =============================================================================
-- این دو جدول، الزام اجباری گوگل‌پلی («یک سامانه‌ی داخل‌اپی برای گزارش‌دادن و
-- مسدودکردن محتوا/کاربران ناشایست») و اپل (Guideline 1.2 — «یک مکانیزم برای
-- گزارش محتوای توهین‌آمیز» و «امکان مسدودکردن کاربران متخلف») را برای بخش
-- «حافظه‌ی جمعی» (محتوای کاربرساخته) برآورده می‌کند.
--
-- توجه: blocked_users («من فلانی را نمی‌بینم») کاملاً جدا از profiles.status
-- (مسدودسازی سراسری توسط ادمین، از قبل موجود در schema.sql) است.
--
-- کاملاً idempotent است — هر چندبار هم اجرا شود مشکلی پیش نمی‌آید.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- ۱) گزارش محتوا/کاربر — reporter یک پست، کامنت یا کاربر را گزارش می‌دهد.
-- target_preview یک نمای کوتاه از محتوا در لحظه‌ی گزارش است (متن پست/کامنت یا
-- نام کاربر) تا پنل مدیریت بدون نیاز به join‌های پیچیده، زمینه را نشان دهد.
-- -----------------------------------------------------------------------------
create table if not exists public.content_reports (
  id              uuid primary key default uuid_generate_v4(),
  reporter_id     uuid not null references public.profiles (id) on delete cascade,
  target_type     text not null check (target_type in ('post', 'comment', 'user')),
  target_id       text not null,
  target_owner_id uuid references public.profiles (id) on delete set null,
  target_preview  text,
  reason          text not null,
  note            text,
  status          text not null default 'pending' check (status in ('pending', 'reviewed', 'dismissed')),
  created_at      timestamptz not null default now()
);
create index if not exists idx_content_reports_status on public.content_reports (status, created_at desc);

alter table public.content_reports enable row level security;

drop policy if exists "content_reports_insert_own" on public.content_reports;
create policy "content_reports_insert_own" on public.content_reports
  for insert with check (auth.uid() = reporter_id);

drop policy if exists "content_reports_select_admin" on public.content_reports;
create policy "content_reports_select_admin" on public.content_reports
  for select using (public.is_admin());

drop policy if exists "content_reports_update_admin" on public.content_reports;
create policy "content_reports_update_admin" on public.content_reports
  for update using (public.is_admin());

-- -----------------------------------------------------------------------------
-- ۲) مسدودسازی کاربر توسط کاربر — پس از مسدودکردن، پست/کامنت‌های blocked_id
-- دیگر برای blocker_id در فید نمایش داده نمی‌شود (فیلتر سمت کلاینت).
-- blocked_name/blocked_avatar_url فقط یک نمای لحظه‌ی مسدودسازی است، برای
-- نمایش در صفحه‌ی «کاربران مسدودشده‌ی من» بدون نیاز به join.
-- -----------------------------------------------------------------------------
create table if not exists public.blocked_users (
  id                 uuid primary key default uuid_generate_v4(),
  blocker_id         uuid not null references public.profiles (id) on delete cascade,
  blocked_id         uuid not null references public.profiles (id) on delete cascade,
  blocked_name       text,
  blocked_avatar_url text,
  created_at         timestamptz not null default now(),
  unique (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index if not exists idx_blocked_users_blocker on public.blocked_users (blocker_id);

alter table public.blocked_users enable row level security;

drop policy if exists "blocked_users_select_own" on public.blocked_users;
create policy "blocked_users_select_own" on public.blocked_users
  for select using (auth.uid() = blocker_id);

drop policy if exists "blocked_users_insert_own" on public.blocked_users;
create policy "blocked_users_insert_own" on public.blocked_users
  for insert with check (auth.uid() = blocker_id);

drop policy if exists "blocked_users_delete_own" on public.blocked_users;
create policy "blocked_users_delete_own" on public.blocked_users
  for delete using (auth.uid() = blocker_id);
