// ایمیل‌های هزاره‌نامه از طریق Resend (https://resend.com).
// فقط وقتی فعال است که هر دو تنظیم شده باشند:
//   RESEND_API_KEY (Secret)  و  EMAIL_FROM (مثلاً «هزاره‌نامه <no-reply@hazaranama.org>»)
// و دامنه‌ی EMAIL_FROM در Resend تأیید شده باشد. در غیر این صورت اپ به روش
// قبلی (کد بازیابی از طریق مدیر) برمی‌گردد.
import type { Env } from "./types";

export function emailConfigured(env: Env): boolean {
  return Boolean(env.RESEND_API_KEY && env.EMAIL_FROM && env.EMAIL_FROM.includes("@"));
}

export async function sendEmail(env: Env, msg: { to: string; subject: string; html: string; text: string }): Promise<boolean> {
  if (!emailConfigured(env)) return false;
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: env.EMAIL_FROM, to: [msg.to], subject: msg.subject, html: msg.html, text: msg.text }),
    });
    if (!res.ok) console.error("resend", res.status, (await res.text()).slice(0, 300));
    return res.ok;
  } catch (e) {
    console.error("resend", e);
    return false;
  }
}

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);

/** قالب یکسان همه‌ی ایمیل‌ها — راست‌به‌چپ، رنگ‌های برند */
function layout(title: string, inner: string): string {
  return `<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(title)}</title></head>
<body style="margin:0;padding:0;background:#0d1226;font-family:Tahoma,'Segoe UI',Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0d1226;padding:28px 12px;">
<tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#161b33;border-radius:20px;overflow:hidden;border:1px solid #2c3559;">
<tr><td style="background:linear-gradient(135deg,#223a85,#5b93ff,#a06bff);padding:26px 24px;text-align:right;">
<div style="color:#ffffff;font-size:22px;font-weight:bold;">هزاره‌نامه</div>
<div style="color:#e6ecff;font-size:13px;margin-top:4px;">روایت زنده‌ی هویت ما</div>
</td></tr>
<tr><td style="padding:26px 24px;color:#f5f7ff;font-size:15px;line-height:1.9;text-align:right;direction:rtl;">${inner}</td></tr>
<tr><td style="padding:16px 24px 24px;color:#7d86b0;font-size:12px;line-height:1.8;text-align:right;border-top:1px solid #2c3559;">
این ایمیل خودکار از سوی اپلیکیشن هزاره‌نامه فرستاده شده است؛ لطفاً به آن پاسخ ندهید.
</td></tr>
</table></td></tr></table></body></html>`;
}

export function recoveryEmail(name: string, code: string, minutes: number) {
  const spaced = code.split("").join(" ");
  return {
    subject: `کد بازیابی رمز هزاره‌نامه: ${code}`,
    html: layout(
      "کد بازیابی رمز",
      `<p style="margin:0 0 12px;">سلام ${esc(name)}،</p>
<p style="margin:0 0 18px;">برای ساختن رمز تازه، این کد را در اپ هزاره‌نامه وارد کنید:</p>
<div style="text-align:center;margin:0 0 18px;"><span dir="ltr" style="display:inline-block;background:#0d1226;border:1px solid #5b93ff;border-radius:14px;padding:14px 22px;font-size:30px;letter-spacing:6px;font-weight:bold;color:#ffffff;font-family:Consolas,Menlo,monospace;">${spaced}</span></div>
<p style="margin:0 0 8px;color:#a9b3d6;font-size:13px;">این کد تا ${minutes} دقیقه معتبر است و فقط یک بار به کار می‌رود.</p>
<p style="margin:0;color:#a9b3d6;font-size:13px;">اگر شما درخواست نکرده‌اید، این ایمیل را نادیده بگیرید؛ رمز شما تغییری نمی‌کند.</p>`,
    ),
    text: `سلام ${name}،\nکد بازیابی رمز هزاره‌نامه: ${code}\nاین کد تا ${minutes} دقیقه معتبر است. اگر شما درخواست نکرده‌اید، این ایمیل را نادیده بگیرید.`,
  };
}

export function welcomeEmail(name: string) {
  return {
    subject: "به هزاره‌نامه خوش آمدید",
    html: layout(
      "خوش آمدید",
      `<p style="margin:0 0 12px;">سلام ${esc(name)}، خوش آمدید!</p>
<p style="margin:0 0 12px;">حساب شما در هزاره‌نامه ساخته شد. از این پس می‌توانید تاریخ، فرهنگ و زبان هزاره‌ها را بخوانید، واژه‌نامه‌ی هزارگی را جست‌وجو کنید و روایت‌ها و خاطره‌های خود را در «حافظه‌ی جمعی» با دیگران در میان بگذارید.</p>
<p style="margin:0;color:#a9b3d6;font-size:13px;">اگر روزی رمزتان را فراموش کردید، از صفحه‌ی ورود «رمز عبور را فراموش کرده‌اید؟» را بزنید تا کد بازیابی به همین ایمیل فرستاده شود.</p>`,
    ),
    text: `سلام ${name}، به هزاره‌نامه خوش آمدید! حساب شما ساخته شد.`,
  };
}

export function passwordChangedEmail(name: string) {
  return {
    subject: "رمز حساب هزاره‌نامه تغییر کرد",
    html: layout(
      "رمز تغییر کرد",
      `<p style="margin:0 0 12px;">سلام ${esc(name)}،</p>
<p style="margin:0 0 12px;">رمز عبور حساب هزاره‌نامه‌ی شما همین حالا تغییر کرد و از همه‌ی دستگاه‌های دیگر خارج شدید.</p>
<p style="margin:0;color:#ffb3c0;font-size:13px;">اگر این کار را شما انجام نداده‌اید، فوراً از صفحه‌ی ورود رمز را بازیابی کنید یا از بخش «تماس با ما» به مدیر خبر دهید.</p>`,
    ),
    text: `سلام ${name}، رمز حساب هزاره‌نامه‌ی شما تغییر کرد. اگر شما نبودید، فوراً رمز را بازیابی کنید.`,
  };
}
