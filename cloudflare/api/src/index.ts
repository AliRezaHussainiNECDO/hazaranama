// =====================================================================
// API هزاره‌نامه روی Cloudflare Workers — جایگزین کامل Supabase:
//   /auth/*        ثبت‌نام، ورود، تغییر رمز، بازیابی رمز با کد مدیر، حذف حساب
//   /db            پرس‌وجوی جدول‌ها با قوانین دسترسی (جای RLS)
//   /rpc/*         شمارنده‌ی بازدید روزانه و بازدید ویدیو
//   /storage/*     آپلود فایل در R2      /media/*  نمایش عمومی فایل‌ها
//   /functions/*   دستیار هوشمند (Workers AI) و حذف حساب
//   /admin/*       کد بازیابی رمز، ورود داده‌ها از Supabase، انتقال فایل‌ها، محتوای اولیه
// =====================================================================
import type { Env, Ctx } from "./types";
import { hashPassword, verifyPassword, signJwt, verifyJwt, sha256Hex } from "./auth";
import { runQuery, HttpError, type User, type QueryReq, encodeValue, columnsOf } from "./db";
import { insertNotifications, adminIds } from "./hooks";
import { pushConfigured } from "./push";
import { emailConfigured, sendEmail, recoveryEmail, welcomeEmail, passwordChangedEmail } from "./email";
import { handleAi } from "./ai";
import { oauthProviders, oauthStart, oauthCallback, oauthExchange, verifyAppleIdentity, type Profile } from "./oauth";
import schemaSql from "../schema.sql";
import seedContent from "../seed/content.json";
import { fetchNews, mirrorCommons, prewarmMirror, enrichNews, enrichNewsItem } from "./content_extra";
import legacySeedKeys from "../seed/legacy_seed_keys.json";
import { allXp, trackEvent, invalidateXp, XP_RULES } from "./xp";

const SCHEMA_VERSION = 6;

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, x-migration-key, x-upsert",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

function json(body: unknown, status = 200, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json; charset=utf-8", ...extra } });
}
const err = (status: number, message: string, code = "error") => json({ error: { message, code } }, status);

// ---------------- اسکیمای پایگاه‌داده (یک‌بار در هر نسخه) ----------------
let schemaReady: Promise<void> | null = null;

async function ensureSchema(env: Env) {
  await env.DB.prepare("CREATE TABLE IF NOT EXISTS _meta (key TEXT PRIMARY KEY, value TEXT)").run();
  const row = await env.DB.prepare("SELECT value FROM _meta WHERE key = 'schema_version'").first<{ value: string }>();
  if (row && Number(row.value) >= SCHEMA_VERSION) return;
  const statements = (schemaSql as string)
    .split(/;\s*(?:\n|$)/)
    .map((s) => s.replace(/^\s*--.*$/gm, "").trim())
    .filter((s) => s && !/^PRAGMA/i.test(s));
  for (const s of statements) {
    try {
      await env.DB.prepare(s).run();
    } catch (e) {
      // ALTER TABLE … ADD COLUMN روی پایگاهی که ستون را دارد — بی‌خطر
      if (!/duplicate column/i.test(String(e))) throw e;
    }
  }
  await env.DB.prepare("INSERT OR REPLACE INTO _meta (key, value) VALUES ('schema_version', ?)").bind(String(SCHEMA_VERSION)).run();
}

/** اگر نسخه‌ی محتوای اولیه‌ی بسته‌بندی‌شده تغییر کرده باشد، آن را بازنویسی کن. */
async function ensureContent(env: Env) {
  const v = (seedContent as { version?: string }).version ?? "";
  const row = await env.DB.prepare("SELECT value FROM _meta WHERE key = 'content_version'").first<{ value: string }>();
  if (row?.value === v) return;
  await seed(env, []);
}

// ---------------- کاربر جاری ----------------
async function currentUser(env: Env, req: Request): Promise<User | null> {
  const h = req.headers.get("authorization") ?? "";
  const m = h.match(/^Bearer\s+(.+)$/i);
  if (!m) return null;
  const claims = await verifyJwt(m[1], env.JWT_SECRET);
  if (!claims) throw new HttpError(401, "نشست شما منقضی شده؛ دوباره وارد شوید.", "session_expired");
  const row = await env.DB.prepare(
    "SELECT u.id, u.email, u.token_version, p.role, p.status FROM users u JOIN profiles p ON p.id = u.id WHERE u.id = ?",
  )
    .bind(claims.sub)
    .first<{ id: string; email: string; token_version: number; role: User["role"]; status: User["status"] }>();
  if (!row || row.token_version !== claims.tv) throw new HttpError(401, "نشست شما منقضی شده؛ دوباره وارد شوید.", "session_expired");
  return { id: row.id, email: row.email, role: row.role, status: row.status };
}

