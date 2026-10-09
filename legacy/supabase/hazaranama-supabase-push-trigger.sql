-- =============================================================================
-- هزاره‌نامه — اتصال مستقیم جدول notifications به تابع send-push با pg_net
-- =============================================================================
-- چون schema داخلی «supabase_functions» (که ویژگی Database Webhooks داشبورد
-- به آن نیاز دارد) در این پروژه وجود نداشت، به‌جای آن مستقیماً از پسوند
-- pg_net (که در این پروژه فعال شد) برای صدا زدن Edge Function استفاده می‌کنیم.
-- نتیجه دقیقاً همان است: هر بار یک ردیف تازه در notifications ساخته شود،
-- بلافاصله (و به‌صورت async/غیرمسدودکننده) تابع send-push صدا زده می‌شود.
-- =============================================================================

create or replace function public.trigger_send_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform net.http_post(
    url := 'https://kyvkqbdigezzywfarhtj.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', 'REPLACE_WITH_YOUR_WEBHOOK_SECRET' -- همان مقداری که به‌عنوان Edge Function secret ذخیره کرده‌اید؛ اینجا فقط برای گیت‌هاب حذف شد
    ),
    body := jsonb_build_object('record', to_jsonb(NEW))
  );
  return NEW;
end;
$$;

drop trigger if exists notifications_send_push on public.notifications;

create trigger notifications_send_push
after insert on public.notifications
for each row execute function public.trigger_send_push();
