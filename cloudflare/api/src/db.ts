// موتور پرس‌وجوی سبک — زیرمجموعه‌ای از همان چیزی که اپ قبلاً با PostgREST/Supabase
// انجام می‌داد (select با embed، eq/lt/gte/…، order، limit، insert/update/delete/upsert)
// به‌علاوه‌ی «قوانین دسترسی» هر جدول که جای RLS پستگرس را می‌گیرد.
import type { Env, Ctx } from "./types";
import { moderationError } from "./moderation";
import { runAfterHooks, loadRowsForHooks } from "./hooks";

export class HttpError extends Error {
  constructor(public status: number, message: string, public code = "error") {
    super(message);
  }
}

export interface User {
  id: string;
  email: string;
  role: "admin" | "editor" | "user";
  status: "active" | "blocked";
  /** حساب‌هایی که با ایمیل ثبت‌نام کرده‌اند تا تأیید ایمیل نمی‌توانند بنویسند */
  email_verified?: boolean;
}

type Cond = { sql: string; params: unknown[] } | null; // null = بدون محدودیت
type Deny = false;

interface Policy {
  select?: (u: User | null) => Cond | Deny;
  /** قبل از درج: ردیف را بررسی/تکمیل می‌کند؛ رشته = پیام خطا */
  insert?: (u: User | null, row: Record<string, unknown>, env: Env) => Promise<true | string> | true | string;
  update?: (u: User | null) => Cond | Deny;
  /** ستون‌هایی که این کاربر حق تغییرشان را ندارد حذف می‌شوند */
  guardUpdate?: (u: User | null, values: Record<string, unknown>) => Record<string, unknown>;
  delete?: (u: User | null) => Cond | Deny;
  json?: string[];
  bool?: string[];
  pk?: string[];
}

const isAdmin = (u: User | null) => !!u && u.role === "admin";
const active = (u: User | null) => !!u && u.status === "active";
const all = () => null;
const admin = (u: User | null): Cond | Deny => (isAdmin(u) ? null : false);
const own = (col: string) => (u: User | null): Cond | Deny => (u ? { sql: `"${col}" = ?`, params: [u.id] } : false);
const ownOrAdmin = (col: string) => (u: User | null): Cond | Deny =>
  isAdmin(u) ? null : u ? { sql: `"${col}" = ?`, params: [u.id] } : false;

function insertOwnActive(col: string) {
  return (u: User | null, row: Record<string, unknown>) => {
    if (!u) return "ابتدا وارد شوید.";
    if (!active(u)) return "حساب شما مسدود است.";
    if (u.email_verified === false && !isAdmin(u)) throw new HttpError(403, "برای نوشتن و مشارکت، اول ایمیل‌تان را تأیید کنید.", "email_unverified");
    if (row[col] == null) row[col] = u.id;
    if (row[col] !== u.id) return "اجازه‌ی این کار را ندارید.";
    return moderationError(row.text, row.title, row.body) ?? true;
  };
}
const insertAdmin = (u: User | null) => (isAdmin(u) ? true : "فقط مدیر می‌تواند این کار را انجام دهد.");

