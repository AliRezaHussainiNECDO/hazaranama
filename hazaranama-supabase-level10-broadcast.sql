-- =============================================================================
-- هزاره‌نامه — نوتیفیکیشن سراسری هنگام رسیدن یک کاربر به مرحله‌ی ۱۰: «پادشاه»
-- =============================================================================
-- وقتی یک حواله/اعلام‌کمک به وضعیت «confirmed» می‌رسد، این trigger مجموع
-- دلاریِ کمک‌های تأییدشده‌ی همان کاربر را (با همان نرخ‌های ثابتِ ویوی
-- donor_leaderboard) پیش و پس از این تراکنش حساب می‌کند. اگر این تراکنش
-- دقیقاً همان چیزی باشد که کاربر را برای اولین بار به آستانه‌ی مرحله‌ی ۱۰
-- (۱۰۰۰ دلار — باید با kDonorTiers.last.minUsd در lib/core/donor_tiers.dart
-- هماهنگ بماند) می‌رساند، برای همه‌ی کاربران هزاره‌نامه یک اعلان درون‌اپی
-- می‌سازد؛ چون هر ردیف تازه در notifications به‌صورت خودکار (با
-- hazaranama-supabase-push-trigger.sql) پوش هم می‌فرستد، این یعنی پوش
-- سراسری هم رایگان همراهش می‌آید.
--
-- اجرا: در Supabase SQL Editor کامل بچسبانید و Run بزنید (idempotent).
-- باید بعد از hazaranama-supabase-donor-tiers.sql و
-- hazaranama-supabase-notifications.sql اجرا شود.
-- =============================================================================

create or replace function public.notify_on_level10_reached()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_threshold constant numeric := 1000; -- باید با kDonorTiers.last.minUsd هماهنگ بماند
  v_rate numeric;
  v_amount_usd numeric;
  v_total_before numeric;
  v_total_after numeric;
  v_name text;
begin
  -- فقط وقتی حواله همین الان به «confirmed» تغییر کرده (نه هر آپدیت دیگری)
  if new.status <> 'confirmed' or old.status = 'confirmed' then
    return new;
  end if;

  v_rate := case new.currency
    when 'USD' then 1.0
    when 'EUR' then 1.08
    when 'CHF' then 1.12
    when 'GBP' then 1.27
    when 'AFN' then 0.014
    else 1.0
  end;
  v_amount_usd := coalesce(new.confirmed_amount, new.amount) * v_rate;

  select coalesce(sum(
    coalesce(dt.confirmed_amount, dt.amount) *
    case dt.currency
      when 'USD' then 1.0
      when 'EUR' then 1.08
      when 'CHF' then 1.12
      when 'GBP' then 1.27
      when 'AFN' then 0.014
      else 1.0
    end
  ), 0)
  into v_total_before
  from public.donation_transfers dt
  where dt.user_id = new.user_id and dt.status = 'confirmed' and dt.id <> new.id;

  v_total_after := v_total_before + v_amount_usd;

  if v_total_before < v_threshold and v_total_after >= v_threshold then
    select name into v_name from public.profiles where id = new.user_id;

    insert into public.notifications (user_id, type, title, body, ref_id, ref_type)
    select
      p.id,
      'level10_reached',
      'کاربر ' || coalesce(v_name, 'یک کاربر هزاره‌نامه') || ' به مقام پادشاهی (مرحله ۱۰) دست یافت! 👑',
      'با کمک‌های تأییدشده‌اش، بالاترین مقام هزاره‌نامه را باز کرد.',
      new.user_id,
      'donor_tier'
    from public.profiles p;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_on_level10_reached on public.donation_transfers;
create trigger trg_notify_on_level10_reached
  after update on public.donation_transfers
  for each row execute procedure public.notify_on_level10_reached();

-- =============================================================================
-- پایان — از این به بعد، اولین باری که مجموع کمک‌های تأییدشده‌ی یک کاربر به
-- ۱۰۰۰ دلار می‌رسد، همه‌ی کاربران یک اعلان درون‌اپی + پوش دریافت می‌کنند.
-- چون شرط «قبلاً کمتر از آستانه، حالا بیشتر/مساوی» فقط یک‌بار true می‌شود،
-- این اعلان دوباره تکرار نخواهد شد (مگر با کاهش دستی رکوردهای تأییدشده).
-- =============================================================================
