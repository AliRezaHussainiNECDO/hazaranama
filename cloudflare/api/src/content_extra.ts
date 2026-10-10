// عکس‌های آزاد Wikimedia Commons (آینه‌شده در R2) و خبرنامه‌ی خودکار.
import type { Env } from "./types";
import seedContent from "../seed/content.json";

const UA = "HazaranamaBot/1.0 (https://hazaranama.com; no-reply@hazaranama.com)";

/** نقشه‌ی کلید R2 ← نشانی اصلی فایل در Commons (ساخته‌شده در seed/build.py) */
function mirrorMap(): Record<string, string> {
  return ((seedContent as { mirror?: Record<string, string> }).mirror ?? {}) as Record<string, string>;
}

/** اگر کلید از عکس‌های Commons است و هنوز در R2 نیست، یک‌بار از منبع می‌گیرد و ذخیره می‌کند. */
export async function mirrorCommons(env: Env, key: string): Promise<boolean> {
  const src = mirrorMap()[key];
  if (!src) return false;
  const res = await fetch(src, { headers: { "User-Agent": UA } });
  if (!res.ok || !res.body) {
    console.error("commons", res.status, src);
    return false;
  }
  const type = res.headers.get("content-type") ?? "image/jpeg";
  if (!type.startsWith("image/")) return false;
  await env.MEDIA.put(key, res.body, { httpMetadata: { contentType: type, cacheControl: "public, max-age=31536000, immutable" } });
  return true;
}

/** در هر اجرای cron چند عکس را از پیش آینه می‌کند تا نخستین بازدیدکننده منتظر نماند. */
export async function prewarmMirror(env: Env, budget: number) {
  const keys = Object.keys(mirrorMap());
  if (!keys.length) return;
  const done = await env.DB.prepare("SELECT value FROM _meta WHERE key = 'mirror_done'").first<{ value: string }>();
  const version = (seedContent as { version?: string }).version ?? "";
  if (done?.value === version) return;
  let n = 0;
  for (const k of keys) {
    if (n >= budget) return;
    if (await env.MEDIA.head(k)) continue;
    n++;
    await mirrorCommons(env, k).catch((e) => console.error("mirror", k, e));
  }
  if (n === 0) await env.DB.prepare("INSERT OR REPLACE INTO _meta (key, value) VALUES ('mirror_done', ?)").bind(version).run();
}

// ---------------- خبرنامه‌ی خودکار ----------------
// فقط عنوان، نام رسانه، تاریخ و لینک به خبر اصلی ذخیره می‌شود (نه متن خبر).
const FEEDS = [
  "https://news.google.com/rss/search?q=%22Hazara%22+(Afghanistan+OR+Taliban+OR+Quetta+OR+Bamyan+OR+Kabul+OR+refugees)&hl=en-US&gl=US&ceid=US:en",
  "https://news.google.com/rss/search?q=Hazaras&hl=en-GB&gl=GB&ceid=GB:en",
  "https://news.google.com/rss/search?q=%D9%87%D8%B2%D8%A7%D8%B1%D9%87%E2%80%8C%D9%87%D8%A7&hl=fa&gl=IR&ceid=IR:fa",
];
const RELEVANT = /hazara|هزاره|هزارگی|بامیان|bamyan|bamiyan|daykundi|دایکندی|dasht-e-barchi|دشت.?برچی|quetta|کویته/i;
// «هزاره» در پاکستان نام یک منطقه‌ی جغرافیایی (ایبت‌آباد، مانسهره…) هم هست
const NOISE = /hazara (division|motorway|expressway|university|region|electric|police)|abbottabad|mansehra|haripur|battagram|kohistan|torghar|ایبت.?آباد|مانسهره/i;

function decode(s: string) {
  return s
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'")
    .replace(/<[^>]+>/g, "")
    .trim();
}

async function sha(s: string) {
  const d = await crypto.subtle.digest("SHA-1", new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 16);
}