async function session(env: Env, user: { id: string; email: string; token_version: number }) {
  const { token, exp } = await signJwt({ sub: user.id, email: user.email, tv: user.token_version }, env.JWT_SECRET);
  return { user: { id: user.id, email: user.email }, session: { access_token: token, expires_at: exp } };
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

async function readJson(req: Request): Promise<Record<string, unknown>> {
  try {
    return (await req.json()) as Record<string, unknown>;
  } catch {
    throw new HttpError(400, "بدنه‌ی درخواست نامعتبر است.");
  }
}

// ---------------- /auth ----------------
async function handleAuth(env: Env, ctx: Ctx, req: Request, path: string): Promise<Response> {
  if (path === "/auth/signup") {
    const b = await readJson(req);
    const email = String(b.email ?? "").trim().toLowerCase();
    const password = String(b.password ?? "");
    const name = String(b.name ?? "").trim() || email.split("@")[0];
    if (!EMAIL_RE.test(email)) return err(400, "invalid email", "invalid_email");
    if (password.length < 6) return err(400, "Password should be at least 6 characters", "weak_password");
    const exists = await env.DB.prepare("SELECT 1 FROM users WHERE email = ?").bind(email).first();
    if (exists) return err(409, "User already registered", "user_already_exists");
    const id = crypto.randomUUID();
    const role = email === (env.ADMIN_EMAIL ?? "").toLowerCase() ? "admin" : "user";
    await env.DB.batch([
      env.DB.prepare("INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)").bind(id, email, await hashPassword(password)),
      env.DB.prepare("INSERT INTO profiles (id, name, email, role, status) VALUES (?, ?, ?, ?, 'active')").bind(id, name, email, role),
    ]);
    if (emailConfigured(env)) ctx.waitUntil(sendEmail(env, { to: email, ...welcomeEmail(name) }).then(() => undefined));
    const admins = (await adminIds(env)).filter((a) => a !== id);
    if (admins.length) {
      await insertNotifications(env, ctx, admins.map((a) => ({ user_id: a, type: "admin_new_user", title: `کاربر تازه پیوست: ${name}`, body: email, ref_id: id, ref_type: "user" })));
    }
    return json(await session(env, { id, email, token_version: 0 }));
  }

  // افزودن ایمیل واقعی برای حساب‌هایی که با شماره/اپل/ایکس و بدون ایمیل ساخته شده‌اند (برای بازیابی رمز)
  if (path === "/auth/set-email") {
    const user = await currentUser(env, req);
    if (!user) return err(401, "ابتدا وارد شوید.");
    const b = await readJson(req);
    const email = String(b.email ?? "").trim().toLowerCase();
    if (!EMAIL_RE.test(email)) return err(400, "ایمیل معتبر نیست.", "invalid_email");
    const u = await env.DB.prepare("SELECT id, email, token_version FROM users WHERE id = ?").bind(user.id).first<{ id: string; email: string; token_version: number }>();
    if (!u) return err(400, "حساب پیدا نشد.");
    if (!u.email.endsWith("@users.hazaranama.com")) return err(400, "ایمیل این حساب از قبل ثبت شده است.", "email_locked");
    const taken = await env.DB.prepare("SELECT 1 FROM users WHERE email = ? AND id != ?").bind(email, u.id).first();
    if (taken) return err(409, "این ایمیل به حساب دیگری تعلق دارد.", "email_exists");
    await env.DB.batch([
      env.DB.prepare("UPDATE users SET email = ? WHERE id = ?").bind(email, u.id),
      env.DB.prepare("UPDATE profiles SET email = ? WHERE id = ?").bind(email, u.id),
    ]);
    return json(await session(env, { ...u, email }));
  }

  // ورود بومی با اپل (iOS): identityToken با کلیدهای عمومی اپل بررسی می‌شود
  if (path === "/auth/apple/native") {
    const b = await readJson(req);
    const a = await verifyAppleIdentity(env, String(b.identity_token ?? ""));
    if (!a) return err(400, "تأیید اپل ناموفق بود.", "invalid_credentials");
    const userId = await ensureOAuthUser(env, ctx, "apple", { id: a.sub, name: String(b.name ?? ""), email: a.email, avatar: null });
    const u = await env.DB.prepare("SELECT id, email, token_version FROM users WHERE id = ?").bind(userId).first<{ id: string; email: string; token_version: number }>();
    if (!u) return err(400, "حساب پیدا نشد.");
    return json(await session(env, u));
  }

  if (path === "/auth/oauth/exchange") {
    const b = await readJson(req);
    const userId = await oauthExchange(env, String(b.code ?? ""));
    if (!userId) return err(400, "ورود منقضی شد؛ دوباره تلاش کنید.", "oauth_expired");
    const u = await env.DB.prepare("SELECT id, email, token_version FROM users WHERE id = ?").bind(userId).first<{ id: string; email: string; token_version: number }>();
    if (!u) return err(400, "حساب پیدا نشد.", "oauth_expired");
    return json(await session(env, u));
  }

  if (path === "/auth/login") {
    const b = await readJson(req);
    const email = String(b.email ?? "").trim().toLowerCase();
    const password = String(b.password ?? "");
    const u = await env.DB.prepare("SELECT id, email, password_hash, token_version FROM users WHERE email = ?")
      .bind(email)
      .first<{ id: string; email: string; password_hash: string; token_version: number }>();
    if (!u) return err(400, "Invalid login credentials", "invalid_credentials");
    const v = await verifyPassword(password, u.password_hash);
    if (!v.ok) return err(400, "Invalid login credentials", "invalid_credentials");
    if (v.rehash) {
      ctx.waitUntil(hashPassword(password).then((h) => env.DB.prepare("UPDATE users SET password_hash = ? WHERE id = ?").bind(h, u.id).run()));
    }
    return json(await session(env, u));
  }

  if (path === "/auth/update") {
    const user = await currentUser(env, req);
    if (!user) return err(401, "Auth session missing", "session_missing");
    const b = await readJson(req);
    const password = String(b.password ?? "");
    if (password.length < 6) return err(400, "Password should be at least 6 characters", "weak_password");
    const cur = await env.DB.prepare("SELECT password_hash, token_version FROM users WHERE id = ?").bind(user.id).first<{ password_hash: string; token_version: number }>();
    if (cur && (await verifyPassword(password, cur.password_hash)).ok) {
      return err(422, "New password should be different from the old password.", "same_password");
    }
    const tv = (cur?.token_version ?? 0) + 1;
    await env.DB.prepare("UPDATE users SET password_hash = ?, token_version = ?, recovery_code_hash = NULL, recovery_expires = NULL WHERE id = ?")
      .bind(await hashPassword(password), tv, user.id)
      .run();
    if (emailConfigured(env)) {
      const p = await env.DB.prepare("SELECT name FROM profiles WHERE id = ?").bind(user.id).first<{ name: string }>();
      ctx.waitUntil(sendEmail(env, { to: user.email, ...passwordChangedEmail(p?.name ?? "") }).then(() => undefined));
    }
    return json(await session(env, { id: user.id, email: user.email, token_version: tv }));
  }

  // درخواست بازیابی رمز: اگر ایمیل (Resend) تنظیم شده، کد ۸ رقمی به ایمیل کاربر می‌رود؛
  // وگرنه مدیر باخبر می‌شود و از پنل برای کاربر کد می‌سازد. پاسخ برای ایمیلِ موجود و
  // ناموجود یکسان است تا معلوم نشود چه کسی حساب دارد.
  if (path === "/auth/recover") {
    const b = await readJson(req);
    const email = String(b.email ?? "").trim().toLowerCase();
    const via = emailConfigured(env) ? "email" : "admin";
    const u = await env.DB.prepare("SELECT u.id, u.recovery_requested_at, p.name FROM users u JOIN profiles p ON p.id = u.id WHERE u.email = ?")
      .bind(email)
      .first<{ id: string; recovery_requested_at: string | null; name: string }>();
    if (u) {
      const last = u.recovery_requested_at ? Date.parse(u.recovery_requested_at) : 0;
      if (via === "email") {
        // هر دقیقه حداکثر یک ایمیل
        if (Date.now() - last > 60_000) {
          const n = crypto.getRandomValues(new Uint32Array(1))[0] % 100_000_000;
          const code = String(n).padStart(8, "0");
          const minutes = 30;
          const now = new Date();
          await env.DB.batch([
            env.DB.prepare("UPDATE users SET recovery_code_hash = ?, recovery_expires = ?, recovery_requested_at = ? WHERE id = ?").bind(
              await sha256Hex(`${u.id}:${code}`),
              new Date(now.getTime() + minutes * 60_000).toISOString(),
              now.toISOString(),
              u.id,
            ),
            env.DB.prepare("DELETE FROM recovery_attempts WHERE user_id = ?").bind(u.id),
          ]);
          ctx.waitUntil(sendEmail(env, { to: email, ...recoveryEmail(u.name, code, minutes) }).then(() => undefined));
        }
      } else if (Date.now() - last > 10 * 60_000) {
        await env.DB.prepare("UPDATE users SET recovery_requested_at = ? WHERE id = ?").bind(new Date().toISOString(), u.id).run();
        const admins = await env.DB.prepare("SELECT id FROM profiles WHERE role = 'admin'").all<{ id: string }>();
        await insertNotifications(
          env,
          ctx,
          (admins.results ?? []).map((a) => ({
            user_id: a.id,
            type: "password_recovery_request",
            title: `${u.name} درخواست بازیابی رمز عبور داد`,
            body: `${email} — از صفحه‌ی کاربر، «ساخت کد بازیابی» را بزنید و کد را برایش بفرستید.`,
            ref_id: u.id,
            ref_type: "user",
          })),
        );
      }
    }
    return json({ ok: true, via }); // عمداً نمی‌گوییم ایمیل وجود دارد یا نه
  }

  if (path === "/auth/verify-recovery") {
    const b = await readJson(req);
    const email = String(b.email ?? "").trim().toLowerCase();
    const token = String(b.token ?? "").trim();
    const u = await env.DB.prepare("SELECT id, email, token_version, recovery_code_hash, recovery_expires FROM users WHERE email = ?")
      .bind(email)
      .first<{ id: string; email: string; token_version: number; recovery_code_hash: string | null; recovery_expires: string | null }>();
    if (!u || !u.recovery_code_hash || !u.recovery_expires || Date.parse(u.recovery_expires) < Date.now()) {
      return err(400, "Token has expired or is invalid", "otp_expired");
    }
    if ((await sha256Hex(`${u.id}:${token}`)) !== u.recovery_code_hash) {
      // پس از ۵ تلاش نادرست، کد باطل می‌شود و باید کد تازه گرفت
      const a = await env.DB.prepare(
        "INSERT INTO recovery_attempts (user_id, n, updated_at) VALUES (?, 1, ?) ON CONFLICT(user_id) DO UPDATE SET n = n + 1, updated_at = excluded.updated_at RETURNING n",
      )
        .bind(u.id, new Date().toISOString())
        .first<{ n: number }>();
      if ((a?.n ?? 0) >= 5) {
        await env.DB.batch([
          env.DB.prepare("UPDATE users SET recovery_code_hash = NULL, recovery_expires = NULL WHERE id = ?").bind(u.id),
          env.DB.prepare("DELETE FROM recovery_attempts WHERE user_id = ?").bind(u.id),
        ]);
        return err(400, "Token has expired or is invalid", "otp_expired");
      }
      return err(400, "Token has expired or is invalid", "otp_invalid");
    }
    await env.DB.batch([
      env.DB.prepare("UPDATE users SET recovery_code_hash = NULL, recovery_expires = NULL, recovery_requested_at = NULL WHERE id = ?").bind(u.id),
      env.DB.prepare("DELETE FROM recovery_attempts WHERE user_id = ?").bind(u.id),
    ]);
    return json(await session(env, u));
  }

  if (path === "/auth/delete-account") {
    const user = await currentUser(env, req);
    if (!user) return err(401, "ابتدا وارد شوید.");
    for (const prefix of [`avatars/${user.id}/`, `post-media/${user.id}/`]) {
      let cursor: string | undefined;
      do {
        const list = await env.MEDIA.list({ prefix, cursor });
        if (list.objects.length) await env.MEDIA.delete(list.objects.map((o) => o.key));
        cursor = list.truncated ? list.cursor : undefined;
      } while (cursor);
    }
    await env.DB.prepare("DELETE FROM users WHERE id = ?").bind(user.id).run();
    return json({ ok: true });
  }

  return err(404, "مسیر پیدا نشد.");
}

// ---------------- /storage و /media ----------------
const BUCKETS = new Set(["avatars", "content-media", "post-media", "artist-media", "donation-media"]);
const OWNER_BUCKETS = new Set(["avatars", "post-media"]); // هر کاربر فقط در پوشه‌ی خودش

async function handleUpload(env: Env, req: Request, bucket: string, key: string): Promise<Response> {
  const user = await currentUser(env, req);
  if (!user) return err(401, "ابتدا وارد شوید.");
  if (!BUCKETS.has(bucket) || !key || key.includes("..")) return err(400, "مسیر نامعتبر.");
  const isAdmin = user.role === "admin";
  if (OWNER_BUCKETS.has(bucket)) {
    if (key.split("/")[0] !== user.id && !isAdmin) return err(403, "اجازه‌ی آپلود در این مسیر را ندارید.");
    if (user.status !== "active") return err(403, "حساب شما مسدود است.");
  } else if (!isAdmin) {
    return err(403, "فقط مدیر می‌تواند این فایل را آپلود کند.");
  }
  const type = req.headers.get("content-type") ?? "application/octet-stream";
  if (!req.body) return err(400, "فایل خالی است.");
  await env.MEDIA.put(`${bucket}/${key}`, req.body, { httpMetadata: { contentType: type, cacheControl: "public, max-age=31536000" } });
  return json({ Key: `${bucket}/${key}` });
}

async function serveMedia(env: Env, req: Request, key: string): Promise<Response> {
  const range = req.headers.get("range");
  let r2Range: R2Range | undefined;
  if (range) {
    const m = range.match(/bytes=(\d*)-(\d*)/);
    if (m) {
      if (m[1] === "" && m[2] !== "") r2Range = { suffix: Number(m[2]) };
      else if (m[2] === "") r2Range = { offset: Number(m[1]) };
      else r2Range = { offset: Number(m[1]), length: Number(m[2]) - Number(m[1]) + 1 };
    }
  }
  let obj = await env.MEDIA.get(key, r2Range ? { range: r2Range } : undefined);
  if (!obj && key.startsWith("commons/") && (await mirrorCommons(env, key))) {
    obj = await env.MEDIA.get(key, r2Range ? { range: r2Range } : undefined);
  }
  if (!obj) return new Response("پیدا نشد", { status: 404, headers: CORS });
  const headers = new Headers(CORS);
  obj.writeHttpMetadata(headers);
  headers.set("etag", obj.httpEtag);
  headers.set("accept-ranges", "bytes");
  if (!headers.get("cache-control")) headers.set("cache-control", "public, max-age=31536000");
  if (r2Range && "range" in obj && obj.range) {
    const rr = obj.range as { offset?: number; length?: number; suffix?: number };
    const offset = rr.offset ?? (rr.suffix != null ? obj.size - rr.suffix : 0);
    const length = rr.length ?? obj.size - offset;
    headers.set("content-range", `bytes ${offset}-${offset + length - 1}/${obj.size}`);
    headers.set("content-length", String(length));
    return new Response(obj.body, { status: 206, headers });
  }
  headers.set("content-length", String(obj.size));
  return new Response(obj.body, { headers });
}

// ---------------- /admin ----------------
async function requireAdminOrKey(env: Env, req: Request): Promise<void> {
  const key = req.headers.get("x-migration-key");
  if (key && env.MIGRATION_KEY && key === env.MIGRATION_KEY) return;
  const u = await currentUser(env, req);
  if (!u || u.role !== "admin") throw new HttpError(403, "فقط مدیر.");
}

const IMPORT_ORDER = [
  "auth_users", "profiles", "content_items", "posts", "comments", "reactions", "comment_likes", "contact_messages",
  "artists", "artist_videos", "video_comments", "video_reactions", "article_submissions", "featured_articles",
  "article_comments", "article_reactions", "contest_settings", "donation_transfers", "donation_reports",
  "donation_settings", "notifications", "device_tokens", "daily_visits", "content_reports", "blocked_users",
];

function pgTime(v: unknown): unknown {
  // زمان‌های پستگرس (2026-08-02 10:00:00.123+00) → ISO با Z
  if (typeof v === "string" && /^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}/.test(v)) {
    const d = new Date(v.replace(" ", "T").replace(/\+00(:00)?$/, "Z"));
    if (!isNaN(d.getTime())) return d.toISOString();
  }
  return v;
}

