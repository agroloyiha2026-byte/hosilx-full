-- 7-migratsiya: sotuvchining ochiq ma'lumoti (ism, hudud). Profillar yopiq qoladi.
-- Talab: migration6 (moderation_status ustuni). Faqat ko'rinadigan e'loni bor sotuvchi uchun natija qaytaradi.
create or replace function public.seller_public(p_seller uuid)
returns table (full_name text, region text)
language sql stable security definer set search_path = public as $$
  select pr.full_name, pr.region from profiles pr
  where pr.id = p_seller
    and exists (select 1 from products p where p.seller_id = pr.id and p.status = 'active' and p.moderation_status = 'approved');
$$;
revoke all on function public.seller_public(uuid) from public;
grant execute on function public.seller_public(uuid) to anon, authenticated;
