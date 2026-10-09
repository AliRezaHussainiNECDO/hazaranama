-- ============================================================
-- هزاره‌نامه — توکن‌های دستگاه برای پوش نوتیفیکیشن واقعی (Firebase FCM)
-- ============================================================
-- هر ردیف یک توکن FCM را به یک کاربر و دستگاه وصل می‌کند. اپ فلاتر بعد از
-- ورود کاربر و گرفتن اجازه‌ی اعلان، توکن دستگاه را اینجا ثبت می‌کند
-- (upsert بر اساس ستون token — چون یک دستگاه ممکن است بین چند کاربر
-- دست‌به‌دست شود، هر بار صاحبِ فعلیِ توکن به‌روزرسانی می‌شود).
--
-- یک Edge Function آینده (send-push یا مشابه)، با کلید سرویس Firebase،
-- برای هر user_id همه‌ی توکن‌های فعالش را می‌خواند و پیام را به‌شان می‌فرستد.
--
-- اجرا: در Supabase SQL Editor کامل بچسبانید و Run بزنید (idempotent).
-- ============================================================

create table if not exists public.device_tokens (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  token      text not null unique,
  platform   text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_device_tokens_user on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

drop policy if exists "device_tokens_manage_own" on public.device_tokens;
create policy "device_tokens_manage_own" on public.device_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- =============================================================================
-- پایان — بعد از اجرای این اسکریپت، اپ می‌تواند با یک upsert ساده (کد فلاتر
-- آماده است)، توکن دستگاه هر کاربر را ثبت/به‌روزرسانی کند.
-- =============================================================================