async function importRows(env: Env, table: string, rows: Record<string, unknown>[]): Promise<number> {
  if (table === "auth_users") {
    const stmts = rows
      .filter((r) => r.email && r.encrypted_password)
      .map((r) =>
        env.DB.prepare("INSERT OR REPLACE INTO users (id, email, password_hash, token_version, created_at) VALUES (?, ?, ?, 0, ?)").bind(
          r.id, String(r.email).toLowerCase(), r.encrypted_password, pgTime(r.created_at) ?? new Date().toISOString(),
        ),
      );
    for (let i = 0; i < stmts.length; i += 50) await env.DB.batch(stmts.slice(i, i + 50));
    return stmts.length;
  }
  if (!IMPORT_ORDER.includes(table)) throw new HttpError(400, `جدول نامعتبر برای ورود: ${table}`);
  if (table === "content_items") {
    // محتوای اولیه‌ی قدیمی (همان SQL-seed های Supabase) تکرار نشود؛ نسخه‌ی گسترش‌یافته‌اش در seed هست
    const legacy = new Set(legacySeedKeys as string[]);
    rows = rows.filter((r) => {
      let f = r.fields as Record<string, unknown> | string | undefined;
      if (typeof f === "string") {
        try { f = JSON.parse(f) as Record<string, unknown>; } catch { f = {}; }
      }
      const ff = (f ?? {}) as Record<string, unknown>;
      const k = ["title", "name", "era", "hazaragi", "caption"].map((x) => ff[x]).find((v) => typeof v === "string" && v.trim());
      return !(k && legacy.has(`${r.section_id}|${String(k).trim()}`));
    });
  }
  const cols = await columnsOf(env, table);
  const stmts: D1PreparedStatement[] = [];
  for (const raw of rows) {
    const keys = Object.keys(raw).filter((k) => cols.has(k));
    if (!keys.length) continue;
    const vals = keys.map((k) => {
      const v = /(_at|^day)$/.test(k) ? pgTime(raw[k]) : raw[k];
      return encodeValue(table, k, v);
    });
    stmts.push(env.DB.prepare(`INSERT OR REPLACE INTO "${table}" (${keys.map((k) => `"${k}"`).join(",")}) VALUES (${keys.map(() => "?").join(",")})`).bind(...vals));
  }
  for (let i = 0; i < stmts.length; i += 50) await env.DB.batch(stmts.slice(i, i + 50));
  return stmts.length;
}