const POLICIES: Record<string, Policy> = {
  profiles: {
    select: all,
    update: ownOrAdmin("id"),
    guardUpdate: (u, v) => {
      delete v.id;
      delete v.email;
      delete v.created_at;
      if (!isAdmin(u)) {
        delete v.role;
        delete v.status;
        delete v.xp_bonus;
        const bad = moderationError(v.name, v.bio);
        if (bad) throw new HttpError(400, bad);
      }
      return v;
    },
    delete: admin,
  },
  content_items: { select: all, insert: insertAdmin, update: admin, delete: admin, json: ["fields"] },
  posts: { select: all, insert: insertOwnActive("author_id"), delete: ownOrAdmin("author_id"), json: ["image_urls"] },
  comments: { select: all, insert: insertOwnActive("author_id"), delete: ownOrAdmin("author_id") },
  reactions: { select: all, insert: insertOwnActive("user_id"), delete: own("user_id") },
  comment_likes: { select: all, insert: insertOwnActive("user_id"), delete: own("user_id") },
  contact_messages: { select: ownOrAdmin("user_id"), insert: insertOwnActive("user_id"), update: admin },
  artists: { select: all, insert: insertAdmin, update: admin, delete: admin },
  artist_videos: { select: all, insert: insertAdmin, update: admin, delete: admin },
  video_comments: { select: all, insert: insertOwnActive("author_id"), delete: ownOrAdmin("author_id") },
  video_reactions: { select: all, insert: insertOwnActive("user_id"), delete: own("user_id") },
  article_submissions: {
    select: ownOrAdmin("author_id"),
    insert: async (u, row, env) => {
      const r = insertOwnActive("author_id")(u, row);
      if (r !== true) return r;
      const cs = await env.DB.prepare("SELECT round_started_at FROM contest_settings WHERE id = 1").first<{ round_started_at: string | null }>();
      if (!cs?.round_started_at) return "دوره‌ی مسابقه هنوز آغاز نشده است.";
      const end = Date.parse(cs.round_started_at) + 28 * 86400_000;
      if (Date.now() >= end) return "مهلت ارسال مقاله برای این دوره تمام شده است.";
      return true;
    },
    update: admin,
    delete: (u) => (isAdmin(u) ? null : u ? { sql: `"author_id" = ? AND "status" = 'active'`, params: [u.id] } : false),
  },
  featured_articles: { select: all, insert: insertAdmin, update: admin, delete: admin },
  article_comments: { select: all, insert: insertOwnActive("author_id"), delete: ownOrAdmin("author_id") },
  article_reactions: { select: all, insert: insertOwnActive("user_id"), delete: own("user_id") },
  contest_settings: { select: all, insert: insertAdmin, update: admin },
  donation_transfers: { select: ownOrAdmin("user_id"), insert: insertOwnActive("user_id"), update: admin },
  donation_reports: { select: all, insert: insertAdmin, update: admin, delete: admin, json: ["image_urls"] },
  donation_settings: { select: all, insert: insertAdmin, update: admin },
  notifications: {
    select: own("user_id"),
    update: own("user_id"),
    guardUpdate: (_u, v) => ({ ...(v.is_read !== undefined ? { is_read: v.is_read } : {}) }),
    bool: ["is_read"],
  },
  device_tokens: {
    select: own("user_id"),
    insert: (u, row) => {
      if (!u) return "ابتدا وارد شوید.";
      row.user_id = u.id;
      return true;
    },
    // توکن یک دستگاه ممکن است قبلاً به کاربر دیگری وصل بوده باشد (دستگاه مشترک)
    update: (u) => (u ? null : false),
    guardUpdate: (u, v) => ({ ...v, user_id: u!.id }),
    delete: (u) => (u ? null : false), // حذف فقط با token مشخص؛ توکن خودش راز دستگاه است
  },
  daily_visits: { select: admin, pk: ["day"] },
  content_reports: { select: admin, insert: insertOwnActive("reporter_id"), update: admin },
  blocked_users: { select: own("blocker_id"), insert: insertOwnActive("blocker_id"), delete: own("blocker_id") },
  donor_leaderboard: { select: (u) => (u ? null : false) },
  user_activity_log: { select: admin },
};

// رابطه‌های قابل embed — همان‌هایی که اپ در select استفاده می‌کند.
const MANY_TO_ONE: Record<string, { table: string; fk: string }> = {
  "posts.author": { table: "profiles", fk: "author_id" },
  "comments.author": { table: "profiles", fk: "author_id" },
  "contact_messages.user": { table: "profiles", fk: "user_id" },
  "content_reports.reporter": { table: "profiles", fk: "reporter_id" },
  "video_comments.author": { table: "profiles", fk: "author_id" },
  "article_submissions.author": { table: "profiles", fk: "author_id" },
  "article_comments.author": { table: "profiles", fk: "author_id" },
};
const ONE_TO_MANY: Record<string, { table: string; fk: string }> = {
  "posts.reactions": { table: "reactions", fk: "post_id" },
  "comments.comment_likes": { table: "comment_likes", fk: "comment_id" },
};

const IDENT = /^[a-z_][a-z0-9_]*$/;
const columnsCache = new Map<string, Set<string>>();

async function columnsOf(env: Env, table: string): Promise<Set<string>> {
  let cols = columnsCache.get(table);
  if (cols) return cols;
  const res = await env.DB.prepare(`PRAGMA table_info("${table}")`).all<{ name: string }>();
  cols = new Set((res.results ?? []).map((r) => r.name));
  if (cols.size === 0) throw new HttpError(400, `جدول نامعتبر: ${table}`);
  columnsCache.set(table, cols);
  return cols;
}

