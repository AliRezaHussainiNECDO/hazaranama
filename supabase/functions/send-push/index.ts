// =============================================================================
// هزاره‌نامه — ارسال پوش نوتیفیکیشن واقعی (Firebase Cloud Messaging)
// =============================================================================
// این تابع را نه کاربر و نه اپ فلاتر مستقیم صدا نمی‌زند — یک Database Webhook
// در Supabase، دقیقاً وقتی یک ردیف تازه در public.notifications ساخته می‌شود
// (یعنی همان لحظه‌ای که trigger‌های SQL یک اعلان درون‌اپی می‌سازند)، خودکار
// همین تابع را با آن ردیف صدا می‌زند. این تابع توکن‌های FCM کاربر مقصد را از
// device_tokens می‌خواند و پیام را مستقیم به گوشی‌اش می‌فرستد — حتی اگر اپ
// بسته باشد.
//
// امنیت: چون این تابع باید از یک Webhook داخلی (نه کاربر واردشده) صدا زده
// شود، verify_jwt برایش خاموش است (نگاه کنید به supabase/config.toml)؛ به‌جایش
// یک هدر مخفی (x-webhook-secret) چک می‌شود که فقط خودِ تعریف Webhook آن را
// می‌داند — بدون آن، هرکسی که آدرس تابع را حدس بزند می‌توانست برای کاربران
// واقعی پوش جعلی بفرستد.
//
// تنظیم (یک‌بار، فقط سمت سرور — هرگز در کد یا گیت):
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='...محتوای کامل فایل service account...'
//   supabase secrets set PUSH_WEBHOOK_SECRET='یک رشته‌ی تصادفی دلخواه'
// (SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY خودکار در اختیار هر Edge Function هست.)
//
// استقرار:
//   supabase functions deploy send-push --no-verify-jwt
// =============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

const WEBHOOK_SECRET = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";
const SERVICE_ACCOUNT_RAW = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";

const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// -----------------------------------------------------------------------------
// گرفتن Access Token از گوگل با گواهی‌نامه‌ی سرویس (Service Account) — بدون
// هیچ پکیج سنگین، فقط با Web Crypto API خودِ Deno (امضای RS256).
// -----------------------------------------------------------------------------
function base64url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

let cachedToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(
  sa: { client_email: string; private_key: string; token_uri: string },
): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 30_000) {
    return cachedToken.token;
  }

  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: sa.token_uri,
    exp: now + 3600,
    iat: now,
  };
  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claim))}`;

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64url(new Uint8Array(signature))}`;

  const res = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`دریافت توکن گوگل شکست خورد: ${await res.text()}`);
  }
  const data = await res.json();
  cachedToken = {
    token: data.access_token as string,
    expiresAt: Date.now() + (Number(data.expires_in ?? 3600) * 1000),
  };
  return cachedToken.token;
}

// -----------------------------------------------------------------------------
// مسیریاب اصلی — یک ردیف تازه‌ی notifications را می‌گیرد و برای همه‌ی
// دستگاه‌های ثبت‌شده‌ی همان کاربر پوش می‌فرستد.
// -----------------------------------------------------------------------------
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("فقط POST مجاز است.", { status: 405 });
  }

  if (!WEBHOOK_SECRET || req.headers.get("x-webhook-secret") !== WEBHOOK_SECRET) {
    return new Response("دسترسی مجاز نیست.", { status: 401 });
  }

  if (!SERVICE_ACCOUNT_RAW) {
    console.error("FIREBASE_SERVICE_ACCOUNT_JSON تنظیم نشده است.");
    // 200 برمی‌گردانیم تا Supabase دوباره و دوباره webhook را retry نکند
    return new Response("سرویس پوش هنوز تنظیم نشده است.", { status: 200 });
  }

  let payload: { record?: Record<string, unknown> };
  try {
    payload = await req.json();
  } catch {
    return new Response("بدنه‌ی درخواست نامعتبر است.", { status: 400 });
  }

  const record = payload.record;
  if (!record || typeof record.user_id !== "string") {
    return new Response("رکورد نامعتبر یا بدون user_id.", { status: 200 });
  }

  const { data: tokens, error } = await supabaseAdmin
    .from("device_tokens")
    .select("id, token")
    .eq("user_id", record.user_id);

  if (error) {
    console.error("خطا در خواندن device_tokens:", error);
    return new Response("خطای دیتابیس.", { status: 500 });
  }
  if (!tokens || tokens.length === 0) {
    return new Response("این کاربر هیچ دستگاه ثبت‌شده‌ای ندارد.", { status: 200 });
  }

  try {
    const serviceAccount = JSON.parse(SERVICE_ACCOUNT_RAW) as {
      client_email: string;
      private_key: string;
      token_uri: string;
      project_id: string;
    };
    const accessToken = await getAccessToken(serviceAccount);
    const projectId = serviceAccount.project_id;

    const results = await Promise.all(tokens.map(async (t) => {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json; charset=utf-8",
          },
          body: JSON.stringify({
            message: {
              token: t.token,
              notification: {
                title: String(record.title ?? "هزاره‌نامه"),
                body: String(record.body ?? ""),
              },
              data: {
                type: String(record.type ?? ""),
                ref_id: String(record.ref_id ?? ""),
                ref_type: String(record.ref_type ?? ""),
              },
              android: { priority: "high", notification: { sound: "default", channel_id: "hazaranama_default" } },
              apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound: "default" } } },
            },
          }),
        },
      );

      if (!res.ok) {
        const errBody = await res.text();
        console.error(`FCM خطا برای توکن ${t.id}:`, res.status, errBody);
        // توکن دیگر معتبر نیست (اپ حذف شده یا دستگاه عوض شده) — پاکش کن
        if (res.status === 404 || errBody.includes("UNREGISTERED") || errBody.includes("NOT_FOUND")) {
          await supabaseAdmin.from("device_tokens").delete().eq("id", t.id);
        }
        return { ok: false, status: res.status };
      }
      return { ok: true };
    }));

    const sent = results.filter((r) => r.ok).length;
    return new Response(JSON.stringify({ sent, total: results.length }), {
      headers: { "Content-Type": "application/json; charset=utf-8" },
    });
  } catch (e) {
    console.error(e);
    const message = e instanceof Error ? e.message : "خطای ناشناخته در ارسال پوش.";
    return new Response(message, { status: 500 });
  }
});
