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
// عنوان، نام رسانه، تاریخ و لینک؛ سپس عکس و خلاصه‌ی اشتراک‌گذاری ناشر (نه متن کامل خبر).
const FEEDS: { name: string; url: string; kind: "rss" | "gdelt" }[] = [
  { name: "KabulNow", url: "https://kabulnow.com/feed/", kind: "rss" },
  { name: "Amu TV", url: "https://amu.tv/feed/", kind: "rss" },
  { name: "Hasht-e Subh", url: "https://8am.media/eng/feed/", kind: "rss" },
  { name: "هشت صبح", url: "https://8am.media/feed/", kind: "rss" },
  { name: "Rukhshana Media", url: "https://rukhshana.com/en/feed/", kind: "rss" },
  { name: "اطلاعات روز", url: "https://www.etilaatroz.com/feed/", kind: "rss" },
  {
    name: "",
    url: "https://api.gdeltproject.org/api/v2/doc/doc?query=hazara%20(afghanistan%20OR%20taliban%20OR%20quetta%20OR%20kabul)&mode=artlist&format=json&maxrecords=60&timespan=14d&sort=datedesc",
    kind: "gdelt",
  },
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
    const last = await env.DB.prepare("SELECT value FROM _meta WHERE key = 'news_fetched_at_v4'").first<{ value: string }>();
    if (last && Date.now() - Date.parse(last.value) < 60 * 60_000) return { added: 0, skipped: "recent" };
  }
  await env.DB.prepare("INSERT OR REPLACE INTO _meta (key, value) VALUES ('news_fetched_at_v4', ?)").bind(new Date().toISOString()).run();

  const seenRow = await env.DB.prepare("SELECT value FROM _meta WHERE key = 'news_seen'").first<{ value: string }>();
  const seen: string[] = seenRow ? JSON.parse(seenRow.value) : [];
  const seenSet = new Set(seen);
  const titles = new Set<string>();
  const fresh: { id: string; fields: Record<string, string> }[] = [];

  for (const feed of FEEDS) {
    let xml = "";
    try {
      const r = await fetch(feed.url, { headers: { "User-Agent": "Mozilla/5.0 (compatible; " + UA + ")", Accept: "application/rss+xml, application/xml" } });
      xml = await r.text();
      console.log("news feed", feed.name || "gdelt", r.status, xml.length);
      if (!r.ok) continue;
    } catch (e) {
      console.error("news feed fail", feed.name || "gdelt", String(e));
      continue;
    }
    type Raw = { title: string; link: string; source: string; pub: number; extra?: string };
    const raws: Raw[] = [];
    if (feed.kind === "gdelt") {
      try {
        const j = JSON.parse(xml) as { articles?: { url: string; title: string; seendate: string; domain: string }[] };
        for (const a of j.articles ?? []) {
          const d = a.seendate.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/);
          raws.push({ title: a.title, link: a.url, source: a.domain.replace(/^www\./, ""), pub: d ? Date.UTC(+d[1], +d[2] - 1, +d[3], +d[4], +d[5], +d[6]) : NaN });
        }
      } catch {
        continue;
      }
    } else {
      for (const m of xml.matchAll(/<item>([\s\S]*?)<\/item>/g)) {
        const body = m[1];
        const pick = (tag: string) => decode((body.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`)) ?? [])[1] ?? "");
        const cats = [...body.matchAll(/<category[^>]*>([\s\S]*?)<\/category>/g)].map((c) => decode(c[1])).join(" ");
        raws.push({ title: pick("title"), link: pick("link"), source: feed.name, pub: Date.parse(pick("pubDate")), extra: `${pick("description").slice(0, 600)} ${cats}` });
      }
    }
    for (const r of raws) {
      const { link, source, pub } = r;
      const title = r.title.replace(/\s+/g, " ").trim();
      if (!link.startsWith("http") || !title || Number.isNaN(pub)) continue;
      if (!RELEVANT.test(`${title} ${r.extra ?? ""}`) || NOISE.test(title)) continue;
      if (Date.now() - pub > 30 * 86_400_000) continue; // فقط خبرهای ۳۰ روز اخیر
      const key = title.toLowerCase();
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

// ---------------- غنی‌سازی خبرها: عکس و خلاصه‌ی ناشر + برگردان فارسی ----------------
// از صفحه‌ی خبر فقط برچسب‌های اشتراک‌گذاری (og:image و og:description) خوانده می‌شود —
// همان عکس و خلاصه‌ای که خودِ ناشر برای نمایش در شبکه‌ها می‌گذارد؛ متن کامل خبر
// کپی نمی‌شود و کاربر آن را داخل اپ، در صفحه‌ی خودِ منبع می‌خواند.
function metaTag(html: string, names: string[]): string {
  for (const n of names) {
    const re1 = new RegExp(`<meta[^>]+(?:property|name)=["']${n}["'][^>]*content=["']([^"']+)["']`, "i");
    const re2 = new RegExp(`<meta[^>]+content=["']([^"']+)["'][^>]*(?:property|name)=["']${n}["']`, "i");
    const m = html.match(re1) ?? html.match(re2);
    if (m?.[1]) return decode(m[1]).replace(/&#(\d+);/g, (_, d) => String.fromCharCode(Number(d)));
  }
  return "";
}

const PERSIAN = /[؀-ۿ]/;

async function toPersian(env: Env, title: string, summary: string): Promise<{ title: string; summary: string } | null> {
  if (!env.AI) return null;
  try {
    const prompt = `Translate this news headline and summary into fluent Persian (Dari, as used in Afghanistan). Keep names accurate. Return ONLY JSON: {"title":"...","summary":"..."}\n\nHeadline: ${title}\nSummary: ${summary || "(none)"}`;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const out: any = await env.AI.run("@cf/google/gemma-3-12b-it" as any, { messages: [{ role: "user", content: prompt }], max_tokens: 700, temperature: 0.2 });
    // مدل گاهی JSON را مستقیم به‌صورت شیء برمی‌گرداند، گاهی به‌صورت متن
    let j: { title?: string; summary?: string };
    if (out?.response && typeof out.response === "object") {
      j = out.response as { title?: string; summary?: string };
    } else {
      const m = String(out?.response ?? "").match(/\{[\s\S]*\}/);
      if (!m) return null;
      j = JSON.parse(m[0]) as { title?: string; summary?: string };
    }
    if (!j.title || !PERSIAN.test(j.title)) return null;
    return { title: j.title.trim().slice(0, 300), summary: (j.summary ?? "").trim().slice(0, 1500) };
  } catch (e) {
    console.error("news fa", String(e));
    return null;
  }
}

type NewsRow = { id: string; fields: string; image_url: string | null };

async function enrichOne(env: Env, row: NewsRow): Promise<Record<string, unknown>> {
  const f = JSON.parse(row.fields || "{}") as Record<string, unknown>;
  let image = row.image_url ?? "";
  const url = String(f.url ?? "");
  if (url.startsWith("http")) {
    try {
      const ctl = new AbortController();
      const t = setTimeout(() => ctl.abort(), 7000);
      const r = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0 (compatible; " + UA + ")", Accept: "text/html" }, signal: ctl.signal, redirect: "follow" });
      clearTimeout(t);
      if (r.ok && (r.headers.get("content-type") ?? "").includes("html")) {
        const html = (await r.text()).slice(0, 400_000);
        const img = metaTag(html, ["og:image", "og:image:url", "twitter:image", "twitter:image:src"]);
        if (!image && img.startsWith("http")) image = img;
        const desc = metaTag(html, ["og:description", "twitter:description", "description"]);
        if (desc && !f.snippet) f.snippet = desc.replace(/\s+/g, " ").trim().slice(0, 1200);
      }
    } catch (e) {
      console.error("news enrich", url, String(e));
    }
  }
  await translateFields(env, f);
  f.enriched = "1";
  await env.DB.prepare("UPDATE content_items SET fields = ?, image_url = ?, updated_at = ? WHERE id = ?")
    .bind(JSON.stringify(f), image || null, new Date().toISOString(), row.id).run();
  return { id: row.id, fields: f, image_url: image || null };
}

async function translateFields(env: Env, f: Record<string, unknown>) {
  const title = String(f.title ?? "");
  if (PERSIAN.test(title) || f.title_fa || f.fa_tried) return;
  const fa = await toPersian(env, title, String(f.snippet ?? ""));
  f.fa_tried = "1";
  if (fa) {
    f.title_fa = fa.title;
    if (fa.summary) f.snippet_fa = fa.summary;
  }
}

/** در هر اجرای cron چند خبر تازه را غنی می‌کند و خبرهای غیرفارسی جامانده را برمی‌گرداند */
export async function enrichNews(env: Env, budget = 6) {
  const rows = await env.DB.prepare(
    "SELECT id, fields, image_url FROM content_items WHERE section_id = 'news' AND json_extract(fields, '$.enriched') IS NULL ORDER BY json_extract(fields, '$.published') DESC LIMIT ?",
  ).bind(budget).all<NewsRow>();
  for (const r of rows.results ?? []) await enrichOne(env, r);
  // خبرهای غنی‌شده‌ای که برگردان فارسی ندارند (مثلاً پیش از رفع خطای برگردان)
  const pending = await env.DB.prepare(
    "SELECT id, fields FROM content_items WHERE section_id = 'news' AND json_extract(fields, '$.enriched') IS NOT NULL AND json_extract(fields, '$.title_fa') IS NULL AND json_extract(fields, '$.fa_tried') IS NULL LIMIT 3",
  ).all<{ id: string; fields: string }>();
  for (const r of pending.results ?? []) {
    const f = JSON.parse(r.fields || "{}") as Record<string, unknown>;
    await translateFields(env, f);
    await env.DB.prepare("UPDATE content_items SET fields = ? WHERE id = ?").bind(JSON.stringify(f), r.id).run();
  }
}

/** غنی‌سازی فوری یک خبر وقتی کاربر آن را باز می‌کند و هنوز آماده نیست */
export async function enrichNewsItem(env: Env, id: string): Promise<Record<string, unknown> | null> {
  const row = await env.DB.prepare("SELECT id, fields, image_url FROM content_items WHERE id = ? AND section_id = 'news'").bind(id).first<NewsRow>();
  if (!row) return null;
  const f = JSON.parse(row.fields || "{}") as Record<string, unknown>;
  if (f.enriched) return { id: row.id, fields: f, image_url: row.image_url };
  return enrichOne(env, row);
}
