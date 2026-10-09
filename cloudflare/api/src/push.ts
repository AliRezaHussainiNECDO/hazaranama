// پوش نوتیفیکیشن از طریق Firebase Cloud Messaging (HTTP v1).
// فقط وقتی کار می‌کند که سکرت FCM_SERVICE_ACCOUNT (JSON حساب سرویس Firebase)
// روی Worker تنظیم شده باشد؛ در غیر این صورت بی‌سروصدا رد می‌شود.
import type { Env } from "./types";
import { b64url } from "./auth";

let cached: { token: string; exp: number } | null = null;

function pemToBuf(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}

async function accessToken(sa: { client_email: string; private_key: string; token_uri: string }): Promise<string> {
  if (cached && cached.exp > Date.now() + 30_000) return cached.token;
  const enc = new TextEncoder();
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(enc.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claim = b64url(enc.encode(JSON.stringify({ iss: sa.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging", aud: sa.token_uri, iat: now, exp: now + 3600 })));
  const key = await crypto.subtle.importKey("pkcs8", pemToBuf(sa.private_key), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, enc.encode(`${head}.${claim}`)));
  const res = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${head}.${claim}.${b64url(sig)}` }),
  });
  if (!res.ok) throw new Error(`google token: ${res.status}`);
  const data = (await res.json()) as { access_token: string; expires_in?: number };
  cached = { token: data.access_token, exp: Date.now() + (data.expires_in ?? 3600) * 1000 };
  return cached.token;
}

export async function sendPushForNotifications(env: Env, rows: Array<Record<string, unknown>>) {
  if (!env.FCM_SERVICE_ACCOUNT || !rows.length) return;
  const sa = JSON.parse(env.FCM_SERVICE_ACCOUNT);
  // پلن رایگان Workers حداکثر ۵۰ زیردرخواست دارد؛ اعلان‌های همگانی را محدود می‌کنیم
  const userIds = [...new Set(rows.map((r) => r.user_id as string))].slice(0, 40);
  const byUser = new Map(rows.map((r) => [r.user_id as string, r]));
  const tokens = await env.DB.prepare(`SELECT id, user_id, token FROM device_tokens WHERE user_id IN (${userIds.map(() => "?").join(",")})`)
    .bind(...userIds)
    .all<{ id: string; user_id: string; token: string }>();
  const list = (tokens.results ?? []).slice(0, 45);
  if (!list.length) return;
  const at = await accessToken(sa);
  await Promise.all(
    list.map(async (t) => {
      const n = byUser.get(t.user_id)!;
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
        method: "POST",
        headers: { Authorization: `Bearer ${at}`, "Content-Type": "application/json; charset=utf-8" },
        body: JSON.stringify({
          message: {
            token: t.token,
            notification: { title: String(n.title ?? "هزاره‌نامه"), body: String(n.body ?? "") },
            data: { type: String(n.type ?? ""), ref_id: String(n.ref_id ?? ""), ref_type: String(n.ref_type ?? "") },
            android: { priority: "high", notification: { sound: "default", channel_id: "hazaranama_default" } },
            apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound: "default" } } },
          },
        }),
      });
      if (!res.ok) {
        const body = await res.text();
        if (res.status === 404 || body.includes("UNREGISTERED") || body.includes("NOT_FOUND")) {
          await env.DB.prepare("DELETE FROM device_tokens WHERE id = ?").bind(t.id).run();
        }
      }
    }),
  );
}
