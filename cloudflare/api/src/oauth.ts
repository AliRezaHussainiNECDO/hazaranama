// ورود و ثبت‌نام با فیسبوک و ایکس (توییتر) — جریان OAuth کاملاً سمت سرور.
// اپ صفحه‌ی ‎/auth/oauth/<provider>/start‎ را باز می‌کند؛ پس از تأیید کاربر، سرور حساب را
// می‌یابد یا می‌سازد و با یک «کد ورود» یک‌بارمصرف (نه توکن) به اپ برمی‌گرداند؛ اپ کد را با
// ‎/auth/oauth/exchange‎ به نشست تبدیل می‌کند.
import type { Env } from "./types";
import { sha256Hex } from "./auth";

export type Provider = "facebook" | "x" | "apple";
export type Profile = { id: string; name: string; email: string | null; avatar: string | null };

const API = "https://hazaranama-api.alireza-necdo.workers.dev";
// فقط به این نشانی‌ها برمی‌گردیم (جلوگیری از سوءاستفاده‌ی redirect)
const ALLOWED_REDIRECTS = [/^https:\/\/(www\.)?hazaranama\.com\//, /^https:\/\/([a-z0-9-]+\.)?hazaranama\.pages\.dev\//, /^hazaranama:\/\/oauth$/, /^http:\/\/localhost(:\d+)?\//];

// مقدار موقت «pending» یعنی هنوز تنظیم نشده
const set = (v?: string) => Boolean(v && v.trim() && v.trim().toLowerCase() !== "pending");
export function oauthProviders(env: Env) {
  return {
    facebook: set(env.FACEBOOK_APP_ID) && set(env.FACEBOOK_APP_SECRET),
    x: set(env.X_CLIENT_ID) && set(env.X_CLIENT_SECRET),
    apple: set(env.APPLE_TEAM_ID) && set(env.APPLE_KEY_ID) && set(env.APPLE_PRIVATE_KEY) && set(env.APPLE_SERVICES_ID),
    phone: set(env.PHONE_LOGIN),
  };
}

const rand = (n = 32) => {
  const b = crypto.getRandomValues(new Uint8Array(n));
  return btoa(String.fromCharCode(...b)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};
async function pkce(verifier: string) {
  const d = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier)));
  return btoa(String.fromCharCode(...d)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
const cb = (p: Provider) => `${API}/auth/oauth/${p}/callback`;

function page(title: string, msg: string, status = 400) {
  return new Response(
    `<!doctype html><html lang="fa" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title><body style="margin:0;min-height:100vh;display:grid;place-items:center;background:#0d1226;color:#f5f7ff;font-family:Tahoma,sans-serif;text-align:center;padding:24px"><div><h2>${title}</h2><p style="color:#a9b3d6">${msg}</p><a href="https://hazaranama.com/" style="color:#8fb2ff">بازگشت به هزاره‌نامه</a></div></body></html>`,
    { status, headers: { "content-type": "text/html; charset=utf-8" } },
  );
}

export async function oauthStart(env: Env, provider: Provider, url: URL): Promise<Response> {
  if (!oauthProviders(env)[provider]) return page("ورود در دسترس نیست", "این روش ورود هنوز فعال نشده است.");
  const redirect = url.searchParams.get("redirect") ?? "";
  if (!ALLOWED_REDIRECTS.some((r) => r.test(redirect))) return page("نشانی نامعتبر", "نشانی بازگشت مجاز نیست.");
  const state = rand();
  const verifier = provider === "x" ? rand(48) : null;
  await env.DB.prepare("DELETE FROM oauth_states WHERE created_at < ?").bind(Date.now() - 15 * 60_000).run();
  await env.DB.prepare("INSERT INTO oauth_states (state, provider, redirect, verifier, created_at) VALUES (?, ?, ?, ?, ?)").bind(state, provider, redirect, verifier, Date.now()).run();
  let target: string;
  if (provider === "facebook") {
    const q = new URLSearchParams({ client_id: env.FACEBOOK_APP_ID!, redirect_uri: cb("facebook"), state, scope: "email,public_profile", response_type: "code" });
    target = `https://www.facebook.com/v19.0/dialog/oauth?${q}`;
  } else if (provider === "apple") {
    const q = new URLSearchParams({ response_type: "code", response_mode: "form_post", client_id: env.APPLE_SERVICES_ID!, redirect_uri: cb("apple"), scope: "name email", state });
    target = `https://appleid.apple.com/auth/authorize?${q}`;
  } else {
    const q = new URLSearchParams({ response_type: "code", client_id: env.X_CLIENT_ID!, redirect_uri: cb("x"), scope: "users.read tweet.read", state, code_challenge: await pkce(verifier!), code_challenge_method: "S256" });
    target = `https://x.com/i/oauth2/authorize?${q}`;
  }
  return Response.redirect(target, 302);
}

async function fetchProfile(env: Env, provider: Provider, code: string, verifier: string | null, appleName?: string): Promise<Profile> {
  if (provider === "facebook") {
    const q = new URLSearchParams({ client_id: env.FACEBOOK_APP_ID!, client_secret: env.FACEBOOK_APP_SECRET!, redirect_uri: cb("facebook"), code });
    const t = (await (await fetch(`https://graph.facebook.com/v19.0/oauth/access_token?${q}`)).json()) as { access_token?: string };
    if (!t.access_token) throw new Error("facebook token");
    const me = (await (await fetch(`https://graph.facebook.com/v19.0/me?fields=id,name,email,picture.type(large)&access_token=${encodeURIComponent(t.access_token)}`)).json()) as {
      id?: string; name?: string; email?: string; picture?: { data?: { url?: string; is_silhouette?: boolean } };
    };
    if (!me.id) throw new Error("facebook profile");
    const pic = me.picture?.data;
    return { id: me.id, name: me.name ?? "", email: me.email ?? null, avatar: pic && !pic.is_silhouette ? pic.url ?? null : null };
  }
  if (provider === "apple") {
    const body = new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: cb("apple"), client_id: env.APPLE_SERVICES_ID!, client_secret: await appleClientSecret(env) });
    const t = (await (await fetch("https://appleid.apple.com/auth/token", { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" }, body })).json()) as { id_token?: string };
    if (!t.id_token) throw new Error("apple token");
    // id_token مستقیم از سرور اپل (روی TLS) آمده است
    const c = JSON.parse(new TextDecoder().decode(b64urlBytes(t.id_token.split(".")[1]))) as { sub: string; email?: string };
    return { id: c.sub, name: appleName ?? "", email: c.email ?? null, avatar: null };
  }
  const body = new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: cb("x"), code_verifier: verifier ?? "", client_id: env.X_CLIENT_ID! });
  const t = (await (
    await fetch("https://api.x.com/2/oauth2/token", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded", authorization: `Basic ${btoa(`${env.X_CLIENT_ID}:${env.X_CLIENT_SECRET}`)}` },
      body,
    })
  ).json()) as { access_token?: string };
  if (!t.access_token) throw new Error("x token");
  const me = (await (await fetch("https://api.x.com/2/users/me?user.fields=profile_image_url,name,username", { headers: { authorization: `Bearer ${t.access_token}` } })).json()) as {
    data?: { id: string; name?: string; username?: string; profile_image_url?: string };
  };
  if (!me.data?.id) throw new Error("x profile");
  return { id: me.data.id, name: me.data.name || me.data.username || "", email: null, avatar: me.data.profile_image_url?.replace("_normal", "_400x400") ?? null };
}