// ستون‌هایی که ممکن است نشانی فایل‌های Supabase Storage را داشته باشند
const URL_COLUMNS: Array<[string, string, boolean]> = [
  ["profiles", "avatar_url", false], ["content_items", "image_url", false], ["content_items", "video_url", false],
  ["posts", "image_urls", true], ["posts", "video_url", false], ["posts", "video_thumbnail_url", false],
  ["artists", "avatar_url", false], ["artists", "cover_url", false], ["artist_videos", "video_url", false],
  ["artist_videos", "thumbnail_url", false], ["donation_reports", "image_urls", true], ["donation_reports", "video_url", false],
  ["featured_articles", "author_avatar", false], ["blocked_users", "blocked_avatar_url", false],
];
const SUPA_RE = /^https:\/\/[a-z0-9]+\.supabase\.co\/storage\/v1\/object\/public\/([^/]+)\/([^?]+)(\?.*)?$/;

async function migrateMedia(env: Env, origin: string, budget: number) {
  const mapping = new Map<string, string>();
  let copied = 0, failed = 0, remaining = 0;
  for (const [table, col, isJson] of URL_COLUMNS) {
    const res = await env.DB.prepare(`SELECT id, "${col}" AS v FROM "${table}" WHERE "${col}" LIKE '%supabase.co/storage/%'`).all<{ id: string; v: string }>();
    for (const row of res.results ?? []) {
      const urls: string[] = isJson ? JSON.parse(row.v || "[]") : [row.v];
      const out: string[] = [];
      let changed = false;
      for (const url of urls) {
        const m = typeof url === "string" ? url.match(SUPA_RE) : null;
        if (!m) {
          out.push(url);
          continue;
        }
        const key = `${m[1]}/${decodeURIComponent(m[2])}`;
        let newUrl = mapping.get(url);
        if (!newUrl) {
          if (budget <= 0) {
            remaining++;
            out.push(url);
            continue;
          }
          budget--;
          try {
            const r = await fetch(url.split("?")[0]);
            if (!r.ok) throw new Error(String(r.status));
            const buf = await r.arrayBuffer();
            await env.MEDIA.put(key, buf, { httpMetadata: { contentType: r.headers.get("content-type") ?? undefined, cacheControl: "public, max-age=31536000" } });
            copied++;
          } catch {
            failed++;
            out.push(url);
            continue;
          }
          newUrl = `${origin}/media/${key}${m[3] ?? ""}`;
          mapping.set(url, newUrl);
        }
        out.push(newUrl);
        changed = true;
      }
      if (changed) {
        await env.DB.prepare(`UPDATE "${table}" SET "${col}" = ? WHERE id = ?`).bind(isJson ? JSON.stringify(out) : out[0], row.id).run();
      }
    }
  }
  return { copied, failed, remaining };
}

interface SeedItem {
  id: string;
  section_id: string;
  sort_order: number;
  image_url?: string;
  fields: Record<string, unknown>;
}

