-- ============================================================
-- هزاره‌نامه — بخش «کمک‌های مالی» (حواله‌ی بانکی + شفافیت مصرف)
-- ============================================================
-- این اسکریپت سه بخش تازه می‌سازد:
--   ۱) donation_transfers — وقتی کاربری از طریق حواله (نه پی‌پال) کمک
--      می‌فرستد، جزئیات ارسال‌کننده (نام، کشور، مبلغ، شماره‌ی حواله) را
--      اینجا ثبت می‌کند تا مدیر بعد از دریافتِ واقعیِ پول، آن را تأیید کند.
--      خودِ انتقال پول همیشه بیرون از اپ و به‌صورت دستی انجام می‌شود — این
--      جدول فقط برای تطبیق و پیگیری است، نه پردازش مالی.
--   ۲) donation_reports — گزارش‌های شفافیتِ مصرف کمک‌ها که مدیر (با کمک
--      هوش مصنوعی برای نگارش) همراه با عکس/ویدیوی مستند منتشر می‌کند؛
--      عمومی و برای همه قابل‌دیدن است.
--   ۳) donation_settings — یک ردیف تکی برای آمار کلیِ کمپین (مجموع
--      جمع‌شده، تعداد خانواده‌های کمک‌شده، تعداد پروژه‌های تکمیل‌شده) که
--      چون پرداخت پی‌پال به این اپ متصل نیست، مدیر دستی به‌روز نگه می‌دارد.
--   + باکت Storage به نام donation-media برای عکس/ویدیوی گزارش‌های شفافیت.
--
-- اجرا: در Supabase SQL Editor کامل بچسبانید و Run بزنید (idempotent).
-- باید بعد از hazaranama-supabase-schema.sql اجرا شود (از is_admin() و
-- profiles استفاده می‌کند).
-- ============================================================

-- ------------------------------------------------------------
-- ۱) حواله‌های اعلام‌شده توسط کاربران
-- ------------------------------------------------------------
create table if not exists public.donation_transfers (
  id                uuid primary key default uuid_generate_v4(),
  user_id           uuid not null references public.profiles (id) on delete cascade,
  sender_name       text not null,
  sender_country    text not null,
  sender_contact    text,
  amount            numeric not null check (amount > 0),
  currency          text not null default 'USD',
  transfer_reference text,
  note              text,
  category          text not null default 'general'
                      check (category in ('family', 'hospital', 'school', 'roads', 'general')),
  status            text not null default 'pending'
                      check (status in ('pending', 'confirmed', 'rejected')),
  confirmed_amount  numeric,
  submitted_at      timestamptz not null default now(),
  confirmed_at      timestamptz
);

create index if not exists idx_donation_transfers_user on public.donation_transfers (user_id, submitted_at desc);
create index if not exists idx_donation_transfers_status on public.donation_transfers (status);

-- ------------------------------------------------------------
-- ۲) گزارش‌های شفافیت (عمومی)
-- ------------------------------------------------------------
create table if not exists public.donation_reports (
  id                 uuid primary key default uuid_generate_v4(),
  title              text not null,
  category           text not null default 'general'
                       check (category in ('family', 'hospital', 'school', 'roads', 'general')),
  summary            text not null,
  body               text not null,
  amount_spent       numeric,
  currency           text not null default 'USD',
  image_urls         text[] not null default '{}',
  video_url          text,
  location           text,
  beneficiaries_count int,
  created_by         uuid references public.profiles (id) on delete set null,
  published_at       timestamptz not null default now()
);

create index if not exists idx_donation_reports_published on public.donation_reports (published_at desc);

-- ------------------------------------------------------------
-- ۳) آمار کلیِ کمپین (تک‌ردیفی)
-- ------------------------------------------------------------
create table if not exists public.donation_settings (
  id                   int primary key default 1,
  total_raised         numeric not null default 0,
  currency             text not null default 'USD',
  families_helped      int not null default 0,
  projects_completed   int not null default 0,
  updated_at           timestamptz not null default now(),
  constraint donation_settings_singleton check (id = 1)
);