export async function fetchNews(env: Env, force = false): Promise<{ added: number; skipped?: string }> {
  if (!force) {
    const last = await env.DB.prepare("SELECT value FROM _meta WHERE key = 'news_fetched_at_v2'").first<{ value: string }>();
    if (last && Date.now() - Date.parse(last.value) < 60 * 60_000) return { added: 0, skipped: "recent" };
  }
  await env.DB.prepare("INSERT OR REPLACE INTO _meta (key, value) VALUES ('news_fetched_at_v2', ?)").bind(new Date().toISOString()).run();

  const seenRow = await env.DB.prepare("SELECT value FROM _meta WHERE key = 'news_seen'").first<{ value: string }>();
  const seen: string[] = seenRow ? JSON.parse(seenRow.value) : [];
  const seenSet = new Set(seen);
  const titles = new Set<string>();
  const fresh: { id: string; fields: Record<string, string> }[] = [];

  for (const feed of FEEDS) {
    let xml = "";
    try {
      const r = await fetch(feed, { headers: { "User-Agent": "Mozilla/5.0 (compatible; " + UA + ")", Accept: "application/rss+xml, application/xml" } });
      xml = await r.text();
      console.log("news feed", r.status, xml.length, (xml.match(/<item>/g) ?? []).length, feed.slice(37, 90));
      if (!r.ok) continue;
    } catch (e) {
      console.error("news feed fail", feed.slice(37, 90), String(e));
      continue;
    }
    for (const m of xml.matchAll(/<item>([\s\S]*?)<\/item>/g)) {
      const body = m[1];
      const pick = (tag: string) => decode((body.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`)) ?? [])[1] ?? "");
      const link = pick("link");
      let title = pick("title");
      const source = pick("source");
      const pub = Date.parse(pick("pubDate"));
      if (!link || !title || Number.isNaN(pub)) continue;
      if (source && title.endsWith(` - ${source}`)) title = title.slice(0, -(source.length + 3)).trim();
      if (!RELEVANT.test(title) || NOISE.test(title)) continue;
      if (Date.now() - pub > 30 * 86_400_000) continue; // فقط خبرهای ۳۰ روز اخیر
      const key = title.replace(/\s+/g, " ").toLowerCase();
      if (titles.has(key)) continue;
      titles.add(key);
      const id = `news-${await sha(link)}`;
      if (seenSet.has(id)) continue;
      fresh.push({ id, fields: { title, source, url: link, published: new Date(pub).toISOString(), snippet: "", auto: "1" } });
    }
  }

  fresh.sort((a, b) => b.fields.published.localeCompare(a.fields.published));
  const batch = fresh.slice(0, 25);
  const now = new Date().toISOString();
  const stmts = batch.map((n) =>
    env.DB.prepare("INSERT OR IGNORE INTO content_items (id, section_id, fields, sort_order, created_at, updated_at) VALUES (?, 'news', ?, 0, ?, ?)").bind(
      n.id, JSON.stringify(n.fields), now, now,
    ),
  );
  // خبرهای خودکار قدیمی‌تر از ۹۰ روز پاک می‌شوند؛ خبرهای دستی مدیر می‌مانند
  stmts.push(
    env.DB.prepare("DELETE FROM content_items WHERE section_id = 'news' AND id LIKE 'news-%' AND json_extract(fields, '$.published') < ?").bind(
      new Date(Date.now() - 90 * 86_400_000).toISOString(),
    ),
  );
  const nextSeen = [...batch.map((b) => b.id), ...seen].slice(0, 800);
  stmts.push(env.DB.prepare("INSERT OR REPLACE INTO _meta (key, value) VALUES ('news_seen', ?)").bind(JSON.stringify(nextSeen)));
  await env.DB.batch(stmts);
  console.log("news added", batch.length, "candidates", fresh.length);
  return { added: batch.length };
}
