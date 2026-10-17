-- ============================================================================
-- Stage 7: RLS va xavfsizlik sinovi. BUTUN faylni Supabase SQL Editor'da bir marta ishga tushiring.
-- Fayl oxirida ATAYLAB xato chiqaradi: bu natijalar xabari, shu sabab hamma o'zgarish avtomatik bekor qilinadi
-- (ma'lumotlaringizga hech narsa yozilmaydi). Xabarda har bir sinov uchun PASS yoki FAIL ko'rinadi.
-- Talab: migration6, migration7, migration8 ishga tushirilgan; bazada kamida 1 ta oddiy foydalanuvchi va 1 ta admin profili bor.
-- ============================================================================
do $$
declare
  uid uuid; adm uuid; pid uuid; before_m text; after_m text; n int; r jsonb;
  res jsonb := '[]'::jsonb; summary text; fails int;
begin
  select id into uid from profiles where role <> 'admin' order by created_at limit 1;
  select id into adm from profiles where role = 'admin' order by created_at limit 1;
  if uid is null or adm is null then raise exception 'Sinov uchun oddiy foydalanuvchi va admin kerak (profiles jadvali)'; end if;

  -- ================= ODDIY FOYDALANUVCHI =================
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', uid::text, true);
  execute 'set local role authenticated';

  select count(*) into n from profiles where id <> uid;
  res := res || jsonb_build_object('t', 'boshqalar profilini ko''ra olmaydi', 'ok', n = 0, 'd', 'qatorlar: ' || n);

  select count(*) into n from audit_logs;
  res := res || jsonb_build_object('t', 'audit jurnalini o''qiy olmaydi', 'ok', n = 0, 'd', 'qatorlar: ' || n);

  begin insert into audit_logs (action, entity) values ('x', 'y');
    res := res || jsonb_build_object('t', 'audit jurnaliga yoza olmaydi', 'ok', false);
  exception when others then res := res || jsonb_build_object('t', 'audit jurnaliga yoza olmaydi', 'ok', true, 'd', sqlerrm); end;

  begin insert into banners (title, image_url) values ('x', 'y');
    res := res || jsonb_build_object('t', 'banner qo''sha olmaydi', 'ok', false);
  exception when others then res := res || jsonb_build_object('t', 'banner qo''sha olmaydi', 'ok', true, 'd', sqlerrm); end;

  begin insert into product_categories (slug, name_uz, name_ru, name_en) values ('hack', 'x', 'x', 'x');
    res := res || jsonb_build_object('t', 'kategoriya qo''sha olmaydi', 'ok', false);
  exception when others then res := res || jsonb_build_object('t', 'kategoriya qo''sha olmaydi', 'ok', true, 'd', sqlerrm); end;

  update products set title = title where seller_id <> uid;
  get diagnostics n = row_count;
  res := res || jsonb_build_object('t', 'birovning mahsulotini o''zgartira olmaydi', 'ok', n = 0, 'd', 'o''zgargan qatorlar: ' || n);

  begin perform admin_stats();
    res := res || jsonb_build_object('t', 'admin_stats chaqira olmaydi', 'ok', false);
  exception when others then res := res || jsonb_build_object('t', 'admin_stats chaqira olmaydi', 'ok', true, 'd', sqlerrm); end;

  begin perform admin_set_role(uid, 'admin');
    res := res || jsonb_build_object('t', 'admin_set_role chaqira olmaydi', 'ok', false);
  exception when others then res := res || jsonb_build_object('t', 'admin_set_role chaqira olmaydi', 'ok', true, 'd', sqlerrm); end;

  begin perform notify(uid, 'x', 'y', null);
    res := res || jsonb_build_object('t', 'notify() ni chaqira olmaydi', 'ok', false);
  exception when others then res := res || jsonb_build_object('t', 'notify() ni chaqira olmaydi', 'ok', true, 'd', sqlerrm); end;

  begin insert into notifications (user_id, type, title) values (uid, 'x', 'y');
    res := res || jsonb_build_object('t', 'bildirishnoma yarata olmaydi', 'ok', false);
  exception when others then res := res || jsonb_build_object('t', 'bildirishnoma yarata olmaydi', 'ok', true, 'd', sqlerrm); end;

  select id, moderation_status into pid, before_m from products where seller_id = uid limit 1;
  if pid is null then
    res := res || jsonb_build_object('t', 'moderatsiya maydonini o''zgartira olmaydi', 'ok', true, 'd', 'o''tkazib yuborildi: foydalanuvchida mahsulot yo''q');
  else
    update products set moderation_status = case when before_m = 'pending' then 'approved' else 'pending' end where id = pid;
    select moderation_status into after_m from products where id = pid;
    res := res || jsonb_build_object('t', 'moderatsiya maydonini o''zgartira olmaydi', 'ok', after_m = before_m, 'd', before_m || ' -> ' || after_m);
  end if;

  begin update profiles set role = 'admin' where id = uid;
    res := res || jsonb_build_object('t', 'o''zini admin qila olmaydi', 'ok', false);
  exception when others then res := res || jsonb_build_object('t', 'o''zini admin qila olmaydi', 'ok', true, 'd', sqlerrm); end;

  -- ================= ADMIN =================
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', adm::text, true);
  execute 'set local role authenticated';

  begin select admin_stats() into r;
    res := res || jsonb_build_object('t', 'admin statistikani oladi', 'ok', r ? 'users', 'd', r::text);
  exception when others then res := res || jsonb_build_object('t', 'admin statistikani oladi', 'ok', false, 'd', sqlerrm); end;

  begin perform admin_set_role(adm, 'farmer');
    res := res || jsonb_build_object('t', 'admin o''zini pasaytira olmaydi', 'ok', false);
  exception when others then res := res || jsonb_build_object('t', 'admin o''zini pasaytira olmaydi', 'ok', true, 'd', sqlerrm); end;

  begin insert into audit_logs (action, entity) values ('x', 'y');
    res := res || jsonb_build_object('t', 'admin ham jurnalga qo''lda yoza olmaydi', 'ok', false);
  exception when others then res := res || jsonb_build_object('t', 'admin ham jurnalga qo''lda yoza olmaydi', 'ok', true, 'd', sqlerrm); end;

  -- ================= ANON (kirmagan) =================
  execute 'reset role';
  perform set_config('request.jwt.claims', '{}', true);
  perform set_config('request.jwt.claim.sub', '', true);
  execute 'set local role anon';

  begin select count(*) into n from profiles;
    res := res || jsonb_build_object('t', 'anon profillarni ko''ra olmaydi', 'ok', n = 0, 'd', 'qatorlar: ' || n);
  exception when others then res := res || jsonb_build_object('t', 'anon profillarni ko''ra olmaydi', 'ok', true, 'd', sqlerrm); end;

  begin select count(*) into n from notifications;
    res := res || jsonb_build_object('t', 'anon bildirishnomalarni ko''ra olmaydi', 'ok', n = 0, 'd', 'qatorlar: ' || n);
  exception when others then res := res || jsonb_build_object('t', 'anon bildirishnomalarni ko''ra olmaydi', 'ok', true, 'd', sqlerrm); end;

  begin perform admin_stats();
    res := res || jsonb_build_object('t', 'anon admin_stats chaqira olmaydi', 'ok', false);
  exception when others then res := res || jsonb_build_object('t', 'anon admin_stats chaqira olmaydi', 'ok', true, 'd', sqlerrm); end;

  execute 'reset role';
  select string_agg(case when (e->>'ok')::boolean then 'PASS  ' else 'FAIL  ' end || (e->>'t') || coalesce('   [' || (e->>'d') || ']', ''), E'\n'),
         count(*) filter (where not (e->>'ok')::boolean)
    into summary, fails from jsonb_array_elements(res) e;
  raise exception E'SINOV NATIJALARI (FAIL soni: %). Bu xato kutilgan: hamma o''zgarish bekor qilindi.\n\n%', fails, summary;
end $$;