async function seed(env: Env, replaceSections: string[]) {
  const content = seedContent as { version?: string; items: SeedItem[] };
  const items = content.items ?? [];
  const stmts: D1PreparedStatement[] = [];
  // محتوای اولیه (seed-*) بازنویسی می‌شود، مگر آیتمی که مدیر ویرایشش کرده (updated_at ≠ created_at)؛
  // آنچه مدیر خودش افزوده هم دست‌نخورده می‌ماند
  stmts.push(env.DB.prepare("DELETE FROM content_items WHERE id LIKE 'seed-%' AND updated_at = created_at"));
  for (const sec of replaceSections) {
    stmts.push(env.DB.prepare("DELETE FROM content_items WHERE section_id = ? AND id NOT LIKE 'seed-%'").bind(sec));
  }
  const now = new Date().toISOString();
  for (const it of items) {
    stmts.push(
      env.DB.prepare("INSERT OR IGNORE INTO content_items (id, section_id, fields, image_url, sort_order, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)").bind(
        it.id, it.section_id, JSON.stringify(it.fields), it.image_url ?? null, it.sort_order, now, now,
      ),
    );
  }
  // هنرمندان و ویدیوهای اولیه (لینک کانال‌های رسمی یوتیوب) — فقط اگر نباشند افزوده می‌شوند
  const music = ((seedContent as unknown as { music?: { artist: Record<string, string>; videos: Record<string, string>[] }[] }).music ?? []);
  music.forEach((m, ai) => {
    const a = m.artist;
    if (a.match_name) {
      // هنرمندی که از قبل (با ویدیوهایش) در پایگاه هست: فقط اطلاعاتش کامل می‌شود
      stmts.push(
        env.DB.prepare("UPDATE artists SET name = ?, bio = CASE WHEN COALESCE(bio,'') = '' THEN ? ELSE bio END, category = ?, avatar_url = COALESCE(?, avatar_url), image_credit = ?, image_page = ?, sort_order = ? WHERE name = ? OR id = ?")
          .bind(a.name, a.bio ?? "", a.category ?? null, a.avatar_url ?? null, a.image_credit ?? null, a.image_page ?? null, ai, a.match_name, a.id),
      );
    }
    stmts.push(env.DB.prepare("INSERT OR IGNORE INTO artists (id, name, bio, avatar_url, cover_url, sort_order, category, image_credit, image_page) SELECT ?, ?, ?, ?, ?, ?, ?, ?, ? WHERE NOT EXISTS (SELECT 1 FROM artists WHERE name = ? OR name = ?)")
      .bind(a.id, a.name, a.bio ?? "", a.avatar_url ?? null, a.cover_url ?? null, ai, a.category ?? null, a.image_credit ?? null, a.image_page ?? null, a.name, a.match_name ?? a.name));
    // بازنشانی گروه/ترتیب ردیف‌های seed (اگر مدیر عکس گذاشته باشد، عکس او می‌ماند)
    stmts.push(env.DB.prepare("UPDATE artists SET category = ?, sort_order = ?, image_credit = COALESCE(image_credit, ?), image_page = COALESCE(image_page, ?), avatar_url = COALESCE(avatar_url, ?) WHERE id = ?")
      .bind(a.category ?? null, ai, a.image_credit ?? null, a.image_page ?? null, a.avatar_url ?? null, a.id));
    m.videos.forEach((v, vi) => {
      stmts.push(env.DB.prepare("INSERT OR IGNORE INTO artist_videos (id, artist_id, title, description, video_url, thumbnail_url, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?)").bind(v.id, a.id, v.title, v.description ?? "", v.video_url, v.thumbnail_url ?? null, vi));
    });
  });
  stmts.push(env.DB.prepare("INSERT OR REPLACE INTO _meta (key, value) VALUES ('content_version', ?)").bind(content.version ?? ""));
  await env.DB.batch(stmts); // یک تراکنش: یا همه یا هیچ
  return { seeded: items.length, version: content.version };
}

// اثر SHA-256 (روی JSON مرتب‌شده) بسته‌ی نهایی داده‌های Supabase: یک کاربر، پروفایل، هنرمند، تنظیمات، بازدیدها و توکن دستگاه
const GLOSSARY_SHA = "e01f0a81f65e6b36a77a59ec990d7c8275fc23358aad01df700da6fa43f653ef";
const LEGACY_IMPORT_SHA = "6de9bef007ed30060e82e19be1491197f346db70acd472bc1b9cd440d9aa91f8";

function canonicalJson(v: unknown): string {
  if (Array.isArray(v)) return `[${v.map(canonicalJson).join(",")}]`;
  if (v && typeof v === "object") {
    const o = v as Record<string, unknown>;
    return `{${Object.keys(o).sort().map((k) => `${JSON.stringify(k)}:${canonicalJson(o[k])}`).join(",")}}`;
  }
  return JSON.stringify(v);
}