/** حساب را بر اساس شناسه‌ی شبکه یا ایمیل پیدا می‌کند، و اگر نبود می‌سازد. شناسه‌ی کاربر را برمی‌گرداند. */
export type EnsureUser = (provider: Provider | "phone", p: Profile) => Promise<string>;

export async function oauthCallback(env: Env, provider: Provider, params: URLSearchParams, ensureUser: EnsureUser): Promise<Response> {
  const state = params.get("state") ?? "";
  const row = await env.DB.prepare("SELECT * FROM oauth_states WHERE state = ? AND provider = ? AND login_code IS NULL")
    .bind(state, provider)
    .first<{ redirect: string; verifier: string | null; created_at: number }>();
  if (!row || Date.now() - row.created_at > 15 * 60_000) return page("درخواست منقضی شد", "لطفاً دوباره از داخل اپ تلاش کنید.");
  const code = params.get("code");
  const sep = row.redirect.includes("?") ? "&" : "?";
  if (!code) {
    await env.DB.prepare("DELETE FROM oauth_states WHERE state = ?").bind(state).run();
    return Response.redirect(`${row.redirect}${sep}hz_oauth_error=cancelled`, 302);
  }
  try {
    let appleName: string | undefined;
    try {
      const u = JSON.parse(params.get("user") ?? "null") as { name?: { firstName?: string; lastName?: string } } | null;
      if (u?.name) appleName = `${u.name.firstName ?? ""} ${u.name.lastName ?? ""}`.trim();
    } catch {}
    const profile = await fetchProfile(env, provider, code, row.verifier, appleName);
    const userId = await ensureUser(provider, profile);
    const loginCode = rand();
    await env.DB.prepare("UPDATE oauth_states SET login_code = ?, user_id = ?, created_at = ? WHERE state = ?").bind(await sha256Hex(loginCode), userId, Date.now(), state).run();
    return Response.redirect(`${row.redirect}${sep}hz_oauth=${loginCode}`, 302);
  } catch (e) {
    console.error("oauth", provider, String(e));
    return Response.redirect(`${row.redirect}${sep}hz_oauth_error=failed`, 302);
  }
}

