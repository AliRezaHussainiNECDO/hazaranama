// احراز هویت: هش رمز (PBKDF2)، تأیید هش‌های bcrypt کاربران منتقل‌شده از
// Supabase، و توکن‌های JWT (HS256) — همه با WebCrypto خودِ Workers.
import bcrypt from "bcryptjs";

const enc = new TextEncoder();

// روی پلن رایگان Workers هر درخواست فقط چند میلی‌ثانیه CPU دارد؛ ۲۰٬۰۰۰ دور
// PBKDF2-SHA256 (بومی و سریع) با نمک تصادفی ۱۶ بایتی تعادل خوبی است.
const PBKDF2_ITER = 20000;

export function b64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function b64urlDecode(s: string): Uint8Array {
  s = s.replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function timingSafeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a[i] ^ b[i];
  return r === 0;
}

async function pbkdf2(password: string, salt: Uint8Array, iter: number): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey("raw", enc.encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations: iter }, key, 256);
  return new Uint8Array(bits);
}

export async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await pbkdf2(password, salt, PBKDF2_ITER);
  return `pbkdf2$${PBKDF2_ITER}$${b64url(salt)}$${b64url(hash)}`;
}

/** نتیجه: ok و این‌که آیا هش باید به قالب تازه بازنویسی شود (کاربران bcrypt). */
export async function verifyPassword(password: string, stored: string): Promise<{ ok: boolean; rehash: boolean }> {
  if (stored.startsWith("pbkdf2$")) {
    const [, iterS, saltS, hashS] = stored.split("$");
    const hash = await pbkdf2(password, b64urlDecode(saltS), parseInt(iterS, 10));
    return { ok: timingSafeEqual(hash, b64urlDecode(hashS)), rehash: false };
  }
  if (stored.startsWith("$2")) {
    // هش‌های bcrypt از Supabase Auth — فقط یک‌بار در اولین ورود بررسی و بعد بازنویسی می‌شوند
    const ok = bcrypt.compareSync(password, stored);
    return { ok, rehash: ok };
  }
  return { ok: false, rehash: false };
}

export async function sha256Hex(s: string): Promise<string> {
  const d = new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(s)));
  return [...d].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// ---------------- JWT (HS256) ----------------

export interface Claims {
  sub: string;
  email: string;
  tv: number; // token_version
  iat: number;
  exp: number;
}

async function hmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"]);
}

export const SESSION_SECONDS = 60 * 60 * 24 * 60; // ۶۰ روز

export async function signJwt(claims: Omit<Claims, "iat" | "exp">, secret: string): Promise<{ token: string; exp: number }> {
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + SESSION_SECONDS;
  const header = b64url(enc.encode(JSON.stringify({ alg: "HS256", typ: "JWT" })));
  const payload = b64url(enc.encode(JSON.stringify({ ...claims, iat, exp })));
  const unsigned = `${header}.${payload}`;
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", await hmacKey(secret), enc.encode(unsigned)));
  return { token: `${unsigned}.${b64url(sig)}`, exp };
}

export async function verifyJwt(token: string, secret: string): Promise<Claims | null> {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const ok = await crypto.subtle.verify("HMAC", await hmacKey(secret), b64urlDecode(parts[2]), enc.encode(`${parts[0]}.${parts[1]}`));
  if (!ok) return null;
  try {
    const claims = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[1]))) as Claims;
    if (claims.exp < Math.floor(Date.now() / 1000)) return null;
    return claims;
  } catch {
    return null;
  }
}
