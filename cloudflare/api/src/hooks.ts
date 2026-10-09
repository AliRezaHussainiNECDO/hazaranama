// جایگزین تریگرهای پستگرس: شمارنده‌ی نظرها، اعلان‌های درون‌اپی و پوش.
import type { Env, Ctx } from "./types";
import { sendPushForNotifications } from "./push";

type Row = Record<string, unknown>;

export async function loadRowsForHooks(env: Env, table: string, where: string, params: unknown[]): Promise<Row[]> {
  if (!HOOKED.has(table)) return [];
  const res = await env.DB.prepare(`SELECT * FROM "${table}" WHERE ${where}`).bind(...params).all<Row>();
  return res.results ?? [];
}

const HOOKED = new Set([
  "comments",
  "video_comments",
  "article_comments",
  "featured_articles",
  "article_submissions",
  "donation_transfers",
  "contact_messages",
]);

interface NewNotification {
  user_id: string;
  type: string;
  title: string;
  body: string;
  ref_id: string | null;
  ref_type: string | null;
}

export async function insertNotifications(env: Env, ctx: Ctx, list: NewNotification[]) {
  if (!list.length) return;
  const now = new Date().toISOString();
  const rows = list.map((n) => ({ id: crypto.randomUUID(), created_at: now, is_read: 0, ...n }));
  const stmt = env.DB.prepare(
    "INSERT INTO notifications (id, user_id, type, title, body, ref_id, ref_type, is_read, created_at) VALUES (?,?,?,?,?,?,?,?,?)",
  );
  for (let i = 0; i < rows.length; i += 50) {
    await env.DB.batch(
      rows.slice(i, i + 50).map((r) => stmt.bind(r.id, r.user_id, r.type, r.title, r.body, r.ref_id, r.ref_type, 0, r.created_at)),
    );
  }
  ctx.waitUntil(sendPushForNotifications(env, rows).catch((e) => console.error("push", e)));
}

async function nameOf(env: Env, id: unknown): Promise<string> {
  const r = await env.DB.prepare("SELECT name FROM profiles WHERE id = ?").bind(id).first<{ name: string }>();
  return r?.name ?? "یک کاربر";
}

const left = (s: unknown, n = 140) => String(s ?? "").slice(0, n);

const RATE: Record<string, number> = { USD: 1.0, EUR: 1.08, CHF: 1.12, GBP: 1.27, AFN: 0.014 };
const LEVEL10_USD = 1000; // باید با kDonorTiers.last.minUsd هماهنگ بماند

