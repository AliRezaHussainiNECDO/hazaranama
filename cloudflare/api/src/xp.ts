// =====================================================================
// امتیاز فعالیت (XP) و مقام کاربران — از همه‌ی بخش‌های اپ، نه از کمک مالی.
// هر کاری که کاربر در هزاره‌نامه می‌کند امتیاز دارد: آمدن روزانه، خواندن
// روایت‌ها و مقاله‌ها، تماشای ویدیو، دانلود کتاب، خواندن خبر، پست و کامنت،
// واکنش، لایک گرفتن، شرکت در مسابقه‌ی مقالات، برنده‌شدن و جایزه‌ی مدیر.
// کمک مالی عمداً بیرون است تا مقام قابل خرید نباشد (و با قانون ۳.۱.۱ اپل
// هم سازگار بماند).
// =====================================================================
import type { Env } from "./types";

/** امتیاز هر نوع فعالیت — همان جدولی که اپ در «راه‌های گرفتن امتیاز» نشان می‌دهد */
export const XP_RULES = {
  visit: 5, // هر روز آمدن به اپ
  read: 2, // خواندن یک روایت، مقاله، شخصیت یا رویداد (هر کدام یک بار)
  video: 2, // تماشای یک ویدیو (هر کدام یک بار)
  book: 3, // دانلود یا خواندن یک کتاب
  news: 1, // خواندن یک خبر
  post: 15, // انتشار پست در «حافظه‌ی جمعی»
  comment: 4, // کامنت روی پست، ویدیو یا مقاله
  reaction: 1, // واکنش و لایک
  liked: 2, // هر لایکی که دیگران به پست شما می‌دهند
  article: 25, // فرستادن مقاله به مسابقه
  featured: 100, // مقاله‌ی برگزیده (برای رتبه‌ی اول ۳۰۰، دوم ۲۰۰، سوم ۱۰۰)
} as const;

export const EVENT_KINDS = ["visit", "read", "video", "book", "news"] as const;
export type EventKind = (typeof EVENT_KINDS)[number];

/** سقف رویدادهای خواندنی در روز — جلوی امتیازسازی با کلیک‌های پشت‌سرهم */
const DAILY_EVENT_CAP = 80;

export type XpStats = {
  visit: number; read: number; video: number; book: number; news: number;
  post: number; comment: number; reaction: number; liked: number; article: number; featured: number; bonus: number;
};
export type XpEntry = { user_id: string; name: string; avatar_path: string | null; role: string; xp: number; stats: XpStats };

const empty = (): XpStats => ({ visit: 0, read: 0, video: 0, book: 0, news: 0, post: 0, comment: 0, reaction: 0, liked: 0, article: 0, featured: 0, bonus: 0 });

export function xpOf(s: XpStats): number {
  return (
    s.visit * XP_RULES.visit + s.read * XP_RULES.read + s.video * XP_RULES.video + s.book * XP_RULES.book + s.news * XP_RULES.news +
    s.post * XP_RULES.post + s.comment * XP_RULES.comment + s.reaction * XP_RULES.reaction + s.liked * XP_RULES.liked +
    s.article * XP_RULES.article + s.featured * XP_RULES.featured + s.bonus
  );
}

let cache: { at: number; list: XpEntry[] } | null = null;
export function invalidateXp() {
  cache = null;
}

