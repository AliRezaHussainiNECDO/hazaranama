// =============================================================================
// هزاره‌نامه — حذف کامل حساب کاربری (Supabase Edge Function)
// =============================================================================
// این تابع را خودِ کاربرِ واردشده صدا می‌زند (نه ادمین، نه کاربر دیگر) تا
// حساب و تمام داده‌های شخصی خودش را برای همیشه پاک کند — الزام اجباری
// Google Play (Account Deletion policy) و اپل (App Store Review Guideline
// 5.1.1(v)): هر اپی که ثبت‌نام دارد، باید حذف حساب از داخل اپ را هم بدهد.
//
// امنیت: verify_jwt=true است (نگاه کنید به supabase/config.toml)، یعنی
// پلتفرم Supabase پیش از رسیدن درخواست به این کد، معتبربودن JWT را تأیید
// کرده. اما این کد هنوز باید خودش، از روی همان JWT (نه از روی چیزی که
// کلاینت در بدنه‌ی درخواست فرستاده)، بفهمد این توکن مال کدام کاربر است —
// وگرنه کاربر A می‌توانست id کاربر B را در بدنه بفرستد و حساب او را حذف کند.
//
// حذف ردیف کاربر از auth.users به‌طور خودکار (از طریق «on delete cascade»ی
// تعریف‌شده در تمام جدول‌های اسکیمای این پروژه) profile و هر پست، کامنت،
// واکنش، پیام، اعلان، توکن دستگاه، شرکت در مسابقه و... متعلق به او را هم پاک
// می‌کند. تنها چیزی که این cascade پوشش نمی‌دهد، فایل‌های خودِ Storage
// (عکس/ویدیوی پروفایل و پست‌ها) است که جداگانه، به‌صورت best-effort، پاک
// می‌شوند.
//
// استقرار:
//   supabase functions deploy delete-account
// =============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json; charset=utf-8" },
  });
}

// این باکت‌ها بر اساس قرارداد «هر کاربر فقط در پوشه‌ی $userId/ خودش می‌نویسد»
// در supabase_service.dart سازمان‌دهی شده‌اند (uploadAvatar, uploadPostImage/Video).
const USER_OWNED_BUCKETS = ["avatars", "post-media"];

async function deleteUserStorageFolder(
  admin: ReturnType<typeof createClient>,
  bucket: string,
  userId: string,
): Promise<void> {
  try {
    // فایل‌های مستقیم زیر پوشه‌ی کاربر (مثل آواتار)
    const { data: rootFiles } = await admin.storage.from(bucket).list(userId);
    const paths: string[] = [];
    for (const f of rootFiles ?? []) {
      if (f.id) paths.push(`${userId}/${f.name}`);
      else {
        // زیرپوشه (مثل images/ یا videos/ در post-media) — یک سطح دیگر لیست کن
        const { data: sub } = await admin.storage.from(bucket).list(`${userId}/${f.name}`);
        for (const sf of sub ?? []) paths.push(`${userId}/${f.name}/${sf.name}`);
      }
    }
    if (paths.length > 0) await admin.storage.from(bucket).remove(paths);
  } catch (_e) {
    // پاک‌سازی Storage تلاش «best-effort» است؛ اگر شکست بخورد، نباید کل حذف
    // حساب را متوقف کند — رکورد کاربر همچنان باید پاک شود.
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "روش نامعتبر است." }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "نشست معتبر یافت نشد." }, 401);

  // کلاینتی با anon key + توکن خودِ کاربر — این تنها راه امن برای فهمیدن
  // «این درخواست واقعاً از طرف کدام کاربر است» بدون اعتماد به بدنه‌ی درخواست.
  const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: userData, error: userErr } = await callerClient.auth.getUser();
  if (userErr || !userData?.user) {
    return json({ error: "کاربر شناسایی نشد؛ لطفاً دوباره وارد شوید." }, 401);
  }
  const userId = userData.user.id;

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  for (const bucket of USER_OWNED_BUCKETS) {
    await deleteUserStorageFolder(admin, bucket, userId);
  }

  const { error: delErr } = await admin.auth.admin.deleteUser(userId);
  if (delErr) {
    return json({ error: `حذف حساب ناموفق بود: ${delErr.message}` }, 500);
  }

  return json({ ok: true });
});