function assertIdent(s: string) {
  if (!IDENT.test(s)) throw new HttpError(400, `نام نامعتبر: ${s}`);
}

// ---------------- پارس select ----------------
interface Embed {
  alias: string;
  table: string;
  cols: string[];
}
interface ParsedSelect {
  cols: string[] | "*";
  embeds: Embed[];
}

function splitTop(s: string): string[] {
  const out: string[] = [];
  let depth = 0,
    cur = "";
  for (const ch of s) {
    if (ch === "(") depth++;
    if (ch === ")") depth--;
    if (ch === "," && depth === 0) {
      out.push(cur.trim());
      cur = "";
    } else cur += ch;
  }
  if (cur.trim()) out.push(cur.trim());
  return out;
}

function parseSelect(sel: string | undefined | null): ParsedSelect {
  if (!sel || sel.trim() === "" || sel.trim() === "*") return { cols: "*", embeds: [] };
  const cols: string[] = [];
  const embeds: Embed[] = [];
  let star = false;
  for (const part of splitTop(sel)) {
    const m = part.match(/^(?:([a-z_][a-z0-9_]*):)?([a-z_][a-z0-9_]*)\((.*)\)$/s);
    if (m) {
      const table = m[2];
      const alias = m[1] ?? table;
      const inner = m[3].split(",").map((c) => c.trim()).filter(Boolean);
      inner.forEach(assertIdent);
      embeds.push({ alias, table, cols: inner });
    } else if (part === "*") {
      star = true;
    } else {
      assertIdent(part);
      cols.push(part);
    }
  }
  return { cols: star ? "*" : cols, embeds };
}

// ---------------- تبدیل خروجی ----------------
function decodeRow(table: string, row: Record<string, unknown>): Record<string, unknown> {
  const p = POLICIES[table];
  for (const c of p?.json ?? []) {
    if (typeof row[c] === "string") {
      try {
        row[c] = JSON.parse(row[c] as string);
      } catch {
        /* رها کن */
      }
    }
  }
  for (const c of p?.bool ?? []) if (c in row) row[c] = !!row[c];
  return row;
}

function encodeValue(table: string, col: string, v: unknown): unknown {
  const p = POLICIES[table];
  if (p?.json?.includes(col)) return v == null ? (col === "fields" ? "{}" : "[]") : JSON.stringify(v);
  if (p?.bool?.includes(col)) return v ? 1 : 0;
  if (typeof v === "boolean") return v ? 1 : 0;
  if (v !== null && typeof v === "object") return JSON.stringify(v);
  return v;
}

/** ایمیل دیگران فقط برای مدیر یا خودِ صاحب حساب دیده می‌شود. */
function scrubProfile(u: User | null, r: Record<string, unknown>) {
  if (!isAdmin(u) && (!u || r.id !== u.id) && "email" in r) r.email = "";
}

// ---------------- اجرای پرس‌وجو ----------------
export interface QueryReq {
  table: string;
  action: "select" | "insert" | "update" | "delete" | "upsert";
  select?: string | null;
  returning?: boolean;
  filters?: [string, string, unknown][];
  order?: [string, boolean][];
  limit?: number | null;
  values?: Record<string, unknown> | Record<string, unknown>[];
  onConflict?: string | null;
  single?: "single" | "maybe" | null;
}

const OPS: Record<string, string> = { eq: "=", neq: "<>", lt: "<", lte: "<=", gt: ">", gte: ">=" };

function buildWhere(table: string, filters: [string, string, unknown][], cols: Set<string>) {
  const parts: string[] = [];
  const params: unknown[] = [];
  for (const [col, op, val] of filters) {
    assertIdent(col);
    if (!cols.has(col)) throw new HttpError(400, `ستون نامعتبر: ${col}`);
    if (op === "is") {
      parts.push(`"${col}" IS ${val === null ? "NULL" : val ? "1" : "0"}`);
      continue;
    }
    if (op === "in") {
      const arr = Array.isArray(val) ? val : [];
      if (arr.length === 0) {
        parts.push("0");
        continue;
      }
      parts.push(`"${col}" IN (${arr.map(() => "?").join(",")})`);
      arr.forEach((x) => params.push(encodeValue(table, col, x)));
      continue;
    }
    const sqlOp = OPS[op];
    if (!sqlOp) throw new HttpError(400, `عملگر نامعتبر: ${op}`);
    parts.push(`"${col}" ${sqlOp} ?`);
    params.push(encodeValue(table, col, val));
  }
  return { parts, params };
}