export async function runAfterHooks(env: Env, ctx: Ctx, table: string, op: "insert" | "update" | "delete", rows: Row[], changes: Row | null) {
  const notes: NewNotification[] = [];

  if (table === "comments") {
    const postIds = [...new Set(rows.map((r) => r.post_id as string))];
    for (const pid of postIds) {
      await env.DB.prepare("UPDATE posts SET comments_count = (SELECT COUNT(*) FROM comments WHERE post_id = ?) WHERE id = ?").bind(pid, pid).run();
    }
    if (op === "insert") {
      for (const c of rows) {
        let recipient: unknown = null;
        if (c.parent_comment_id) {
          recipient = (await env.DB.prepare("SELECT author_id FROM comments WHERE id = ?").bind(c.parent_comment_id).first<Row>())?.author_id;
        } else {
          recipient = (await env.DB.prepare("SELECT author_id FROM posts WHERE id = ?").bind(c.post_id).first<Row>())?.author_id;
        }
        if (recipient && recipient !== c.author_id) {
          const who = await nameOf(env, c.author_id);
          notes.push({
            user_id: recipient as string,
            type: c.parent_comment_id ? "post_reply" : "post_comment",
            title: c.parent_comment_id ? `${who} به نظر شما پاسخ داد` : `${who} روی پست شما نظر داد`,
            body: left(c.text),
            ref_id: c.post_id as string,
            ref_type: "post",
          });
        }
      }
    }
  }

  if (table === "video_comments" && op === "insert") {
    for (const c of rows) {
      if (!c.parent_comment_id) continue;
      const recipient = (await env.DB.prepare("SELECT author_id FROM video_comments WHERE id = ?").bind(c.parent_comment_id).first<Row>())?.author_id;
      if (recipient && recipient !== c.author_id) {
        notes.push({
          user_id: recipient as string,
          type: "video_reply",
          title: `${await nameOf(env, c.author_id)} به نظر شما روی یک ویدیو پاسخ داد`,
          body: left(c.text),
          ref_id: c.video_id as string,
          ref_type: "video",
        });
      }
    }
  }

  if (table === "article_comments" && op === "insert") {
    for (const c of rows) {
      const recipient = c.parent_comment_id
        ? (await env.DB.prepare("SELECT author_id FROM article_comments WHERE id = ?").bind(c.parent_comment_id).first<Row>())?.author_id
        : (await env.DB.prepare("SELECT author_id FROM featured_articles WHERE id = ?").bind(c.featured_article_id).first<Row>())?.author_id;
      if (recipient && recipient !== c.author_id) {
        const who = await nameOf(env, c.author_id);
        notes.push({
          user_id: recipient as string,
          type: c.parent_comment_id ? "article_reply" : "article_comment",
          title: c.parent_comment_id ? `${who} به نظر شما روی یک مقاله پاسخ داد` : `${who} روی مقاله‌ی برگزیده‌ی شما نظر داد`,
          body: left(c.text),
          ref_id: c.featured_article_id as string,
          ref_type: "article",
        });
      }
    }
  }

  if (table === "featured_articles" && op === "insert") {
    for (const a of rows) {
      if (a.author_id) {
        notes.push({ user_id: a.author_id as string, type: "article_featured", title: "مقاله‌ی شما برگزیده و منتشر شد! 🎉", body: String(a.title), ref_id: a.id as string, ref_type: "article" });
      }
    }
  }

  if (table === "article_submissions" && op === "update" && changes?.status !== undefined) {
    for (const s of rows) {
      if (s.status === changes.status) continue;
      let title: string | null = null;
      if (changes.status === "disqualified") title = "مقاله‌ی ارسالی شما رد صلاحیت شد";
      else if (changes.status === "closed") title = "دوره‌ی داوری مقاله‌ی شما تمام شد";
      if (title) notes.push({ user_id: s.author_id as string, type: "article_status", title, body: String(s.title), ref_id: s.id as string, ref_type: "article_submission" });
    }
  }

  if (table === "donation_transfers" && op === "update" && changes?.status !== undefined) {
    for (const d of rows) {
      if (d.status === changes.status) continue;
      let title: string | null = null;
      if (changes.status === "confirmed") title = "کمک مالی شما تأیید شد ✓";
      else if (changes.status === "rejected") title = "کمک مالی اعلام‌شده‌ی شما رد شد";
      if (title) notes.push({ user_id: d.user_id as string, type: "donation_status", title, body: `${d.amount} ${d.currency}`, ref_id: d.id as string, ref_type: "donation_transfer" });

      // اعلان همگانی رسیدن به مقام دهم (پادشاهی)
      if (changes.status === "confirmed") {
        const amount = (changes.confirmed_amount ?? d.confirmed_amount ?? d.amount) as number;
        const thisUsd = Number(amount) * (RATE[d.currency as string] ?? 1);
        const before = await env.DB.prepare(
          `SELECT COALESCE(SUM(COALESCE(confirmed_amount, amount) * CASE currency WHEN 'USD' THEN 1.0 WHEN 'EUR' THEN 1.08 WHEN 'CHF' THEN 1.12 WHEN 'GBP' THEN 1.27 WHEN 'AFN' THEN 0.014 ELSE 1.0 END), 0) AS t
           FROM donation_transfers WHERE user_id = ? AND status = 'confirmed' AND id <> ?`,
        )
          .bind(d.user_id, d.id)
          .first<{ t: number }>();
        const totalBefore = before?.t ?? 0;
        if (totalBefore < LEVEL10_USD && totalBefore + thisUsd >= LEVEL10_USD) {
          const who = await nameOf(env, d.user_id);
          const all = await env.DB.prepare("SELECT id FROM profiles").all<{ id: string }>();
          for (const p of all.results ?? []) {
            notes.push({
              user_id: p.id,
              type: "level10_reached",
              title: `کاربر ${who} به مقام پادشاهی (مرحله ۱۰) دست یافت! 👑`,
              body: "با کمک‌های تأییدشده‌اش، بالاترین مقام هزاره‌نامه را باز کرد.",
              ref_id: d.user_id as string,
              ref_type: "donor_tier",
            });
          }
        }
      }
    }
  }

  if (table === "contact_messages" && op === "update" && changes?.status === "replied") {
    for (const m of rows) {
      if (m.status === "replied") continue;
      notes.push({ user_id: m.user_id as string, type: "message_reply", title: "پشتیبانی به پیام شما پاسخ داد", body: left(changes.admin_reply ?? ""), ref_id: m.id as string, ref_type: "contact_message" });
    }
  }

  await insertNotifications(env, ctx, notes);
}
