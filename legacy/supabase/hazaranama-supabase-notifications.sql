-- ============================================================
-- هزاره‌نامه — سیستم اعلان‌های درون‌اپی (Notifications)
-- ============================================================
-- یک جدول notifications می‌سازد + مجموعه‌ای از trigger که خودکار، هر جا در
-- اپ لازم باشد، برای کاربر درست یک اعلان می‌سازند:
--   • نظر/ریپلای روی پست شما در حافظه‌ی جمعی
--   • ریپلای روی نظر شما در ویدیوی یک هنرمند
--   • نظر/ریپلای روی مقاله‌ی برگزیده‌ی شما
--   • برگزیده‌شدن و انتشار مقاله‌ی ارسالی شما
--   • تغییر وضعیت مقاله‌ی ارسالی‌تان (رد صلاحیت / پایان دوره‌ی داوری)
--   • تأیید یا رد کمک مالی اعلام‌شده‌ی شما
--   • پاسخ پشتیبانی به پیام «تماس با ما»ی شما
-- کلاینت (اپ فلاتر) با Supabase Realtime روی همین جدول، برای هر کاربر
-- گوش می‌دهد تا اعلان تازه بی‌درنگ (بدون رفرش) روی صفحه ظاهر شود.
--
-- اجرا: در Supabase SQL Editor کامل بچسبانید و Run بزنید (idempotent).
-- باید بعد از همه‌ی اسکریپت‌های دیگر (schema، community-upgrade،
-- articles-contest، artists-videos، donations، messages) اجرا شود.
-- ============================================================