function applyCond(parts: string[], params: unknown[], cond: Cond) {
  if (cond) {
    parts.push(`(${cond.sql})`);
    params.push(...cond.params);
  }
}

async function resolveEmbeds(env: Env, u: User | null, base: string, rows: Record<string, unknown>[], embeds: Embed[]) {
  for (const e of embeds) {
    const m2o = MANY_TO_ONE[`${base}.${e.alias}`];
    const o2m = ONE_TO_MANY[`${base}.${e.alias}`] ?? ONE_TO_MANY[`${base}.${e.table}`];
    if (m2o && m2o.table === e.table) {
      const ids = [...new Set(rows.map((r) => r[m2o.fk]).filter((x) => x != null))] as string[];
      const map = new Map<string, Record<string, unknown>>();
      const cols = await columnsOf(env, e.table);
      e.cols.forEach((c) => {
        if (!cols.has(c)) throw new HttpError(400, `ستون نامعتبر: ${c}`);
      });
      for (let i = 0; i < ids.length; i += 90) {
        const chunk = ids.slice(i, i + 90);
        const sel = [...new Set(["id", ...e.cols])].map((c) => `"${c}"`).join(",");
        const res = await env.DB.prepare(`SELECT ${sel} FROM "${e.table}" WHERE id IN (${chunk.map(() => "?").join(",")})`)
          .bind(...chunk)
          .all<Record<string, unknown>>();
        for (const r of res.results ?? []) {
          if (e.table === "profiles") scrubProfile(u, r);
          map.set(r.id as string, r);
        }
      }
      for (const r of rows) {
        const t = map.get(r[m2o.fk] as string);
        if (t) {
          const out: Record<string, unknown> = {};
          for (const c of e.cols) out[c] = t[c];
          r[e.alias] = out;
        } else r[e.alias] = null;
      }
    } else if (o2m && o2m.table === e.table) {
      const ids = rows.map((r) => r.id as string);
      const groups = new Map<string, Record<string, unknown>[]>();
      const cols = await columnsOf(env, e.table);
      e.cols.forEach((c) => {
        if (!cols.has(c)) throw new HttpError(400, `ستون نامعتبر: ${c}`);
      });
      for (let i = 0; i < ids.length; i += 90) {
        const chunk = ids.slice(i, i + 90);
        const sel = [...new Set([o2m.fk, ...e.cols])].map((c) => `"${c}"`).join(",");
        const res = await env.DB.prepare(`SELECT ${sel} FROM "${e.table}" WHERE "${o2m.fk}" IN (${chunk.map(() => "?").join(",")})`)
          .bind(...chunk)
          .all<Record<string, unknown>>();
        for (const r of res.results ?? []) {
          const k = r[o2m.fk] as string;
          const out: Record<string, unknown> = {};
          for (const c of e.cols) out[c] = r[c];
          if (!groups.has(k)) groups.set(k, []);
          groups.get(k)!.push(out);
        }
      }
      for (const r of rows) r[e.alias] = groups.get(r.id as string) ?? [];
    } else {
      throw new HttpError(400, `رابطه‌ی نامعتبر: ${base}.${e.alias}`);
    }
  }
}

function finish(q: QueryReq, rows: Record<string, unknown>[], parsed: ParsedSelect) {
  // ستون‌های کمکی که فقط برای embed لازم بودند ولی خواسته نشده‌اند، حذف شوند
  if (parsed.cols !== "*") {
    const keep = new Set([...parsed.cols, ...parsed.embeds.map((e) => e.alias)]);
    rows = rows.map((r) => Object.fromEntries(Object.entries(r).filter(([k]) => keep.has(k))));
  }
  if (q.single === "single") {
    if (rows.length !== 1) throw new HttpError(406, "انتظار دقیقاً یک ردیف می‌رفت.", "PGRST116");
    return rows[0];
  }
  if (q.single === "maybe") {
    if (rows.length > 1) throw new HttpError(406, "بیش از یک ردیف.", "PGRST116");
    return rows[0] ?? null;
  }
  return rows;
}