async function handleAdmin(env: Env, ctx: Ctx, req: Request, path: string, url: URL): Promise<Response> {
  if (path === "/admin/recovery-code") {
    const u = await currentUser(env, req);
    if (!u || u.role !== "admin") return err(403, "فقط مدیر.");
    const b = await readJson(req);
    const target = String(b.user_id ?? "");
    const exists = await env.DB.prepare("SELECT id FROM users WHERE id = ?").bind(target).first();
    if (!exists) return err(404, "کاربر پیدا نشد.");
    const n = crypto.getRandomValues(new Uint32Array(1))[0] % 100_000_000;
    const code = String(n).padStart(8, "0");
    const expires = new Date(Date.now() + 24 * 3600_000).toISOString();
    await env.DB.prepare("UPDATE users SET recovery_code_hash = ?, recovery_expires = ? WHERE id = ?").bind(await sha256Hex(`${target}:${code}`), expires, target).run();
    return json({ code, expires_at: expires });
  }

  if (path === "/admin/legacy-import" && req.method === "POST") {
    // ورود یک‌باره‌ی باقی‌مانده‌ی داده‌های Supabase (ارسال‌شده با pg_net از خود Supabase).
    // بدون کلید: فقط همان بسته‌ای پذیرفته می‌شود که اثر SHA-256 آن از پیش در کد ثبت شده است.
    const done = await env.DB.prepare("SELECT value FROM _meta WHERE key = 'legacy_import'").first();
    if (done) return err(409, "این داده‌ها قبلاً وارد شده‌اند.");
    const body = await readJson(req);
    if ((await sha256Hex(canonicalJson(body))) !== LEGACY_IMPORT_SHA) return err(403, "بسته‌ی داده با نسخه‌ی تأییدشده یکی نیست.");
    const tables = (body.tables ?? {}) as Record<string, Record<string, unknown>[]>;
    const result: Record<string, number> = {};
    for (const t of IMPORT_ORDER) if (tables[t]) result[t] = await importRows(env, t, tables[t]);
    await env.DB.prepare("INSERT OR REPLACE INTO _meta (key, value) VALUES ('legacy_import', ?)").bind(new Date().toISOString()).run();
    ctx.waitUntil(migrateMedia(env, PUBLIC_ORIGIN, 20));
    return json({ ok: true, imported: result });
  }

  if (path === "/admin/upload-glossary" && req.method === "POST") {
    // بارگذاری یک‌باره‌ی واژه‌نامه‌ی هزارگی (با اجازه‌ی سایت مشعل) — فقط همان فایلی
    // پذیرفته می‌شود که اثر SHA-256 آن از پیش در کد ثبت شده است.
    const text = await req.text();
    if ((await sha256Hex(text)) !== GLOSSARY_SHA) return err(403, "فایل با نسخه‌ی تأییدشده یکی نیست.");
    await env.MEDIA.put("imports/mashal-glossary.json", text, { httpMetadata: { contentType: "application/json; charset=utf-8" } });
    return json({ ok: true, bytes: text.length });
  }

  if (path === "/admin/fetch-news") {
    const u = await currentUser(env, req);
    if (!u || u.role !== "admin") return err(403, "فقط مدیر.");
    return json(await fetchNews(env, true));
  }

  if (path === "/admin/push-status" || path === "/admin/broadcast") {
    // فقط با نشست مدیر (نه کلید انتقال)
    const u = await currentUser(env, req);
    if (!u || u.role !== "admin") return err(403, "فقط مدیر.");

    if (path === "/admin/push-status") {
      const d = await env.DB.prepare("SELECT COUNT(*) AS devices, COUNT(DISTINCT user_id) AS users, SUM(platform = 'android') AS android, SUM(platform = 'ios') AS ios FROM device_tokens").first<Record<string, number>>();
      const p = await env.DB.prepare("SELECT COUNT(*) AS c FROM profiles WHERE status = 'active'").first<{ c: number }>();
      const last = await env.DB.prepare("SELECT title, body, created_at FROM notifications WHERE type = 'announcement' ORDER BY created_at DESC LIMIT 1").first();
      return json({
        configured: pushConfigured(env),
        email_configured: emailConfigured(env),
        email_from: env.EMAIL_FROM ?? null,
        devices: d?.devices ?? 0,
        users_with_devices: d?.users ?? 0,
        android: d?.android ?? 0,
        ios: d?.ios ?? 0,
        active_users: p?.c ?? 0,
        last_announcement: last ?? null,
      });
    }

    // /admin/broadcast — اعلان همگانی (درون‌اپ برای همه + پوش برای گوشی‌ها)
    const b = await readJson(req);
    const title = String(b.title ?? "").trim().slice(0, 120);
    const body = String(b.body ?? "").trim().slice(0, 500);
    if (!title) return err(400, "عنوان اعلان خالی است.");
    const audience = b.audience === "admins" ? "admins" : "all";
    const recipients =
      audience === "admins"
        ? await adminIds(env)
        : ((await env.DB.prepare("SELECT id FROM profiles WHERE status = 'active'").all<{ id: string }>()).results ?? []).map((r) => r.id);
    const list = recipients.map((id) => ({ user_id: id, type: "announcement", title, body, ref_id: null, ref_type: null }));
    await insertNotifications(env, ctx, list, { broadcast: audience === "all" });
    return json({ ok: true, recipients: list.length, push: pushConfigured(env) });
  }

  await requireAdminOrKey(env, req);

  if (path === "/admin/import") {
    const b = await readJson(req);
    // پذیرش {table, rows} یا {tables: {name: rows}}
    const tables: Record<string, Record<string, unknown>[]> = (b.tables as Record<string, Record<string, unknown>[]>) ?? { [String(b.table)]: (b.rows as Record<string, unknown>[]) ?? [] };
    const result: Record<string, number> = {};
    for (const t of IMPORT_ORDER) {
      if (tables[t]) result[t] = await importRows(env, t, tables[t] ?? []);
    }
    return json({ ok: true, imported: result });
  }

  if (path === "/admin/stage") {
    // فقط ذخیره‌ی خام (بدون پردازش سنگین) — کار اصلی را cron هر دقیقه انجام می‌دهد
    const table = url.searchParams.get("table") ?? "";
    if (!IMPORT_ORDER.includes(table)) return err(400, `جدول نامعتبر: ${table}`);
    const body = await req.text();
    await env.DB.prepare("INSERT INTO _import_staging (tbl, data) VALUES (?, ?)").bind(table, body).run();
    return json({ ok: true, staged: table, bytes: body.length });
  }

  if (path === "/admin/import-status") {
    const r = await env.DB.prepare("SELECT tbl, applied, result, length(data) AS bytes FROM _import_staging ORDER BY id").all();
    return json(r.results ?? []);
  }

  if (path === "/admin/migrate-media") {
    const budget = Math.min(40, Number(url.searchParams.get("limit") ?? 25));
    return json(await migrateMedia(env, url.origin, budget));
  }

  if (path === "/admin/seed-content") {
    const b = req.method === "POST" ? await readJson(req).catch(() => ({})) : {};
    const replace = Array.isArray((b as Record<string, unknown>).replace_sections) ? ((b as Record<string, unknown>).replace_sections as string[]) : [];
    return json(await seed(env, replace));
  }

  // جایزه یا کسر امتیاز از سوی مدیر — با اعلان برای کاربر
  if (path === "/admin/xp-bonus" && req.method === "POST") {
    const u = await currentUser(env, req);
    if (!u || u.role !== "admin") return err(403, "فقط مدیر.");
    const b = await readJson(req);
    const target = String(b.user_id ?? "");
    const delta = Math.trunc(Number(b.delta) || 0);
    if (!target || !delta || Math.abs(delta) > 100000) return err(400, "کاربر و مقدار امتیاز معتبر لازم است.");
    const reason = String(b.reason ?? "").trim().slice(0, 200);
    const r = await env.DB.prepare("UPDATE profiles SET xp_bonus = COALESCE(xp_bonus, 0) + ? WHERE id = ?").bind(delta, target).run();
    if (!(r.meta?.changes ?? 0)) return err(404, "کاربر پیدا نشد.");
    invalidateXp();
    if (delta > 0) {
      await insertNotifications(env, ctx, [{ user_id: target, type: "xp_bonus", title: `🎁 ${delta} امتیاز جایزه گرفتید!`, body: reason || "از سوی مدیریت هزاره‌نامه، برای فعالیت ارزشمندتان.", ref_id: target, ref_type: "user" }]);
    }
    return json({ ok: true });
  }

  if (path === "/admin/stats") {
    const out: Record<string, number> = {};
    for (const t of IMPORT_ORDER.filter((t) => t !== "auth_users").concat(["users"])) {
      const r = await env.DB.prepare(`SELECT COUNT(*) AS c FROM "${t}"`).first<{ c: number }>();
      out[t] = r?.c ?? 0;
    }
    return json(out);
  }

  return err(404, "مسیر پیدا نشد.");
}

