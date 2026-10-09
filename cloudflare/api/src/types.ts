export interface Env {
  DB: D1Database;
  MEDIA: R2Bucket;
  AI: Ai;
  JWT_SECRET: string;
  ADMIN_EMAIL: string;
  MIGRATION_KEY?: string;
  FCM_SERVICE_ACCOUNT?: string;
  AI_MODEL?: string;
  SUPABASE_URL?: string;
}
export type Ctx = ExecutionContext;