async function selectRows(env: Env, u: User | null, q: QueryReq, extraIds?: string[]) {
  const policy = POLICIES[q.table];
  if (!policy?.select) throw new HttpError(403, "دسترسی مجاز نیست.");
  const cond = policy.select(u);
  if (cond === false) throw new HttpError(403, "دسترسی مجاز نیست.");
  const cols = await columnsOf(env, q.table);
  const parsed = parseSelect(q.select);
  let selCols = "*";
  if (parsed.cols !== "*") {
    const need = new Set(parsed.cols);
    for (const e of parsed.embeds) {
      const m2o = MANY_TO_ONE[`${q.table}.${e.alias}`];
      if (m2o) need.add(m2o.fk);
      else need.add("id");
    }
    for (const c of need) if (!cols.has(c)) throw new HttpError(400, `ستون نامعتبر: ${c}`);
    selCols = [...need].map((c) => `"${c}"`).join(",");
  }
  const { parts, params } = buildWhere(q.table, q.filters ?? [], cols);
  applyCond(parts, params, cond);
  if (extraIds) {
    parts.push(`id IN (${extraIds.map(() => "?").join(",") || "NULL"})`);
    params.push(...extraIds);
  }
  let sql = `SELECT ${selCols} FROM "${q.table}"`;
  if (parts.length) sql += ` WHERE ${parts.join(" AND ")}`;
  if (q.order?.length) {
    sql +=
      " ORDER BY " +
      q.order
        .map(([c, asc]) => {
          assertIdent(c);
          if (!cols.has(c)) throw new HttpError(400, `ستون نامعتبر: ${c}`);
          return `"${c}" ${asc ? "ASC" : "DESC"}`;
        })
        .join(", ");
  }
  if (q.limit != null) sql += ` LIMIT ${Math.max(0, Math.min(1000, Math.floor(q.limit)))}`;
  const res = await env.DB.prepare(sql).bind(...params).all<Record<string, unknown>>();
  const rows = (res.results ?? []).map((r) => decodeRow(q.table, r));
  if (q.table === "profiles") rows.forEach((r) => scrubProfile(u, r));
  await resolveEmbeds(env, u, q.table, rows, parsed.embeds);
  return { rows, parsed };
}

function defaultsForInsert(table: string, row: Record<string, unknown>, cols: Set<string>) {
  if (cols.has("id") && row.id == null && !(POLICIES[table]?.pk)) {
    if (table !== "contest_settings" && table !== "donation_settings") row.id = crypto.randomUUID();
  }
}