// ---------------- پردازش زمان‌بندی‌شده (هر دقیقه) ----------------
/** یک تکه از داده‌های staged را — به ترتیب وابستگی جدول‌ها — وارد می‌کند. */
async function applyStaged(env: Env): Promise<boolean> {
  const pending = await env.DB.prepare("SELECT id, tbl FROM _import_staging WHERE applied = 0").all<{ id: number; tbl: string }>();
  const list = pending.results ?? [];
  if (!list.length) return false;
  list.sort((a, b) => IMPORT_ORDER.indexOf(a.tbl) - IMPORT_ORDER.indexOf(b.tbl) || a.id - b.id);
  const next = list[0];
  const row = await env.DB.prepare("SELECT data FROM _import_staging WHERE id = ?").bind(next.id).first<{ data: string }>();
  let result: string;
  try {
    const parsed = JSON.parse(row?.data ?? "[]");
    const rows = Array.isArray(parsed) ? parsed : [];
    const n = await importRows(env, next.tbl, rows);
    result = `ok:${n}`;
  } catch (e) {
    result = `error:${e instanceof Error ? e.message : String(e)}`.slice(0, 500);
  }
  await env.DB.prepare("UPDATE _import_staging SET applied = 1, result = ?, data = '' WHERE id = ?").bind(result, next.id).run();
  return true;
}

const PUBLIC_ORIGIN = "https://hazaranama-api.alireza-necdo.workers.dev";

async function scheduled(env: Env) {
  if (!schemaReady) schemaReady = ensureSchema(env).then(() => ensureContent(env));
  await schemaReady;
  // تا ۳ تکه در هر اجرا؛ وقتی چیزی برای ورود نماند، نوبت انتقال فایل‌هاست
  let worked = false;
  for (let i = 0; i < 3; i++) {
    if (!(await applyStaged(env))) break;
    worked = true;
  }
  if (!worked) await migrateMedia(env, PUBLIC_ORIGIN, 20);
  await prewarmMirror(env, 6).catch((e) => console.error("prewarm", e));
  await fetchNews(env).catch((e) => console.error("news", e));
  await enrichNews(env, 6).catch((e) => console.error("news enrich", e));
}