/** امتیاز همه‌ی کاربران فعال — با چند پرس‌وجوی گروهی، و نیم‌دقیقه نگه‌داری در حافظه */
export async function allXp(env: Env): Promise<XpEntry[]> {
  if (cache && Date.now() - cache.at < 30_000) return cache.list;
  const q = async (sql: string) => ((await env.DB.prepare(sql).all<{ u: string; c: number; k?: string }>()).results ?? []);
  const [profiles, posts, comments, vcomments, acomments, reactions, vreactions, areactions, clikes, liked, articles, featured, events] = await Promise.all([
    env.DB.prepare("SELECT id, name, avatar_url, role, COALESCE(xp_bonus, 0) AS bonus FROM profiles WHERE status = 'active'").all<{ id: string; name: string; avatar_url: string | null; role: string; bonus: number }>(),
    q("SELECT author_id AS u, COUNT(*) AS c FROM posts GROUP BY author_id"),
    q("SELECT author_id AS u, COUNT(*) AS c FROM comments GROUP BY author_id"),
    q("SELECT author_id AS u, COUNT(*) AS c FROM video_comments GROUP BY author_id"),
    q("SELECT author_id AS u, COUNT(*) AS c FROM article_comments GROUP BY author_id"),
    q("SELECT user_id AS u, COUNT(*) AS c FROM reactions GROUP BY user_id"),
    q("SELECT user_id AS u, COUNT(*) AS c FROM video_reactions GROUP BY user_id"),
    q("SELECT user_id AS u, COUNT(*) AS c FROM article_reactions GROUP BY user_id"),
    q("SELECT user_id AS u, COUNT(*) AS c FROM comment_likes GROUP BY user_id"),
    q("SELECT p.author_id AS u, COUNT(*) AS c FROM reactions r JOIN posts p ON p.id = r.post_id WHERE r.user_id != p.author_id GROUP BY p.author_id"),
    q("SELECT author_id AS u, COUNT(*) AS c FROM article_submissions WHERE status != 'disqualified' GROUP BY author_id"),
    q("SELECT author_id AS u, SUM(4 - placement) AS c FROM featured_articles WHERE author_id IS NOT NULL GROUP BY author_id"),
    q("SELECT user_id AS u, kind AS k, COUNT(*) AS c FROM user_events GROUP BY user_id, kind"),
  ]);
  const map = new Map<string, XpEntry>();
  for (const p of profiles.results ?? []) {
    const s = empty();
    s.bonus = Number(p.bonus) || 0;
    map.set(p.id, { user_id: p.id, name: p.name, avatar_path: p.avatar_url, role: p.role, xp: 0, stats: s });
  }
  const add = (rows: { u: string; c: number }[], key: keyof XpStats) => {
    for (const r of rows) {
      const e = map.get(r.u);
      if (e) e.stats[key] += Number(r.c) || 0;
    }
  };
  add(posts, "post");
  add(comments, "comment");
  add(vcomments, "comment");
  add(acomments, "comment");
  add(reactions, "reaction");
  add(vreactions, "reaction");
  add(areactions, "reaction");
  add(clikes, "reaction");
  add(liked, "liked");
  add(articles, "article");
  add(featured, "featured");
  for (const r of events) {
    const e = map.get(r.u);
    if (e && r.k && (EVENT_KINDS as readonly string[]).includes(r.k)) e.stats[r.k as EventKind] += Number(r.c) || 0;
  }
  const list = [...map.values()];
  for (const e of list) e.xp = Math.max(0, xpOf(e.stats));
  list.sort((a, b) => b.xp - a.xp);
  cache = { at: Date.now(), list };
  return list;
}

/** ثبت یک فعالیت (خواندن، تماشا، دانلود، آمدن روزانه) — هر مورد یک بار امتیاز دارد */
export async function trackEvent(env: Env, userId: string, kindRaw: unknown, refRaw: unknown): Promise<{ added: boolean }> {
  const kind = String(kindRaw ?? "");
  if (!(EVENT_KINDS as readonly string[]).includes(kind)) return { added: false };
  const today = new Date().toISOString().slice(0, 10);
  const ref = kind === "visit" ? today : String(refRaw ?? "").slice(0, 120);
  if (!ref) return { added: false };
  if (kind !== "visit") {
    const n = await env.DB.prepare("SELECT COUNT(*) AS c FROM user_events WHERE user_id = ? AND created_at >= ?").bind(userId, today).first<{ c: number }>();
    if ((n?.c ?? 0) >= DAILY_EVENT_CAP) return { added: false };
  }
  const r = await env.DB.prepare("INSERT OR IGNORE INTO user_events (user_id, kind, ref) VALUES (?, ?, ?)").bind(userId, kind, ref).run();
  const added = (r.meta?.changes ?? 0) > 0;
  if (added) invalidateXp();
  return { added };
}