export async function runQuery(env: Env, ctx: Ctx, u: User | null, q: QueryReq): Promise<unknown> {
  assertIdent(q.table);
  const policy = POLICIES[q.table];
  if (!policy) throw new HttpError(400, `جدول نامعتبر: ${q.table}`);

  if (q.table === "user_activity_log") {
    if (!isAdmin(u)) throw new HttpError(403, "دسترسی مجاز نیست.");
    return activityLog(env, q);
  }

  if (q.action === "select") {
    const { rows, parsed } = await selectRows(env, u, q);
    return finish(q, rows, parsed);
  }

  const cols = await columnsOf(env, q.table);

  if (q.action === "insert" || q.action === "upsert") {
    const list = Array.isArray(q.values) ? q.values : [q.values ?? {}];
    const isUpsert = q.action === "upsert";
    const conflict = (q.onConflict ?? (policy.pk ?? ["id"]).join(",")).split(",").map((s) => s.trim());
    conflict.forEach(assertIdent);
    const insertedIds: string[] = [];
    const insertedRows: Record<string, unknown>[] = [];
    for (const raw of list) {
      const row: Record<string, unknown> = { ...raw };
      for (const k of Object.keys(row)) {
        assertIdent(k);
        if (!cols.has(k)) throw new HttpError(400, `ستون نامعتبر: ${k}`);
      }
      // upsert روی ردیف موجود = به‌روزرسانی، با قوانین update
      let existing: Record<string, unknown> | null = null;
      if (isUpsert && conflict.every((c) => row[c] !== undefined)) {
        existing = await env.DB.prepare(`SELECT * FROM "${q.table}" WHERE ${conflict.map((c) => `"${c}" = ?`).join(" AND ")}`)
          .bind(...conflict.map((c) => encodeValue(q.table, c, row[c])))
          .first<Record<string, unknown>>();
      }
      if (existing && !policy.update) {
        // جدول بدون قانون update (مثل blocked_users): ردیف تکراری = بی‌اثر و بدون خطا
        if (existing.id != null) insertedIds.push(existing.id as string);
        continue;
      }
      if (existing) {
        const upd = policy.update?.(u);
        if (!policy.update || upd === false) throw new HttpError(403, "اجازه‌ی این کار را ندارید.");
        if (upd) {
          const ok = await env.DB.prepare(`SELECT 1 FROM "${q.table}" WHERE ${conflict.map((c) => `"${c}" = ?`).join(" AND ")} AND (${upd.sql})`)
            .bind(...conflict.map((c) => encodeValue(q.table, c, row[c])), ...upd.params)
            .first();
          if (!ok) throw new HttpError(403, "اجازه‌ی این کار را ندارید.");
        }
        let values = { ...row };
        for (const c of conflict) delete values[c];
        if (policy.guardUpdate) values = policy.guardUpdate(u, values);
        const keys = Object.keys(values);
        if (keys.length) {
          const old = [existing];
          await env.DB.prepare(
            `UPDATE "${q.table}" SET ${keys.map((k) => `"${k}" = ?`).join(", ")} WHERE ${conflict.map((c) => `"${c}" = ?`).join(" AND ")}`,
          )
            .bind(...keys.map((k) => encodeValue(q.table, k, values[k])), ...conflict.map((c) => encodeValue(q.table, c, row[c])))
            .run();
          await runAfterHooks(env, ctx, q.table, "update", old, values);
        }
        if (existing.id != null) insertedIds.push(existing.id as string);
        continue;
      }
      if (!policy.insert) throw new HttpError(403, "اجازه‌ی این کار را ندارید.");
      const verdict = await policy.insert(u, row, env);
      if (verdict !== true) throw new HttpError(403, verdict);
      defaultsForInsert(q.table, row, cols);
      const keys = Object.keys(row);
      const res = await env.DB.prepare(
        `INSERT INTO "${q.table}" (${keys.map((k) => `"${k}"`).join(",")}) VALUES (${keys.map(() => "?").join(",")}) RETURNING *`,
      )
        .bind(...keys.map((k) => encodeValue(q.table, k, row[k])))
        .first<Record<string, unknown>>()
        .catch((e: Error) => {
          const msg = String(e.message ?? e);
          if (msg.includes("UNIQUE")) throw new HttpError(409, "این مورد قبلاً ثبت شده است.", "23505");
          if (msg.includes("FOREIGN KEY")) throw new HttpError(409, "مورد مرتبط پیدا نشد.", "23503");
          if (msg.includes("CHECK")) throw new HttpError(400, "مقدار نامعتبر.", "23514");
          throw e;
        });
      if (res) {
        insertedRows.push(res);
        if (res.id != null) insertedIds.push(res.id as string);
      }
    }
    if (insertedRows.length) await runAfterHooks(env, ctx, q.table, "insert", insertedRows, null);
    if (!q.returning) return null;
    // ردیف(های) درج‌شده را با همان select درخواستی برگردان (با قوانین مشاهده‌ی خودِ کاربر)
    const back = await selectRows(env, u, { ...q, action: "select", filters: [], order: [], limit: null }, insertedIds);
    return finish(q, back.rows, back.parsed);
  }

  if (q.action === "update") {
    if (!policy.update) throw new HttpError(403, "اجازه‌ی این کار را ندارید.");
    const cond = policy.update(u);
    if (cond === false) throw new HttpError(403, "اجازه‌ی این کار را ندارید.");
    let values = { ...(q.values as Record<string, unknown>) };
    for (const k of Object.keys(values)) {
      assertIdent(k);
      if (!cols.has(k)) throw new HttpError(400, `ستون نامعتبر: ${k}`);
    }
    if (policy.guardUpdate) values = policy.guardUpdate(u, values);
    if (cols.has("updated_at") && values.updated_at === undefined && q.table === "content_items") values.updated_at = new Date().toISOString();
    const keys = Object.keys(values);
    if (!keys.length) return null;
    const { parts, params } = buildWhere(q.table, q.filters ?? [], cols);
    if (!parts.length) throw new HttpError(400, "به‌روزرسانی بدون شرط مجاز نیست.");
    applyCond(parts, params, cond);
    const where = parts.join(" AND ");
    const old = await loadRowsForHooks(env, q.table, where, params);
    await env.DB.prepare(`UPDATE "${q.table}" SET ${keys.map((k) => `"${k}" = ?`).join(", ")} WHERE ${where}`)
      .bind(...keys.map((k) => encodeValue(q.table, k, values[k])), ...params)
      .run();
    if (old.length) await runAfterHooks(env, ctx, q.table, "update", old, values);
    return null;
  }

  if (q.action === "delete") {
    if (!policy.delete) throw new HttpError(403, "اجازه‌ی این کار را ندارید.");
    const cond = policy.delete(u);
    if (cond === false) throw new HttpError(403, "اجازه‌ی این کار را ندارید.");
    const { parts, params } = buildWhere(q.table, q.filters ?? [], cols);
    if (!parts.length) throw new HttpError(400, "حذف بدون شرط مجاز نیست.");
    applyCond(parts, params, cond);
    const where = parts.join(" AND ");
    const old = await loadRowsForHooks(env, q.table, where, params);
    await env.DB.prepare(`DELETE FROM "${q.table}" WHERE ${where}`).bind(...params).run();
    if (old.length) await runAfterHooks(env, ctx, q.table, "delete", old, null);
    return null;
  }

  throw new HttpError(400, "عملیات نامعتبر.");
}