create table if not exists public.notifications (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  type       text not null,
  title      text not null,
  body       text not null default '',
  ref_id     uuid,
  ref_type   text,
  is_read    boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_user on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own" on public.notifications
  for select using (auth.uid() = user_id);

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own" on public.notifications
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ------------------------------------------------------------
-- نظر/ریپلای روی پست حافظه‌ی جمعی
-- ------------------------------------------------------------
create or replace function public.notify_on_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient uuid;
  v_commenter_name text;
begin
  select name into v_commenter_name from public.profiles where id = new.author_id;
  if new.parent_comment_id is not null then
    select author_id into v_recipient from public.comments where id = new.parent_comment_id;
  else
    select author_id into v_recipient from public.posts where id = new.post_id;
  end if;
  if v_recipient is not null and v_recipient <> new.author_id then
    insert into public.notifications (user_id, type, title, body, ref_id, ref_type)
    values (
      v_recipient,
      case when new.parent_comment_id is not null then 'post_reply' else 'post_comment' end,
      case when new.parent_comment_id is not null then coalesce(v_commenter_name, 'یک کاربر') || ' به نظر شما پاسخ داد'
           else coalesce(v_commenter_name, 'یک کاربر') || ' روی پست شما نظر داد' end,
      left(new.text, 140), new.post_id, 'post'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_on_comment on public.comments;
create trigger trg_notify_on_comment
  after insert on public.comments
  for each row execute procedure public.notify_on_comment();

-- ------------------------------------------------------------
-- ریپلای روی نظر یک ویدیو
-- ------------------------------------------------------------
create or replace function public.notify_on_video_comment_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient uuid;
  v_commenter_name text;
begin
  if new.parent_comment_id is null then
    return new;
  end if;
  select author_id into v_recipient from public.video_comments where id = new.parent_comment_id;
  select name into v_commenter_name from public.profiles where id = new.author_id;
  if v_recipient is not null and v_recipient <> new.author_id then
    insert into public.notifications (user_id, type, title, body, ref_id, ref_type)
    values (v_recipient, 'video_reply', coalesce(v_commenter_name, 'یک کاربر') || ' به نظر شما روی یک ویدیو پاسخ داد',
            left(new.text, 140), new.video_id, 'video');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_on_video_comment_reply on public.video_comments;
create trigger trg_notify_on_video_comment_reply
  after insert on public.video_comments
  for each row execute procedure public.notify_on_video_comment_reply();

-- ------------------------------------------------------------
-- نظر/ریپلای روی مقاله‌ی برگزیده
-- ------------------------------------------------------------
create or replace function public.notify_on_article_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient uuid;
  v_commenter_name text;
begin
  select name into v_commenter_name from public.profiles where id = new.author_id;
  if new.parent_comment_id is not null then
    select author_id into v_recipient from public.article_comments where id = new.parent_comment_id;
  else
    select author_id into v_recipient from public.featured_articles where id = new.featured_article_id;
  end if;
  if v_recipient is not null and v_recipient <> new.author_id then
    insert into public.notifications (user_id, type, title, body, ref_id, ref_type)
    values (
      v_recipient,
      case when new.parent_comment_id is not null then 'article_reply' else 'article_comment' end,
      case when new.parent_comment_id is not null then coalesce(v_commenter_name, 'یک کاربر') || ' به نظر شما روی یک مقاله پاسخ داد'
           else coalesce(v_commenter_name, 'یک کاربر') || ' روی مقاله‌ی برگزیده‌ی شما نظر داد' end,
      left(new.text, 140), new.featured_article_id, 'article'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_on_article_comment on public.article_comments;
create trigger trg_notify_on_article_comment
  after insert on public.article_comments
  for each row execute procedure public.notify_on_article_comment();

-- ------------------------------------------------------------
-- برگزیده‌شدن مقاله (انتشار در featured_articles)
-- ------------------------------------------------------------
create or replace function public.notify_on_article_featured()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.author_id is not null then
    insert into public.notifications (user_id, type, title, body, ref_id, ref_type)
    values (new.author_id, 'article_featured', 'مقاله‌ی شما برگزیده و منتشر شد! 🎉', new.title, new.id, 'article');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_on_article_featured on public.featured_articles;
create trigger trg_notify_on_article_featured
  after insert on public.featured_articles
  for each row execute procedure public.notify_on_article_featured();

-- ------------------------------------------------------------
-- تغییر وضعیت مقاله‌ی ارسالی (رد صلاحیت / پایان دوره‌ی داوری)
-- ------------------------------------------------------------
create or replace function public.notify_on_submission_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
  v_body text;
begin
  if new.status = old.status then
    return new;
  end if;
  if new.status = 'disqualified' then
    v_title := 'مقاله‌ی ارسالی شما رد صلاحیت شد';
    v_body := new.title;
  elsif new.status = 'closed' then
    v_title := 'دوره‌ی داوری مقاله‌ی شما تمام شد';
    v_body := new.title;
  else
    return new;
  end if;
  insert into public.notifications (user_id, type, title, body, ref_id, ref_type)
  values (new.author_id, 'article_status', v_title, v_body, new.id, 'article_submission');
  return new;
end;
$$;

drop trigger if exists trg_notify_on_submission_status on public.article_submissions;
create trigger trg_notify_on_submission_status
  after update on public.article_submissions
  for each row execute procedure public.notify_on_submission_status();

-- ------------------------------------------------------------
-- تأیید/رد کمک مالی
-- ------------------------------------------------------------
create or replace function public.notify_on_donation_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
begin
  if new.status = old.status then
    return new;
  end if;
  if new.status = 'confirmed' then
    v_title := 'کمک مالی شما تأیید شد ✓';
  elsif new.status = 'rejected' then
    v_title := 'کمک مالی اعلام‌شده‌ی شما رد شد';
  else
    return new;
  end if;
  insert into public.notifications (user_id, type, title, body, ref_id, ref_type)
  values (new.user_id, 'donation_status', v_title, new.amount::text || ' ' || new.currency, new.id, 'donation_transfer');
  return new;
end;
$$;

drop trigger if exists trg_notify_on_donation_status on public.donation_transfers;
create trigger trg_notify_on_donation_status
  after update on public.donation_transfers
  for each row execute procedure public.notify_on_donation_status();

-- ------------------------------------------------------------
-- پاسخ پشتیبانی به پیام «تماس با ما»
-- ------------------------------------------------------------
create or replace function public.notify_on_message_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'replied' and old.status <> 'replied' then
    insert into public.notifications (user_id, type, title, body, ref_id, ref_type)
    values (new.user_id, 'message_reply', 'پشتیبانی به پیام شما پاسخ داد', coalesce(left(new.admin_reply, 140), ''), new.id, 'contact_message');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_on_message_reply on public.contact_messages;
create trigger trg_notify_on_message_reply
  after update on public.contact_messages
  for each row execute procedure public.notify_on_message_reply();

-- ------------------------------------------------------------
-- فعال‌سازی Realtime روی جدول notifications — تا کلاینت بی‌درنگ خبردار شود
-- ------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

-- =============================================================================
-- پایان — از این به بعد، هر کدام از رویدادهای بالا خودکار یک اعلان در اپ
-- می‌سازد؛ ناقوسِ صفحه‌ی نخست اپ (کنار لوگو) آن را بی‌درنگ نشان می‌دهد.
-- =============================================================================
