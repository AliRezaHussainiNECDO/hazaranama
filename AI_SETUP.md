# راه‌اندازی هوش مصنوعی هزاره‌نامه

همه‌ی قابلیت‌های هوش مصنوعی (دستیار گفتگو، جستجوی معنایی، پیشنهاد محتوا،
ابزار مدیر، بررسی و رتبه‌بندی مقاله‌های مسابقه با `review_article`، و نگارش
گزارش شفافیت با `draft_donation_report`) از مسیر `/functions/ai-gateway`
روی Worker هزاره‌نامه رد می‌شوند و با **Cloudflare Workers AI** کار می‌کنند.

- هیچ کلید API لازم نیست؛ اتصال `AI` در `cloudflare/api/wrangler.toml` تعریف شده.
- مدل در متغیر `AI_MODEL` همان فایل تعیین می‌شود (اکنون `@cf/google/gemma-3-12b-it`).
  برای تغییر مدل، مقدار را عوض کنید و push کنید.
- کد: `cloudflare/api/src/ai.ts`. گزارش‌ها و خطاها در داشبورد Cloudflare ←
  Workers ← hazaranama-api ← Logs دیده می‌شوند.
- هزینه: Workers AI در پلن رایگان سهمیه‌ی روزانه‌ی محدودی دارد.

نسخه‌ی قدیمی (Supabase Edge Function + Gemini) فقط برای سابقه در `legacy/supabase` است.