const ACTIVITY_SOURCES = [
  `SELECT author_id AS user_id, 'post' AS activity_type, id AS ref_id, substr(text,1,140) AS summary, created_at AS occurred_at FROM posts`,
  `SELECT author_id AS user_id, 'post_comment' AS activity_type, id AS ref_id, substr(text,1,140) AS summary, created_at AS occurred_at FROM comments`,
  `SELECT author_id AS user_id, 'video_comment' AS activity_type, id AS ref_id, substr(text,1,140) AS summary, created_at AS occurred_at FROM video_comments`,
  `SELECT author_id AS user_id, 'article_submission' AS activity_type, id AS ref_id, title AS summary, submitted_at AS occurred_at FROM article_submissions`,
  `SELECT author_id AS user_id, 'article_comment' AS activity_type, id AS ref_id, substr(text,1,140) AS summary, created_at AS occurred_at FROM article_comments`,
  `SELECT user_id, 'donation_transfer' AS activity_type, id AS ref_id, (amount || ' ' || currency || ' — ' || status) AS summary, submitted_at AS occurred_at FROM donation_transfers`,
  `SELECT user_id, 'contact_message' AS activity_type, id AS ref_id, substr(message,1,140) AS summary, created_at AS occurred_at FROM contact_messages`,
  `SELECT user_id, 'post_reaction' AS activity_type, post_id AS ref_id, emoji AS summary, created_at AS occurred_at FROM reactions`,
  `SELECT user_id, 'video_reaction' AS activity_type, video_id AS ref_id, emoji AS summary, created_at AS occurred_at FROM video_reactions`,
  `SELECT user_id, 'article_reaction' AS activity_type, featured_article_id AS ref_id, emoji AS summary, created_at AS occurred_at FROM article_reactions`,
  `SELECT user_id, 'comment_like' AS activity_type, comment_id AS ref_id, 'یک نظر را پسندید' AS summary, created_at AS occurred_at FROM comment_likes`,
];

/** تاریخچه‌ی فعالیت کاربران — هر منبع جدا پرس‌وجو و بعد ادغام می‌شود. */
async function activityLog(env: Env, q: QueryReq) {
  const userFilter = (q.filters ?? []).find(([c, op]) => c === "user_id" && op === "eq");
  const limit = Math.max(1, Math.min(1000, Math.floor(q.limit ?? 300)));
  const stmts = ACTIVITY_SOURCES.map((sql) => {
    const full = `SELECT * FROM (${sql}) ${userFilter ? "WHERE user_id = ?" : ""} ORDER BY occurred_at DESC LIMIT ${limit}`;
    return userFilter ? env.DB.prepare(full).bind(userFilter[2]) : env.DB.prepare(full);
  });
  const results = await env.DB.batch<Record<string, unknown>>(stmts);
  const rows = results.flatMap((r) => r.results ?? []);
  rows.sort((a, b) => String(b.occurred_at).localeCompare(String(a.occurred_at)));
  return rows.slice(0, limit);
}

export { POLICIES, encodeValue, columnsOf };
