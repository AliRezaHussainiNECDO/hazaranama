export interface Env {
  DB: D1Database;
  MEDIA: R2Bucket;
  AI: Ai;
  JWT_SECRET: string;
  ADMIN_EMAIL: string;
  MIGRATION_KEY?: string;
  FCM_SERVICE_ACCOUNT?: string;
  RESEND_API_KEY?: string; // Secret — کلید Resend برای ایمیل
  EMAIL_FROM?: string; // مثلاً «هزاره‌نامه <no-reply@hazaranama.org>» (دامنه در Resend تأییدشده)
  AI_MODEL?: string;
  SUPABASE_URL?: string;
}
export type Ctx = ExecutionContext;
