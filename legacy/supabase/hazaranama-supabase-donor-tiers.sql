-- =============================================================================
-- هزاره‌نامه — مقام‌های کمک‌کننده: روش کمک (پی‌پال/حواله) + فهرست عمومی
-- کمک‌کنندگان با جمعِ دلاریِ کمک‌های تأییدشده‌ی هر کاربر.
-- =============================================================================
-- این اسکریپت باید بعد از hazaranama-supabase-donations.sql اجرا شود.
-- ایده: donation_transfers از قبل هر حواله را به یک user_id واقعی وصل می‌کند
-- (چون ارسال‌کننده باید در اپ وارد حساب باشد تا فرم را ثبت کند) — چه از طریق
-- پی‌پال کمک کرده باشد چه از طریق حواله‌ی بانکی/صرافی. این اسکریپت یک ستون
-- «method» برای تفکیک این دو کانال اضافه می‌کند، و یک ویوی عمومیِ امن
-- (donor_leaderboard) می‌سازد که فقط جمعِ کمک‌های تأییدشده‌ی هر کاربر را
-- نشان می‌دهد — نه جزئیات حساس مثل شماره تماس یا یادداشت.
-- =============================================================================

-- ------------------------------------------------------------
-- ۱) ستون روش کمک
-- ------------------------------------------------------------
alter table public.donation_transfers
  add column if not exists method text not null default 'bank_transfer'
    check (method in ('paypal', 'bank_transfer'));

create index if not exists idx_donation_transfers_method on public.donation_transfers (method);

-- ------------------------------------------------------------
-- ۲) فهرست عمومی کمک‌کنندگان — جمعِ دلاریِ تقریبیِ کمک‌های تأییدشده.
--    این ویو با اختیارات سازنده (نه فراخوان) اجرا می‌شود، پس با اینکه
--    RLS جدول donation_transfers فقط صاحب رکورد/مدیر را مجاز می‌داند، این
--    ویو می‌تواند مجموع را برای همه محاسبه کند — بدون افشای رکورد خام.
--    نرخ‌های تبدیل، ثابت و تقریبی‌اند (فقط برای رتبه‌بندی، نه حسابداری دقیق).
-- ------------------------------------------------------------
create or replace view public.donor_leaderboard as
select
  dt.user_id,
  p.name,
  p.avatar_url as avatar_path,
  sum(
    coalesce(dt.confirmed_amount, dt.amount) *
    case dt.currency
      when 'USD' then 1.0
      when 'EUR' then 1.08
      when 'CHF' then 1.12
      when 'GBP' then 1.27
      when 'AFN' then 0.014
      else 1.0
    end
  )::numeric(12, 2) as total_usd,
  count(*)::int as donation_count,
  max(dt.submitted_at) as last_donation_at
from public.donation_transfers dt
join public.profiles p on p.id = dt.user_id
where dt.status = 'confirmed'
group by dt.user_id, p.name, p.avatar_url
order by total_usd desc;

grant select on public.donor_leaderboard to authenticated;

-- =============================================================================
-- پایان — بعد از اجرای این اسکریپت:
--  • کارت پی‌پال در صفحه‌ی «کمک‌های مالی» یک دکمه‌ی «ثبت اعلام کمک پی‌پال»
--    خواهد داشت که همان فرم حواله را با method=paypal پر می‌کند.
--  • حلقه‌ی دور عکس پروفایل هر کاربر بر اساس جمعِ کمک‌های تأییدشده‌اش
--    (۱۰ مرحله) خودکار زیباتر می‌شود.
--  • صفحه‌ی «فهرست کمک‌کنندگان» از donor_leaderboard می‌خواند.
-- =============================================================================
