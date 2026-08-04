-- =============================================================================
-- هزاره‌نامه — پرونده‌ی کامل کاربر برای پنل مدیریت: تاریخچه‌ی یکجای همه‌ی
-- فعالیت‌های هر کاربر در سراسر اپ (پست، کامنت، واکنش، مقاله، حواله، پیام).
-- =============================================================================
-- این اسکریپت باید بعد از تمام اسکریپت‌های دیگر (schema، messages،
-- articles-contest، artists-videos، community-upgrade، donations) اجرا شود،
-- چون از جدول‌های همه‌ی آن‌ها می‌خواند.
--
-- ویوی user_activity_log هر فعالیتِ هر کاربر را (پست تازه، کامنت روی پست/
-- ویدیو/مقاله، ارسال مقاله برای مسابقه، اعلام حواله، پیام تماس، واکنش ایموجی
-- روی پست/ویدیو/مقاله، لایک یک نظر) در یک ردیف یکسان (user_id, activity_type,
-- ref_id, summary, occurred_at) کنار هم می‌آورد تا پرونده‌ی هر کاربر در پنل
-- مدیریت یک جدول زمانیِ کامل داشته باشد.
--
-- امنیت: این ویو با اختیارات سازنده (نه فراخوان) اجرا می‌شود، پس با اینکه
-- کاربر عادی طبق RLS فقط رکوردهای خودش را می‌بیند، این ویو می‌تواند همه‌ی
-- رکوردها را بخواند — به همین دلیل شرط «where public.is_admin()» را روی کل
-- نتیجه گذاشته‌ایم تا فقط مدیر بتواند از آن بخواند (کاربر عادی صفر ردیف
-- می‌گیرد، نه خطا).
-- =============================================================================

create or replace view public.user_activity_log as
select * from (
  select author_id as user_id, 'post'::text as activity_type, id as ref_id,
         left(text, 140) as summary, created_at as occurred_at
  from public.posts

  union all
  select author_id, 'post_comment', id, left(text, 140), created_at
  from public.comments

  union all
  select author_id, 'video_comment', id, left(text, 140), created_at
  from public.video_comments

  union all
  select author_id, 'article_submission', id, title, submitted_at
  from public.article_submissions

  union all
  select author_id, 'article_comment', id, left(text, 140), created_at
  from public.article_comments

  union all
  select user_id, 'donation_transfer', id,
         (amount::text || ' ' || currency || ' — ' || status), submitted_at
  from public.donation_transfers

  union all
  select user_id, 'contact_message', id, left(message, 140), created_at
  from public.contact_messages

  union all
  select user_id, 'post_reaction', post_id, emoji, created_at
  from public.reactions

  union all
  select user_id, 'video_reaction', video_id, emoji, created_at
  from public.video_reactions

  union all
  select user_id, 'article_reaction', featured_article_id, emoji, created_at
  from public.article_reactions

  union all
  select user_id, 'comment_like', comment_id, 'یک نظر را پسندید'::text, created_at
  from public.comment_likes
) activity
where public.is_admin()
order by occurred_at desc;

grant select on public.user_activity_log to authenticated;

-- =============================================================================
-- پایان — بعد از اجرای این اسکریپت، پرونده‌ی هر کاربر در پنل مدیریت →
-- «کاربران» یک جدول زمانیِ کامل از همه‌ی فعالیت‌هایش (به‌همراه شمار هر نوع)
-- نشان می‌دهد.
-- =============================================================================