// ---------------- ورودی اصلی ----------------
export default {
  async scheduled(_event: ScheduledController, env: Env, ctx: Ctx) {
    ctx.waitUntil(scheduled(env));
  },

  async fetch(req: Request, env: Env, ctx: Ctx): Promise<Response> {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
    const url = new URL(req.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";
    try {
      if (path.startsWith("/media/") && (req.method === "GET" || req.method === "HEAD")) {
        return await serveMedia(env, req, decodeURIComponent(path.slice("/media/".length)));
      }
      if (path === "/") return json({ ok: true, service: "hazaranama-api" });
      // عکس خبرها از سایت ناشر — با سرآیند CORS تا نسخه‌ی وب هم بتواند نشانش دهد.
      // فقط عکس‌هایی که واقعاً به یک خبر ذخیره‌شده تعلق دارند (پروکسی باز نیست).
      if (path === "/img-proxy" && req.method === "GET") return await imageProxy(env, ctx, req, url);

      schemaReady ??= ensureSchema(env).then(() => ensureContent(env)).catch((e) => {
        schemaReady = null;
        throw e;
      });
      await schemaReady;

      if (path === "/auth/oauth/providers" && req.method === "GET") return json(oauthProviders(env));
      {
        const m = path.match(/^\/auth\/oauth\/(facebook|x|apple)\/(start|callback)$/);
        if (m && (req.method === "GET" || (req.method === "POST" && m[2] === "callback"))) {
          const provider = m[1] as "facebook" | "x" | "apple";
          if (m[2] === "start") return await oauthStart(env, provider, url);
          // اپل نتیجه را با form_post (POST) می‌فرستد
          const params = req.method === "POST" ? new URLSearchParams(await req.text()) : url.searchParams;
          return await oauthCallback(env, provider, params, (pv, p) => ensureOAuthUser(env, ctx, pv, p));
        }
      }
      if (path.startsWith("/auth/") && req.method === "POST") return await handleAuth(env, ctx, req, path);

      if (path === "/db" && req.method === "POST") {
        const user = await currentUser(env, req);
        const q = (await readJson(req)) as unknown as QueryReq;
        const data = await runQuery(env, ctx, user, q);
        return json({ data });
      }

      if (path.startsWith("/storage/") && (req.method === "PUT" || req.method === "POST")) {
        const rest = path.slice("/storage/".length);
        const slash = rest.indexOf("/");
        return await handleUpload(env, req, rest.slice(0, slash), decodeURIComponent(rest.slice(slash + 1)));
      }

      if (path === "/rpc/increment_daily_visit") {
        const user = await currentUser(env, req);
        if (!user) return err(401, "ابتدا وارد شوید.");
        const day = new Date().toISOString().slice(0, 10);
        await env.DB.prepare("INSERT INTO daily_visits (day, count) VALUES (?, 1) ON CONFLICT(day) DO UPDATE SET count = count + 1").bind(day).run();
        await trackEvent(env, user.id, "visit", day);
        return json({ data: null });
      }
      // امتیاز فعالیت: ثبت خواندن/تماشا/دانلود/خبر و جدول مقام‌ها
      if (path === "/rpc/track" && req.method === "POST") {
        const user = await currentUser(env, req);
        if (!user) return err(401, "ابتدا وارد شوید.");
        const b = await readJson(req);
        return json({ data: await trackEvent(env, user.id, b.kind, b.ref) });
      }
      // نشانی دانلود مستقیم کتاب: فایل آپلودشده‌ی مدیر، یا PDF آزاد یک اثر در Internet Archive
      if (path === "/books/download" && req.method === "GET") {
        const id = url.searchParams.get("id") ?? "";
        const row = await env.DB.prepare("SELECT fields FROM content_items WHERE id = ? AND section_id = 'library'").bind(id).first<{ fields: string }>();
        if (!row) return err(404, "کتاب پیدا نشد.");
        const f = JSON.parse(row.fields || "{}") as Record<string, string>;
        if ((f.file_url ?? "").startsWith("http")) return json({ data: { url: f.file_url, name: f.file_name || `${id}.pdf`, size: Number(f.file_size) || null } });
        const aid = (f.archive_id ?? "").trim();
        if (!aid || f.downloadable !== "1") return err(404, "این کتاب نسخه‌ی قابل دانلود ندارد.");
        const meta = await fetch(`https://archive.org/metadata/${encodeURIComponent(aid)}`, { headers: { "User-Agent": "HazaranamaBot/1.0 (https://hazaranama.com)" } });
        if (!meta.ok) return err(502, "منبع کتاب در دسترس نیست؛ کمی بعد دوباره امتحان کنید.");
        const m = (await meta.json()) as { files?: { name: string; size?: string; format?: string; private?: string }[]; metadata?: { "access-restricted-item"?: string } };
        if (String(m.metadata?.["access-restricted-item"]) === "true") return err(404, "این کتاب فقط امانتی است و دانلود آزاد ندارد.");
        const pdfs = (m.files ?? []).filter((x) => /\.pdf$/i.test(x.name) && x.private !== "true");
        pdfs.sort((a, b) => Number(a.size ?? 0) - Number(b.size ?? 0)); // کوچک‌ترین PDF — مناسب موبایل
        const pick = pdfs[0];
        if (!pick) return err(404, "فایل PDF این کتاب پیدا نشد.");
        return json({ data: { url: `https://archive.org/download/${encodeURIComponent(aid)}/${pick.name.split("/").map(encodeURIComponent).join("/")}`, name: pick.name.split("/").pop(), size: Number(pick.size) || null } });
      }
      if (path === "/news/item" && req.method === "GET") {
        const it = await enrichNewsItem(env, url.searchParams.get("id") ?? "");
        return it ? json({ data: it }) : err(404, "خبر پیدا نشد.");
      }
      if (path === "/xp/leaderboard" && req.method === "GET") {
        const user = await currentUser(env, req);
        if (!user) return err(401, "ابتدا وارد شوید.");
        const limit = Math.min(500, Math.max(1, Number(url.searchParams.get("limit") ?? 200) || 200));
        const list = await allXp(env);
        return json({ data: list.slice(0, limit).map((e, i) => ({ ...e, position: i + 1 })), rules: XP_RULES, total_users: list.length });
      }
      if (path === "/xp/me" && req.method === "GET") {
        const user = await currentUser(env, req);
        if (!user) return err(401, "ابتدا وارد شوید.");
        const id = url.searchParams.get("user_id") || user.id;
        const list = await allXp(env);
        const i = list.findIndex((e) => e.user_id === id);
        return json({ data: i < 0 ? null : { ...list[i], position: i + 1 }, rules: XP_RULES, total_users: list.length });
      }
      if (path === "/rpc/increment_video_views") {
        const b = await readJson(req);
        await env.DB.prepare("UPDATE artist_videos SET views_count = views_count + 1 WHERE id = ?").bind(String(b.p_video_id ?? "")).run();
        return json({ data: null });
      }

      if (path === "/functions/ai-gateway" && req.method === "POST") {
        const user = await currentUser(env, req);
        if (!user) return err(401, "ابتدا وارد شوید.");
        return await handleAi(env, await readJson(req)).then((r) => {
          const h = new Headers(r.headers);
          Object.entries(CORS).forEach(([k, v]) => h.set(k, v));
          return new Response(r.body, { status: r.status, headers: h });
        });
      }
      if (path === "/functions/delete-account" && req.method === "POST") return await handleAuth(env, ctx, req, "/auth/delete-account");

      if (path.startsWith("/admin/")) return await handleAdmin(env, ctx, req, path, url);

      return err(404, "مسیر پیدا نشد.");
    } catch (e) {
      if (e instanceof HttpError) return err(e.status, e.message, e.code);
      console.error(e);
      return err(500, e instanceof Error ? e.message : "خطای داخلی سرور.");
    }
  },
};


/** حساب کاربر ورودی از شبکه‌ی اجتماعی: پیوند موجود ← حساب با همان ایمیل ← حساب تازه */
async function ensureOAuthUser(env: Env, ctx: Ctx, provider: "facebook" | "x" | "apple" | "phone", p: Profile): Promise<string> {
  const linked = await env.DB.prepare("SELECT user_id FROM oauth_accounts WHERE provider = ? AND provider_user_id = ?").bind(provider, p.id).first<{ user_id: string }>();
  if (linked) return linked.user_id;
  const email = (p.email ?? "").trim().toLowerCase();
  if (email) {
    const existing = await env.DB.prepare("SELECT id FROM users WHERE email = ?").bind(email).first<{ id: string }>();
    if (existing) {
      await env.DB.prepare("INSERT OR IGNORE INTO oauth_accounts (provider, provider_user_id, user_id) VALUES (?, ?, ?)").bind(provider, p.id, existing.id).run();
      return existing.id;
    }
  }
  const id = crypto.randomUUID();
  // بدون ایمیل (ایکس): نشانی داخلی و یکتا — کاربر بعداً می‌تواند ایمیل واقعی‌اش را در پروفایل بگذارد
  const userEmail = email || `${provider}-${p.id.replace(/[^0-9A-Za-z.]/g, "")}@users.hazaranama.com`;
  const name = p.name.trim() || "کاربر هزاره‌نامه";
  const role = email && email === (env.ADMIN_EMAIL ?? "").toLowerCase() ? "admin" : "user";
  const unusable = `oauth$${crypto.randomUUID()}`; // با هیچ رمزی تطبیق نمی‌کند
  await env.DB.batch([
    env.DB.prepare("INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)").bind(id, userEmail, unusable),
    env.DB.prepare("INSERT INTO profiles (id, name, email, role, status, avatar_url) VALUES (?, ?, ?, ?, 'active', ?)").bind(id, name, userEmail, role, p.avatar),
    env.DB.prepare("INSERT INTO oauth_accounts (provider, provider_user_id, user_id) VALUES (?, ?, ?)").bind(provider, p.id, id),
  ]);
  if (email && emailConfigured(env)) ctx.waitUntil(sendEmail(env, { to: email, ...welcomeEmail(name) }).then(() => undefined));
  const admins = (await adminIds(env)).filter((a) => a !== id);
  if (admins.length) {
    const via = { facebook: "فیسبوک", x: "ایکس", apple: "اپل", phone: "شماره‌ی تلفن" }[provider];
    await insertNotifications(env, ctx, admins.map((a) => ({ user_id: a, type: "admin_new_user", title: `کاربر تازه پیوست: ${name}`, body: `از راه ${via}`, ref_id: id, ref_type: "user" })));
  }
  return id;
}


async function imageProxy(env: Env, ctx: Ctx, req: Request, url: URL): Promise<Response> {
  const target = url.searchParams.get("u") ?? "";
  if (!/^https?:\/\//.test(target)) return new Response("bad", { status: 400, headers: CORS });
  const cache = caches.default;
  const hit = await cache.match(req);
  if (hit) return hit;
  const known = await env.DB.prepare("SELECT 1 AS ok FROM content_items WHERE image_url = ? LIMIT 1").bind(target).first<{ ok: number }>();
  if (!known) return new Response("forbidden", { status: 403, headers: CORS });
  const r = await fetch(target, { headers: { "User-Agent": "Mozilla/5.0 (compatible; HazaranamaBot/1.0; +https://hazaranama.com)", Accept: "image/*" }, redirect: "follow" });
  const type = r.headers.get("content-type") ?? "";
  if (!r.ok || !type.startsWith("image/")) return new Response("not an image", { status: 502, headers: CORS });
  const h = new Headers(CORS);
  h.set("content-type", type);
  h.set("cache-control", "public, max-age=604800");
  const res = new Response(r.body, { status: 200, headers: h });
  ctx.waitUntil(cache.put(req, res.clone()));
  return res;
}
