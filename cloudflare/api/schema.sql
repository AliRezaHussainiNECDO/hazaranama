-- =====================================================================
-- هزاره‌نامه — اسکیمای پایگاه‌داده‌ی Cloudflare D1 (SQLite)
-- معادل جدول‌های قبلی Supabase/Postgres، با همان نام ستون‌ها تا خروجی API
-- برای اپ دقیقاً همان شکل قبلی را داشته باشد.
--   • شناسه‌ها: متن UUID (ساخته‌شده در Worker)
--   • زمان‌ها: متن ISO-8601 به وقت UTC (مثل 2026-10-09T21:00:00.000Z)
--   • ستون‌های JSON (fields, image_urls): متن JSON
--   • بولین‌ها: عدد ۰/۱ (Worker به true/false تبدیل می‌کند)
-- اجرای دوباره‌ی این فایل بی‌خطر است (IF NOT EXISTS).
-- =====================================================================

PRAGMA foreign_keys = ON;

-- ---------------- احراز هویت ----------------
CREATE TABLE IF NOT EXISTS users (
  id                 TEXT PRIMARY KEY,
  email              TEXT NOT NULL UNIQUE COLLATE NOCASE,
  password_hash      TEXT NOT NULL,            -- pbkdf2$iter$salt$hash  یا  bcrypt ($2a$…) برای کاربران منتقل‌شده
  token_version      INTEGER NOT NULL DEFAULT 0, -- با تغییر رمز بالا می‌رود تا نشست‌های قدیمی باطل شوند
  recovery_code_hash TEXT,
  recovery_expires   TEXT,
  recovery_requested_at TEXT,
  created_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS profiles (
  id                TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  email             TEXT NOT NULL,
  avatar_url        TEXT,
  role              TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin','editor','user')),
  status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','blocked')),
  country           TEXT,
  origin_province   TEXT,
  district          TEXT,
  tribe             TEXT,
  native_language   TEXT,
  bio               TEXT,
  terms_accepted_at TEXT,
  created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- ---------------- محتوای بخش‌ها ----------------
CREATE TABLE IF NOT EXISTS content_items (
  id          TEXT PRIMARY KEY,
  section_id  TEXT NOT NULL,
  fields      TEXT NOT NULL DEFAULT '{}',
  image_url   TEXT,
  video_url   TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_by  TEXT REFERENCES profiles(id) ON DELETE SET NULL,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_content_items_section ON content_items (section_id, sort_order);

-- ---------------- حافظه‌ی جمعی ----------------
CREATE TABLE IF NOT EXISTS posts (
  id                  TEXT PRIMARY KEY,
  author_id           TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  text                TEXT NOT NULL,
  image_urls          TEXT NOT NULL DEFAULT '[]',
  video_url           TEXT,
  video_thumbnail_url TEXT,
  comments_count      INTEGER NOT NULL DEFAULT 0,
  created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_posts_created ON posts (created_at DESC);

CREATE TABLE IF NOT EXISTS comments (
  id                TEXT PRIMARY KEY,
  post_id           TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  author_id         TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  parent_comment_id TEXT REFERENCES comments(id) ON DELETE CASCADE,
  text              TEXT NOT NULL,
  created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_comments_post ON comments (post_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent ON comments (parent_comment_id);

CREATE TABLE IF NOT EXISTS reactions (
  id         TEXT PRIMARY KEY,
  post_id    TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id    TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  emoji      TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE (post_id, user_id, emoji)
);
CREATE INDEX IF NOT EXISTS idx_reactions_post ON reactions (post_id);

CREATE TABLE IF NOT EXISTS comment_likes (
  id         TEXT PRIMARY KEY,
  comment_id TEXT NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  user_id    TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE (comment_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_comment_likes_comment ON comment_likes (comment_id);

-- ---------------- تماس با ما ----------------
CREATE TABLE IF NOT EXISTS contact_messages (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  message     TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new','read','replied')),
  admin_reply TEXT,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  replied_at  TEXT
);
CREATE INDEX IF NOT EXISTS idx_contact_messages_user ON contact_messages (user_id, created_at DESC);

-- ---------------- موسیقی و ویدیو ----------------
CREATE TABLE IF NOT EXISTS artists (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  bio         TEXT,
  avatar_url  TEXT,
  cover_url   TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_by  TEXT REFERENCES profiles(id) ON DELETE SET NULL,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS artist_videos (
  id            TEXT PRIMARY KEY,
  artist_id     TEXT NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  description   TEXT,
  video_url     TEXT NOT NULL,
  thumbnail_url TEXT,
  views_count   INTEGER NOT NULL DEFAULT 0,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  created_by    TEXT REFERENCES profiles(id) ON DELETE SET NULL,
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_artist_videos_artist ON artist_videos (artist_id, sort_order);

CREATE TABLE IF NOT EXISTS video_comments (
  id                TEXT PRIMARY KEY,
  video_id          TEXT NOT NULL REFERENCES artist_videos(id) ON DELETE CASCADE,
  author_id         TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  parent_comment_id TEXT REFERENCES video_comments(id) ON DELETE CASCADE,
  text              TEXT NOT NULL,
  created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_video_comments_video ON video_comments (video_id, created_at);

CREATE TABLE IF NOT EXISTS video_reactions (
  id         TEXT PRIMARY KEY,
  video_id   TEXT NOT NULL REFERENCES artist_videos(id) ON DELETE CASCADE,
  user_id    TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  emoji      TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE (video_id, user_id, emoji)
);
CREATE INDEX IF NOT EXISTS idx_video_reactions_video ON video_reactions (video_id);

-- ---------------- مسابقه‌ی مقالات ----------------
CREATE TABLE IF NOT EXISTS article_submissions (
  id               TEXT PRIMARY KEY,
  author_id        TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title            TEXT NOT NULL,
  body             TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','closed','disqualified','published')),
  ai_verdict       TEXT CHECK (ai_verdict IN ('original','suspicious','likely_ai_or_copied')),
  ai_confidence    REAL,
  ai_quality_score REAL,
  ai_notes         TEXT,
  submitted_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_article_submissions_author ON article_submissions (author_id, submitted_at DESC);

CREATE TABLE IF NOT EXISTS featured_articles (
  id            TEXT PRIMARY KEY,
  submission_id TEXT REFERENCES article_submissions(id) ON DELETE SET NULL,
  author_id     TEXT REFERENCES profiles(id) ON DELETE SET NULL,
  author_name   TEXT NOT NULL,
  author_avatar TEXT,
  title         TEXT NOT NULL,
  body          TEXT NOT NULL,
  placement     INTEGER NOT NULL CHECK (placement IN (1,2,3)),
  month_label   TEXT NOT NULL,
  prize         TEXT,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  published_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS article_comments (
  id                  TEXT PRIMARY KEY,
  featured_article_id TEXT NOT NULL REFERENCES featured_articles(id) ON DELETE CASCADE,
  author_id           TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  parent_comment_id   TEXT REFERENCES article_comments(id) ON DELETE CASCADE,
  text                TEXT NOT NULL,
  created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_article_comments_article ON article_comments (featured_article_id, created_at);

CREATE TABLE IF NOT EXISTS article_reactions (
  id                  TEXT PRIMARY KEY,
  featured_article_id TEXT NOT NULL REFERENCES featured_articles(id) ON DELETE CASCADE,
  user_id             TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  emoji               TEXT NOT NULL,
  created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE (featured_article_id, user_id, emoji)
);

CREATE TABLE IF NOT EXISTS contest_settings (
  id               INTEGER PRIMARY KEY CHECK (id = 1),
  topic            TEXT NOT NULL DEFAULT 'موضوع این دوره هنوز از سوی مدیریت تعیین نشده است',
  prize_first      TEXT,
  prize_second     TEXT,
  prize_third      TEXT,
  round_started_at TEXT,
  updated_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
INSERT OR IGNORE INTO contest_settings (id) VALUES (1);

-- ---------------- کمک‌های مالی ----------------
CREATE TABLE IF NOT EXISTS donation_transfers (
  id                 TEXT PRIMARY KEY,
  user_id            TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  sender_name        TEXT NOT NULL,
  sender_country     TEXT NOT NULL,
  sender_contact     TEXT,
  amount             REAL NOT NULL CHECK (amount > 0),
  currency           TEXT NOT NULL DEFAULT 'USD',
  transfer_reference TEXT,
  note               TEXT,
  category           TEXT NOT NULL DEFAULT 'general' CHECK (category IN ('family','hospital','school','roads','general')),
  method             TEXT NOT NULL DEFAULT 'bank_transfer' CHECK (method IN ('paypal','bank_transfer')),
  status             TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','confirmed','rejected')),
  confirmed_amount   REAL,
  submitted_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  confirmed_at       TEXT
);
CREATE INDEX IF NOT EXISTS idx_donation_transfers_user ON donation_transfers (user_id, submitted_at DESC);

CREATE TABLE IF NOT EXISTS donation_reports (
  id                  TEXT PRIMARY KEY,
  title               TEXT NOT NULL,
  category            TEXT NOT NULL DEFAULT 'general' CHECK (category IN ('family','hospital','school','roads','general')),
  summary             TEXT NOT NULL,
  body                TEXT NOT NULL,
  amount_spent        REAL,
  currency            TEXT NOT NULL DEFAULT 'USD',
  image_urls          TEXT NOT NULL DEFAULT '[]',
  video_url           TEXT,
  location            TEXT,
  beneficiaries_count INTEGER,
  created_by          TEXT REFERENCES profiles(id) ON DELETE SET NULL,
  published_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS donation_settings (
  id                 INTEGER PRIMARY KEY CHECK (id = 1),
  total_raised       REAL NOT NULL DEFAULT 0,
  currency           TEXT NOT NULL DEFAULT 'USD',
  families_helped    INTEGER NOT NULL DEFAULT 0,
  projects_completed INTEGER NOT NULL DEFAULT 0,
  updated_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
INSERT OR IGNORE INTO donation_settings (id) VALUES (1);

-- ---------------- اعلان‌ها و دستگاه‌ها ----------------
CREATE TABLE IF NOT EXISTS notifications (
  id         TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type       TEXT NOT NULL,
  title      TEXT NOT NULL,
  body       TEXT NOT NULL DEFAULT '',
  ref_id     TEXT,
  ref_type   TEXT,
  is_read    INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS device_tokens (
  id         TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token      TEXT NOT NULL UNIQUE,
  platform   TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens (user_id);

CREATE TABLE IF NOT EXISTS daily_visits (
  day   TEXT PRIMARY KEY,
  count INTEGER NOT NULL DEFAULT 0
);

-- ---------------- نظارت ----------------
CREATE TABLE IF NOT EXISTS content_reports (
  id              TEXT PRIMARY KEY,
  reporter_id     TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  target_type     TEXT NOT NULL CHECK (target_type IN ('post','comment','user')),
  target_id       TEXT NOT NULL,
  target_owner_id TEXT REFERENCES profiles(id) ON DELETE SET NULL,
  target_preview  TEXT,
  reason          TEXT NOT NULL,
  note            TEXT,
  status          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','reviewed','dismissed')),
  created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS blocked_users (
  id                 TEXT PRIMARY KEY,
  blocker_id         TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  blocked_id         TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  blocked_name       TEXT,
  blocked_avatar_url TEXT,
  created_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

-- ---------------- انتقال داده از Supabase ----------------
CREATE TABLE IF NOT EXISTS _import_staging (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  tbl        TEXT NOT NULL,
  data       TEXT NOT NULL,
  applied    INTEGER NOT NULL DEFAULT 0,
  result     TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- ---------------- ویوها ----------------
DROP VIEW IF EXISTS donor_leaderboard;
CREATE VIEW donor_leaderboard AS
SELECT
  dt.user_id AS user_id,
  p.name AS name,
  p.avatar_url AS avatar_path,
  ROUND(SUM(COALESCE(dt.confirmed_amount, dt.amount) *
    CASE dt.currency WHEN 'USD' THEN 1.0 WHEN 'EUR' THEN 1.08 WHEN 'CHF' THEN 1.12
                     WHEN 'GBP' THEN 1.27 WHEN 'AFN' THEN 0.014 ELSE 1.0 END), 2) AS total_usd,
  COUNT(*) AS donation_count,
  MAX(dt.submitted_at) AS last_donation_at
FROM donation_transfers dt
JOIN profiles p ON p.id = dt.user_id
WHERE dt.status = 'confirmed'
GROUP BY dt.user_id, p.name, p.avatar_url;

-- user_activity_log در خودِ Worker ساخته می‌شود (D1 اجتماع بیش از ۵ SELECT را نمی‌پذیرد).
DROP VIEW IF EXISTS user_activity_log;

-- شمار تلاش‌های نادرست برای کد بازیابی (پس از ۵ بار، کد باطل می‌شود)
CREATE TABLE IF NOT EXISTS recovery_attempts (
  user_id    TEXT PRIMARY KEY,
  n          INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
