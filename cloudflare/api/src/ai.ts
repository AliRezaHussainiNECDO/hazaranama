// دستیار هوشمند هزاره‌نامه روی Workers AI خودِ Cloudflare (جایگزین Gemini).
// همان وظایف قبلی: chat / search / recommend / admin / review_article / draft_donation_report
import type { Env } from "./types";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json; charset=utf-8" } });
}

const DEFAULT_MODEL = "@cf/google/gemma-3-12b-it";

function extractJson(text: string): string {
  const t = text.replace(/```(?:json)?/g, "").trim();
  const s = t.indexOf("{");
  const e = t.lastIndexOf("}");
  return s >= 0 && e > s ? t.slice(s, e + 1) : t;
}

async function callModel(env: Env, opts: {
  systemInstruction: string;
  contents: Array<{ role: "user" | "model"; parts: Array<{ text: string }> }>;
  jsonSchema?: Record<string, unknown>;
  temperature?: number;
}): Promise<string> {
  let system = opts.systemInstruction;
  if (opts.jsonSchema) {
    system += "\n\nخروجی را فقط و فقط به‌صورت یک شیء JSON معتبر مطابق این طرح برگردان، بدون هیچ متن یا توضیح اضافه: " +
      JSON.stringify(opts.jsonSchema);
  }
  const messages = [
    { role: "system", content: system },
    ...opts.contents.map((c) => ({ role: c.role === "model" ? "assistant" : "user", content: c.parts.map((p) => p.text).join("") })),
  ];
  const model = env.AI_MODEL || DEFAULT_MODEL;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const out: any = await env.AI.run(model as any, { messages, max_tokens: 1024, temperature: opts.temperature ?? 0.6 });
  const text = typeof out?.response === "string" ? out.response : (out?.response ? JSON.stringify(out.response) : "");
  if (!text) throw new Error("پاسخی از سرویس هوش مصنوعی دریافت نشد.");
  return opts.jsonSchema ? extractJson(text) : text.trim();
}

const BASE_PERSONA = `تو «راهنمای هزاره‌نامه» هستی؛ دستیار هوشمند اپلیکیشن هزاره‌نامه —
مرجع دیجیتال تاریخ، فرهنگ و حافظه‌ی جمعی مردم هزاره. اصول تو:
- همیشه به زبان فارسی/دری، با لحنی گرم، محترمانه و دقیق پاسخ بده.
- درباره‌ی تاریخ، فرهنگ، زبان هزارگی، شخصیت‌های برجسته، رویدادها و جغرافیای هزارستان
  با دقت تاریخی صحبت کن؛ اگر از چیزی مطمئن نیستی، صادقانه بگو و حدس را با واقعیت قاطی نکن.
- درباره‌ی رویدادهای دردناک (مانند نسل‌کشی‌ها) با احترام و بدون تحریک خشونت یا نفرت‌پراکنی
  علیه هیچ قوم یا گروهی بنویس؛ روایت مستند و انسانی باش، نه حزبی یا سیاسی.
- پاسخ‌ها کوتاه، خوانا و مفید باشند (معمولاً ۲ تا ۶ جمله)، مگر کاربر توضیح مفصل بخواهد.`;

async function handleChat(env: Env, body: Record<string, unknown>): Promise<Response> {
  const message = String(body.message ?? "").trim();
  if (!message) return json({ error: "پیام خالی است." }, 400);

  const history = Array.isArray(body.history) ? body.history as Array<{ role: string; text: string }> : [];
  const contents = [
    ...history.slice(-12).map((h) => ({
      role: (h.role === "assistant" || h.role === "model") ? "model" as const : "user" as const,
      parts: [{ text: String(h.text ?? "") }],
    })),
    { role: "user" as const, parts: [{ text: message }] },
  ];

  const reply = await callModel(env, { systemInstruction: BASE_PERSONA, contents, temperature: 0.7 });
  return json({ reply });
}

// -----------------------------------------------------------------------------
// ۲) جستجوی هوشمند معنایی
// -----------------------------------------------------------------------------
async function handleSearch(env: Env, body: Record<string, unknown>): Promise<Response> {
  const query = String(body.query ?? "").trim();
  if (!query) return json({ error: "عبارت جستجو خالی است." }, 400);

  const sections = Array.isArray(body.sections) ? body.sections as Array<{ id: string; title: string; description: string }> : [];
  const sectionsList = sections.map((s) => `- id:"${s.id}" | ${s.title} — ${s.description}`).join("\n");

  const prompt =
    `عبارت جستجوی کاربر: "${query}"\n\n` +
    `فهرست بخش‌های موجود در اپ هزاره‌نامه:\n${sectionsList}\n\n` +
    `یک پاسخ کوتاه و مفید فارسی به عبارت جستجو بده (بر اساس دانش عمومی درباره‌ی تاریخ و فرهنگ هزاره، ` +
    `نه لزوماً محتوای دقیق اپ) و حداکثر ۳ مورد از id های فهرست بالا را که مرتبط‌ترین هستند انتخاب کن.`;

  const schema = {
    type: "OBJECT",
    properties: {
      answer: { type: "STRING" },
      sectionIds: { type: "ARRAY", items: { type: "STRING" } },
    },
    required: ["answer", "sectionIds"],
  };

  const raw = await callModel(env, {
    systemInstruction: BASE_PERSONA,
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    jsonSchema: schema,
    temperature: 0.4,
  });

  try {
    const parsed = JSON.parse(raw);
    const validIds = new Set(sections.map((s) => s.id));
    const sectionIds = Array.isArray(parsed.sectionIds)
      ? parsed.sectionIds.filter((id: unknown) => typeof id === "string" && validIds.has(id)).slice(0, 3)
      : [];
    return json({ answer: String(parsed.answer ?? ""), sectionIds });
  } catch {
    return json({ answer: raw, sectionIds: [] });
  }
}

// -----------------------------------------------------------------------------
// ۳) پیشنهاد و شخصی‌سازی محتوا
// -----------------------------------------------------------------------------
async function handleRecommend(env: Env, body: Record<string, unknown>): Promise<Response> {
  const profile = (body.profile ?? {}) as Record<string, unknown>;
  const sections = Array.isArray(body.sections) ? body.sections as Array<{ id: string; title: string; description: string }> : [];
  const sectionsList = sections.map((s) => `- id:"${s.id}" | ${s.title} — ${s.description}`).join("\n");

  const prompt =
    `پروفایل کاربر:\n` +
    `طایفه: ${profile.tribe ?? "نامشخص"} | ولایت خاستگاه: ${profile.originProvince ?? "نامشخص"} | ` +
    `زبان مادری: ${profile.nativeLanguage ?? "نامشخص"} | یادداشت: ${profile.bio ?? "—"}\n\n` +
    `فهرست بخش‌های اپ:\n${sectionsList}\n\n` +
    `دقیقاً ۳ بخش را که با توجه به پروفایل این کاربر بیشترین ارتباط و جذابیت را دارند انتخاب کن؛ ` +
    `برای هرکدام یک دلیل خیلی کوتاه (حداکثر ۸ کلمه) فارسی بنویس.`;

  const schema = {
    type: "OBJECT",
    properties: {
      picks: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          properties: {
            sectionId: { type: "STRING" },
            reason: { type: "STRING" },
          },
          required: ["sectionId", "reason"],
        },
      },
    },
    required: ["picks"],
  };

  const raw = await callModel(env, {
    systemInstruction: BASE_PERSONA,
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    jsonSchema: schema,
    temperature: 0.5,
  });

  try {
    const parsed = JSON.parse(raw);
    const validIds = new Set(sections.map((s) => s.id));
    const picks = Array.isArray(parsed.picks)
      ? parsed.picks.filter((p: { sectionId?: string }) => typeof p.sectionId === "string" && validIds.has(p.sectionId)).slice(0, 3)
      : [];
    return json({ picks });
  } catch {
    return json({ picks: [] });
  }
}

// -----------------------------------------------------------------------------
// ۴) ابزار هوش مصنوعی برای مدیر (پیش‌نویس / خلاصه / ترجمه)
// -----------------------------------------------------------------------------
async function handleAdmin(env: Env, body: Record<string, unknown>): Promise<Response> {
  const action = String(body.action ?? "draft");
  const sectionTitle = String(body.sectionTitle ?? "");
  const topic = String(body.topic ?? "").trim();
  const sourceText = String(body.sourceText ?? "").trim();
  const targetLang = String(body.targetLang ?? "فارسی");

  if (!topic && !sourceText) return json({ error: "موضوع یا متن ورودی لازم است." }, 400);

  let prompt: string;
  if (action === "summarize") {
    prompt = `متن زیر را برای بخش «${sectionTitle}» در ۲ تا ۳ جمله‌ی فارسی خلاصه کن:\n\n${sourceText}`;
  } else if (action === "translate") {
    prompt = `متن زیر را به ${targetLang} ترجمه کن؛ فقط متن ترجمه‌شده را برگردان، بدون توضیح اضافه:\n\n${sourceText}`;
  } else {
    prompt =
      `یک پیش‌نویس محتوای مستند و دقیق فارسی برای بخش «${sectionTitle}» اپ هزاره‌نامه درباره‌ی ` +
      `«${topic}» بنویس (۳ تا ۵ جمله، لحن دانشنامه‌ای و بی‌طرف).`;
  }

  const text = await callModel(env, {
    systemInstruction: BASE_PERSONA,
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    temperature: 0.55,
  });
  return json({ text });
}

// -----------------------------------------------------------------------------
// ۵) بررسی اصالت مقاله برای مسابقه‌ی مقالات (کمکی برای مدیر، نه داوری خودکار)
// -----------------------------------------------------------------------------
async function handleReviewArticle(env: Env, body: Record<string, unknown>): Promise<Response> {
  const title = String(body.title ?? "").trim();
  const articleBody = String(body.body ?? "").trim();
  if (!articleBody) return json({ error: "متن مقاله خالی است." }, 400);

  const prompt =
    `تو داور کمکی «مسابقه‌ی مقالات هزاره‌نامه» هستی و دو کار همزمان انجام می‌دهی: ` +
    `اول بررسی اصالت، دوم نمره‌دهی کیفیت. متن زیر را یک کاربر عادی به‌عنوان مقاله‌ی خودش ` +
    `ارسال کرده.\n\n` +
    `بخش اول — اصالت: حدس بزن این متن واقعاً توسط یک انسان معمولی و با دانش/تجربه‌ی ` +
    `شخصی نوشته شده، یا نشانه‌های نگران‌کننده دارد — مثلاً: لحن و ساختار مصنوعی و ` +
    `کلیشه‌ای شبیه پاسخ‌های چت‌بات‌های هوش مصنوعی (ChatGPT/Gemini/...)، عمومی و ` +
    `بی‌جزئیات‌بودن بیش‌ازحد، یا شباهت زیاد به متنی که احتمالاً از یک منبع دیگر عیناً ` +
    `کپی شده. این تشخیص هرگز قطعی نیست؛ فقط یک برآورد کمکی برای مدیر است، نه حکم نهایی.\n\n` +
    `بخش دوم — کیفیت: صرف‌نظر از اصالت، این مقاله از نظر محتوا، عمق، انسجام، دقت ` +
    `تاریخی/فرهنگی (اگر مرتبط با هزاره‌ها یا افغانستان است) و کیفیت نگارش چقدر قوی و ` +
    `عالی است؟ این نمره برای رتبه‌بندی مقالات مسابقه و انتخاب سه مقام برتر استفاده ` +
    `می‌شود — پس منصفانه و با معیار بالا قضاوت کن.\n\n` +
    `عنوان مقاله: «${title}»\n\nمتن مقاله:\n${articleBody}\n\n` +
    `یک verdict از این سه مقدار انتخاب کن: "original" (به‌احتمال زیاد نوشته‌ی خودِ کاربر)، ` +
    `"suspicious" (نشانه‌های خفیف مشکوک هست ولی قطعی نیست)، یا "likely_ai_or_copied" ` +
    `(نشانه‌های قوی تولید توسط هوش مصنوعی یا کپی از جای دیگر). یک confidence بین ۰ تا ۱ ` +
    `بده (میزان اطمینانت به همین verdict). یک quality_score عدد صحیح بین ۰ تا ۱۰۰ بده ` +
    `(نمره‌ی کیفیت محتوا و نگارش، مستقل از اصالت). و یک notes خیلی کوتاه فارسی ` +
    `(حداکثر ۳۰ کلمه) بنویس که هم دلیل verdict و هم دلیل quality_score را برای مدیر ` +
    `خلاصه کند.`;

  const schema = {
    type: "OBJECT",
    properties: {
      verdict: { type: "STRING", enum: ["original", "suspicious", "likely_ai_or_copied"] },
      confidence: { type: "NUMBER" },
      quality_score: { type: "NUMBER" },
      notes: { type: "STRING" },
    },
    required: ["verdict", "confidence", "quality_score", "notes"],
  };

  const raw = await callModel(env, {
    systemInstruction: BASE_PERSONA,
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    jsonSchema: schema,
    temperature: 0.2,
  });

  try {
    const parsed = JSON.parse(raw);
    const verdict = ["original", "suspicious", "likely_ai_or_copied"].includes(parsed.verdict)
      ? parsed.verdict
      : "suspicious";
    const confidence = typeof parsed.confidence === "number"
      ? Math.max(0, Math.min(1, parsed.confidence))
      : 0.5;
    const qualityScore = typeof parsed.quality_score === "number"
      ? Math.max(0, Math.min(100, Math.round(parsed.quality_score)))
      : 50;
    return json({ verdict, confidence, quality_score: qualityScore, notes: String(parsed.notes ?? "").trim() });
  } catch {
    return json({ verdict: "suspicious", confidence: 0.5, quality_score: 50, notes: "پاسخ هوش مصنوعی قابل‌تفسیر نبود." });
  }
}

// -----------------------------------------------------------------------------
// ۶) نگارش گزارش شفافیت برای بخش «کمک‌های مالی» (کمکی برای مدیر)
// -----------------------------------------------------------------------------
async function handleDraftDonationReport(env: Env, body: Record<string, unknown>): Promise<Response> {
  const categoryLabel = String(body.categoryLabel ?? "عمومی هزارستان").trim();
  const rawNotes = String(body.rawNotes ?? "").trim();
  const existingTitle = String(body.title ?? "").trim();
  const amountSpent = body.amountSpent;
  const currency = String(body.currency ?? "USD").trim();
  const location = String(body.location ?? "").trim();
  const beneficiariesCount = body.beneficiariesCount;
  if (!rawNotes) return json({ error: "نکات/واقعیت‌های خام گزارش خالی است." }, 400);

  const facts: string[] = [`دسته‌بندی: ${categoryLabel}`];
  if (typeof amountSpent === "number") facts.push(`مبلغ مصرف‌شده: ${amountSpent} ${currency}`);
  if (location) facts.push(`محل: ${location}`);
  if (typeof beneficiariesCount === "number") facts.push(`تعداد خانواده‌ها/افراد کمک‌شده: ${beneficiariesCount}`);

  const prompt =
    `تو نویسنده‌ی «گزارش‌های شفافیت» بخش کمک‌های مالی هزاره‌نامه هستی. مدیر این پروژه ` +
    `نکات خام زیر را درباره‌ی نحوه‌ی مصرف واقعیِ بخشی از کمک‌های جمع‌آوری‌شده نوشته؛ کار تو ` +
    `این است که همین واقعیت‌ها را — بدون اضافه‌کردن هیچ رقم یا ادعای تازه‌ای که مدیر نگفته — ` +
    `به یک گزارش شفاف، گرم و قابل‌اعتماد فارسی/دری تبدیل کنی که حس امانت‌داری و صداقت را به ` +
    `کسانی که کمک کرده‌اند منتقل کند.\n\n` +
    `اطلاعات ثابت:\n${facts.join("\n")}\n\n` +
    `نکات خام مدیر:\n${rawNotes}\n\n` +
    (existingTitle ? `عنوان پیشنهادی مدیر: «${existingTitle}»\n\n` : "") +
    `سه چیز تولید کن: title (یک عنوان کوتاه و صادقانه فارسی، ${existingTitle ? "همان عنوان مدیر را کمی صیقل بده" : "خودت از روی نکات بساز"})، ` +
    `summary (یک جمله‌ی خیلی کوتاه برای کارت فهرست گزارش‌ها)، و body (گزارش کامل، ۴ تا ۸ جمله، ` +
    `لحن صمیمی و شفاف — دقیقاً بگو با این کمک چه‌کاری انجام شد، برای چه کسانی، و چرا این کار اهمیت ` +
    `دارد؛ هیچ رقم یا جزئیاتی که در نکات خام نبوده اختراع نکن).`;

  const schema = {
    type: "OBJECT",
    properties: {
      title: { type: "STRING" },
      summary: { type: "STRING" },
      body: { type: "STRING" },
    },
    required: ["title", "summary", "body"],
  };

  const raw = await callModel(env, {
    systemInstruction: BASE_PERSONA,
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    jsonSchema: schema,
    temperature: 0.5,
  });

  try {
    const parsed = JSON.parse(raw);
    return json({
      title: String(parsed.title ?? existingTitle).trim(),
      summary: String(parsed.summary ?? "").trim(),
      body: String(parsed.body ?? "").trim(),
    });
  } catch {
    return json({ error: "پاسخ هوش مصنوعی قابل‌تفسیر نبود." }, 502);
  }
}

// -----------------------------------------------------------------------------
// مسیریاب اصلی
// -----------------------------------------------------------------------------

export async function handleAi(env: Env, body: Record<string, unknown>): Promise<Response> {
  const task = String(body.task ?? "");
  try {
    switch (task) {
      case "chat": return await handleChat(env, body);
      case "search": return await handleSearch(env, body);
      case "recommend": return await handleRecommend(env, body);
      case "admin": return await handleAdmin(env, body);
      case "review_article": return await handleReviewArticle(env, body);
      case "draft_donation_report": return await handleDraftDonationReport(env, body);
      default: return json({ error: `task نامعتبر است: "${task}"` }, 400);
    }
  } catch (e) {
    console.error(e);
    return json({ error: e instanceof Error ? e.message : "خطای ناشناخته در سرویس هوش مصنوعی." }, 502);
  }
}
