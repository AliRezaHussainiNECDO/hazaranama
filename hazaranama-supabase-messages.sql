-- ============================================================
-- هزاره‌نامه — «تماس با ما» و صندوق پیام‌های مدیر
-- این را بعد از hazaranama-supabase-schema.sql اجرا کنید
-- (چون از تابع public.is_admin() که در آن فایل ساخته شده استفاده می‌کند).
-- ============================================================

create type message_status as enum ('new', 'read', 'replied');

create table public.contact_messages (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  message     text not null,
  status      message_status not null default 'new',
  admin_reply text,
  created_at  timestamptz not null default now(),
  replied_at  timestamptz
);

create index idx_contact_messages_user on public.contact_messages (user_id, created_at desc);

alter table public.contact_messages enable row level security;

-- کاربر فقط پیام‌های خودش را می‌بیند؛ مدیر همه را می‌بیند
create policy "messages_select_own_or_admin" on public.contact_messages
  for select using (auth.uid() = user_id or public.is_admin());

-- کاربر فقط برای خودش پیام می‌فرستد (نه به نام دیگران) و فقط اگر مسدود نباشد
create policy "messages_insert_own" on public.contact_messages
  for insert with check (
    auth.uid() = user_id and
    (select status from public.profiles where id = auth.uid()) = 'active'
  );

-- فقط مدیر می‌تواند وضعیت/پاسخ را تغییر دهد (برای علامت‌زدن خوانده‌شده و ثبت پاسخ)
create policy "messages_admin_update" on public.contact_messages
  for update using (public.is_admin());