insert into public.donation_settings (id)
values (1)
on conflict (id) do nothing;

-- ------------------------------------------------------------
-- ۴) RLS
-- ------------------------------------------------------------
alter table public.donation_transfers enable row level security;
alter table public.donation_reports   enable row level security;
alter table public.donation_settings  enable row level security;

-- حواله‌ها: کاربر فقط حواله‌های خودش را می‌بیند؛ مدیر همه را می‌بیند
drop policy if exists "donation_transfers_select_own_or_admin" on public.donation_transfers;
create policy "donation_transfers_select_own_or_admin" on public.donation_transfers
  for select using (auth.uid() = user_id or public.is_admin());

-- کاربر فعال فقط برای خودش حواله ثبت می‌کند
drop policy if exists "donation_transfers_insert_own" on public.donation_transfers;
create policy "donation_transfers_insert_own" on public.donation_transfers
  for insert with check (
    auth.uid() = user_id and
    (select status from public.profiles where id = auth.uid()) = 'active'
  );

-- فقط مدیر می‌تواند وضعیت/مبلغ تأییدشده را تغییر دهد
drop policy if exists "donation_transfers_admin_update" on public.donation_transfers;
create policy "donation_transfers_admin_update" on public.donation_transfers
  for update using (public.is_admin());

-- گزارش‌های شفافیت: خواندن برای همه؛ نوشتن فقط مدیر
drop policy if exists "donation_reports_select_all" on public.donation_reports;
create policy "donation_reports_select_all" on public.donation_reports for select using (true);
drop policy if exists "donation_reports_admin_insert" on public.donation_reports;
create policy "donation_reports_admin_insert" on public.donation_reports for insert with check (public.is_admin());
drop policy if exists "donation_reports_admin_update" on public.donation_reports;
create policy "donation_reports_admin_update" on public.donation_reports for update using (public.is_admin());
drop policy if exists "donation_reports_admin_delete" on public.donation_reports;
create policy "donation_reports_admin_delete" on public.donation_reports for delete using (public.is_admin());

-- آمار کلی: خواندن برای همه؛ نوشتن/ویرایش فقط مدیر
drop policy if exists "donation_settings_select_all" on public.donation_settings;
create policy "donation_settings_select_all" on public.donation_settings for select using (true);
drop policy if exists "donation_settings_admin_insert" on public.donation_settings;
create policy "donation_settings_admin_insert" on public.donation_settings
  for insert with check (public.is_admin());
drop policy if exists "donation_settings_admin_update" on public.donation_settings;
create policy "donation_settings_admin_update" on public.donation_settings
  for update using (public.is_admin());

-- ------------------------------------------------------------
-- ۵) باکت Storage برای عکس/ویدیوی گزارش‌های شفافیت
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('donation-media', 'donation-media', true)
on conflict (id) do nothing;

drop policy if exists "donation_media_public_read" on storage.objects;
create policy "donation_media_public_read"
on storage.objects for select
using (bucket_id = 'donation-media');

drop policy if exists "donation_media_admin_write" on storage.objects;
create policy "donation_media_admin_write"
on storage.objects for insert
with check (bucket_id = 'donation-media' and public.is_admin());

drop policy if exists "donation_media_admin_update" on storage.objects;
create policy "donation_media_admin_update"
on storage.objects for update
using (bucket_id = 'donation-media' and public.is_admin());

drop policy if exists "donation_media_admin_delete" on storage.objects;
create policy "donation_media_admin_delete"
on storage.objects for delete
using (bucket_id = 'donation-media' and public.is_admin());

-- ============================================================
-- پایان — بعد از اجرای موفق این فایل، از پنل مدیریت → «کمک‌های مالی» می‌توانید
-- حواله‌های ارسالی را تأیید کنید، گزارش شفافیت با عکس/ویدیو منتشر کنید، و
-- آمار کلی (مجموع جمع‌شده/خانواده‌های کمک‌شده) را به‌روز نگه دارید.
-- ============================================================
