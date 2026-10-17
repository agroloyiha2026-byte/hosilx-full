-- 8-migratsiya: admin kontent o'zgarishlarini audit jurnaliga avtomatik yozish.
-- Talab: migration6 (audit_logs jadvali). Faqat adminning o'zgarishlari yoziladi; oddiy foydalanuvchilar (masalan shikoyat yuboruvchi) jurnalga tegmaydi.
create or replace function public.audit_row_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare payload jsonb; rid text;
begin
  if not public.is_admin() then return null; end if;
  payload := case tg_op when 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  rid := coalesce(payload->>'id', payload->>'slug', payload->>'key');
  insert into audit_logs (actor_id, action, entity, entity_id, details)
    values (auth.uid(), lower(tg_op), tg_table_name, rid, jsonb_build_object('row', payload));
  return null;
end $$;

do $$
declare t text;
begin
  foreach t in array array['banners','ads','product_categories','site_settings','reports'] loop
    execute format('drop trigger if exists audit_%1$s on public.%1$I', t);
    execute format('create trigger audit_%1$s after insert or update or delete on public.%1$I for each row execute function public.audit_row_change()', t);
  end loop;
end $$;