/** کد ورود یک‌بارمصرف (۵ دقیقه) را به شناسه‌ی کاربر تبدیل می‌کند */
export async function oauthExchange(env: Env, loginCode: string): Promise<string | null> {
  const h = await sha256Hex(loginCode);
  const row = await env.DB.prepare("DELETE FROM oauth_states WHERE login_code = ? RETURNING user_id, created_at").bind(h).first<{ user_id: string; created_at: number }>();
  if (!row || Date.now() - row.created_at > 5 * 60_000) return null;
  return row.user_id;
}


// ---------------- ابزار JWT: امضای ES256 برای اپل و بررسی RS256 (اپل و Firebase) ----------------
function b64urlBytes(s: string): Uint8Array {
  const b = atob(s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4));
  return Uint8Array.from(b, (c) => c.charCodeAt(0));
}
const b64urlStr = (u: Uint8Array) => btoa(String.fromCharCode(...u)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

/** client_secret اپل: JWT امضاشده با کلید ‎.p8‎ (ES256)، ۱۰ دقیقه اعتبار */
async function appleClientSecret(env: Env): Promise<string> {
  const pem = env.APPLE_PRIVATE_KEY!.replace(/-----[^-]+-----/g, "").replace(/\\n|\s/g, "");
  const key = await crypto.subtle.importKey("pkcs8", b64urlBytes(pem.replace(/\+/g, "-").replace(/\//g, "_")), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const now = Math.floor(Date.now() / 1000);
  const enc = new TextEncoder();
  const head = b64urlStr(enc.encode(JSON.stringify({ alg: "ES256", kid: env.APPLE_KEY_ID })));
  const body = b64urlStr(enc.encode(JSON.stringify({ iss: env.APPLE_TEAM_ID, iat: now, exp: now + 600, aud: "https://appleid.apple.com", sub: env.APPLE_SERVICES_ID })));
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, enc.encode(`${head}.${body}`)));
  return `${head}.${body}.${b64urlStr(sig)}`;
}

const jwksCache = new Map<string, { at: number; keys: JsonWebKey[] }>();
async function verifyRs256(token: string, jwksUrl: string): Promise<Record<string, unknown> | null> {
  const [h, p, sg] = token.split(".");
  if (!h || !p || !sg) return null;
  const header = JSON.parse(new TextDecoder().decode(b64urlBytes(h))) as { kid?: string; alg?: string };
  if (header.alg !== "RS256") return null;
  let c = jwksCache.get(jwksUrl);
  if (!c || Date.now() - c.at > 3600_000 || !c.keys.some((k) => (k as { kid?: string }).kid === header.kid)) {
    c = { at: Date.now(), keys: ((await (await fetch(jwksUrl)).json()) as { keys: JsonWebKey[] }).keys };
    jwksCache.set(jwksUrl, c);
  }
  const jwk = c.keys.find((k) => (k as { kid?: string }).kid === header.kid);
  if (!jwk) return null;
  const key = await crypto.subtle.importKey("jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, b64urlBytes(sg), new TextEncoder().encode(`${h}.${p}`));
  if (!ok) return null;
  const claims = JSON.parse(new TextDecoder().decode(b64urlBytes(p))) as Record<string, unknown>;
  if (typeof claims.exp !== "number" || claims.exp < Date.now() / 1000) return null;
  return claims;
}

/** ورود بومی اپل در iOS: identityToken را با کلیدهای عمومی اپل بررسی می‌کند */
export async function verifyAppleIdentity(env: Env, identityToken: string): Promise<{ sub: string; email: string | null } | null> {
  const c = await verifyRs256(identityToken, "https://appleid.apple.com/auth/keys");
  if (!c || c.iss !== "https://appleid.apple.com") return null;
  const allowed = [env.APPLE_BUNDLE_ID || "com.hazaranama.hazaranama", env.APPLE_SERVICES_ID].filter(Boolean);
  if (!allowed.includes(String(c.aud))) return null;
  return { sub: String(c.sub), email: typeof c.email === "string" ? c.email : null };
}

/** ورود با شماره‌ی تلفن: ID token فایربیس (پس از تأیید پیامک) را بررسی می‌کند و شماره را برمی‌گرداند */
export async function verifyFirebasePhone(env: Env, idToken: string): Promise<string | null> {
  const project = env.FIREBASE_PROJECT_ID || "hazaranama";
  const c = await verifyRs256(idToken, "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com");
  if (!c || c.iss !== `https://securetoken.google.com/${project}` || c.aud !== project) return null;
  const phone = typeof c.phone_number === "string" ? c.phone_number : null;
  return phone && /^\+\d{7,15}$/.test(phone) ? phone : null;
}
