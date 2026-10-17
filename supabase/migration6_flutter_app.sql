-- ============================================================================
-- Hosil X, 6-migratsiya: Flutter ilova uchun QO'SHIMCHALAR (additive).
-- Talab: schema.sql va migration2..5 allaqachon ishga tushirilgan.
-- Jadvallar o'chirilmaydi, ma'lumotlar yo'qolmaydi. Rolning nomi 'warehouse_owner' saqlanadi
-- (sayt va bot shunga tayanadi; ilovada 'warehouse_provider' sifatida ko'rsatiladi).
-- ============================================================================

-- 1) KATEGORIYALAR (admin boshqaradi) --------------------------------------
create table if not exists public.product_categories (
  slug text primary key check (slug ~ '^[a-z0-9_]+$'),
  name_uz text not null, name_ru text not null, name_en text not null,
  icon text, sort_order int not null default 0, active boolean not null default true,
  created_at timestamptz not null default now()
);
insert into public.product_categories (slug, name_uz, name_ru, name_en, icon, sort_order) values
  ('fruit','Mevalar','Фрукты','Fruit','🍎',1), ('vegetable','Sabzavotlar','Овощи','Vegetables','🥕',2),
  ('grain','Don','Зерно','Grain','🌾',3), ('dairy','Sut mahsulotlari','Молочные продукты','Dairy','🥛',4),
  ('other','Boshqa','Другое','Other','📦',5)
on conflict do nothing;
-- Qat'iy 5 ta qiymatli CHECK o'rniga kategoriyalar jadvaliga FK (o'chirish taqiqlangan: faqat faolsizlantiriladi)
alter table public.products drop constraint if exists products_category_check;
alter table public.products drop constraint if exists products_category_fk;
alter table public.products add constraint products_category_fk
  foreign key (category) references public.product_categories(slug) on update cascade on delete restrict;
alter table public.product_categories enable row level security;
create policy "kategoriya: hamma ko'radi" on public.product_categories for select using (active or public.is_admin());
create policy "kategoriya: admin" on public.product_categories for all using (public.is_admin()) with check (public.is_admin());

-- 2) MODERATSIYA (sukut bo'yicha O'CHIQ: mavjud xatti-harakat o'zgarmaydi) ---
alter table public.products add column if not exists moderation_status text not null default 'approved'
  check (moderation_status in ('pending','approved','rejected'));
alter table public.products add column if not exists moderation_note text;
alter table public.products add column if not exists updated_at timestamptz not null default now();
insert into public.site_settings (key, value) values ('require_moderation','false') on conflict do nothing;

create or replace function public.products_before_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if not public.is_admin()
       and coalesce((select value from site_settings where key = 'require_moderation'), 'false') = 'true' then
      new.moderation_status := 'pending';
    end if;
  else
    new.updated_at := now();
    if not public.is_admin() then   -- sotuvchi moderatsiya maydonlarini o'zgartira olmaydi
      new.moderation_status := old.moderation_status;
      new.moderation_note := old.moderation_note;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists products_bw on public.products;
create trigger products_bw before insert or update on public.products
  for each row execute function public.products_before_write();

drop policy if exists "mahsulot: faol hammaga" on public.products;
create policy "mahsulot: ko'rish" on public.products for select
  using ((status = 'active' and moderation_status = 'approved') or seller_id = auth.uid() or public.is_admin());

-- 3) MAHSULOT RASMLARI (galereya) ------------------------------------------
create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  url text not null, sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists product_images_product_idx on public.product_images (product_id, sort_order);
alter table public.product_images enable row level security;
create policy "rasm: mahsulot ko'rinsa ko'rinadi" on public.product_images for select
  using (exists (select 1 from public.products p where p.id = product_id));
create policy "rasm: egasi yoki admin" on public.product_images for all
  using (exists (select 1 from public.products p where p.id = product_id and (p.seller_id = auth.uid() or public.is_admin())))
  with check (exists (select 1 from public.products p where p.id = product_id and (p.seller_id = auth.uid() or public.is_admin())));

-- 4) BANNERLAR (bosh ekran) -------------------------------------------------
create table if not exists public.banners (
  id uuid primary key default gen_random_uuid(),
  title text not null, subtitle text, image_url text not null,
  link_type text not null default 'none' check (link_type in ('none','product','category','url')),
  link_value text, sort_order int not null default 0, active boolean not null default true,
  starts_at timestamptz, ends_at timestamptz, created_at timestamptz not null default now()
);
alter table public.banners enable row level security;
create policy "banner: faol ko'rinadi" on public.banners for select
  using ((active and (starts_at is null or starts_at <= now()) and (ends_at is null or ends_at > now())) or public.is_admin());
create policy "banner: admin" on public.banners for all using (public.is_admin()) with check (public.is_admin());
-- Reklama kampaniyalari uchun mavjud public.ads jadvali ishlatiladi (migration5).

-- 5) BILDIRISHNOMALAR (kalit saqlanadi, matn ilovada tarjima qilinadi) -------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null, title text not null, body text,
  data jsonb not null default '{}'::jsonb, read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications (user_id, read, created_at desc);
alter table public.notifications enable row level security;
create policy "bildirishnoma: o'zi ko'radi" on public.notifications for select using (user_id = auth.uid());
create policy "bildirishnoma: o'zi o'chiradi" on public.notifications for delete using (user_id = auth.uid());
-- INSERT/UPDATE siyosati yo'q: faqat quyidagi ishonchli funksiyalar orqali.

create or replace function public.notify(p_user uuid, p_type text, p_title text, p_body text, p_data jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into notifications (user_id, type, title, body, data) values (p_user, p_type, p_title, p_body, p_data);
$$;
revoke all on function public.notify(uuid, text, text, text, jsonb) from public, anon, authenticated;

create or replace function public.mark_notifications_read() returns void
language sql security definer set search_path = public as $$
  update notifications set read = true where user_id = auth.uid() and read = false;
$$;
revoke all on function public.mark_notifications_read() from public, anon;
grant execute on function public.mark_notifications_read() to authenticated;

create or replace function public.trg_inquiry_notify() returns trigger
language plpgsql security definer set search_path = public as $$
declare s uuid; t text;
begin
  select seller_id, title into s, t from products where id = new.product_id;
  if s is not null then
    perform notify(s, 'inquiry', 'new_inquiry', t, jsonb_build_object('inquiry_id', new.id, 'product_id', new.product_id));
  end if;
  return new;
end $$;
drop trigger if exists inquiry_notify on public.inquiries;
create trigger inquiry_notify after insert on public.inquiries for each row execute function public.trg_inquiry_notify();

create or replace function public.trg_moderation_notify() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.moderation_status is distinct from old.moderation_status and new.moderation_status in ('approved','rejected') then
    perform notify(new.seller_id, 'moderation', 'product_' || new.moderation_status, new.title,
                   jsonb_build_object('product_id', new.id, 'note', new.moderation_note));
  end if;
  return new;
end $$;
drop trigger if exists moderation_notify on public.products;
create trigger moderation_notify after update of moderation_status on public.products
  for each row execute function public.trg_moderation_notify();

-- 6) AUDIT JURNALI (faqat admin o'qiydi; yozish faqat ishonchli funksiyalar orqali) ---
create table if not exists public.audit_logs (
  id bigserial primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null, entity text not null, entity_id text,
  details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
alter table public.audit_logs enable row level security;
create policy "audit: admin o'qiydi" on public.audit_logs for select using (public.is_admin());
revoke insert, update, delete on public.audit_logs from anon, authenticated;

-- 7) ADMIN AMALLARI (ishonchli funksiyalar) -----------------------------------
create or replace function public.admin_set_role(target uuid, new_role text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if new_role not in ('farmer','buyer','warehouse_owner','admin') then raise exception 'bad role'; end if;
  if target = auth.uid() and new_role <> 'admin' then raise exception 'cannot demote yourself'; end if;
  update profiles set role = new_role where id = target;
  insert into audit_logs (actor_id, action, entity, entity_id, details)
    values (auth.uid(), 'set_role', 'profile', target::text, jsonb_build_object('role', new_role));
end $$;

create or replace function public.moderate_product(p_id uuid, decision text, note text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  if decision not in ('approved','rejected') then raise exception 'bad decision'; end if;
  update products set moderation_status = decision, moderation_note = note where id = p_id;
  insert into audit_logs (actor_id, action, entity, entity_id, details)
    values (auth.uid(), 'moderate_product', 'product', p_id::text, jsonb_build_object('decision', decision, 'note', note));
end $$;

create or replace function public.admin_stats() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return jsonb_build_object(
    'users', (select count(*) from profiles),
    'products', (select count(*) from products),
    'pending_products', (select count(*) from products where moderation_status = 'pending'),
    'active_banners', (select count(*) from banners where active and (ends_at is null or ends_at > now())),
    'active_ads', (select count(*) from ads where active and (ends_at is null or ends_at > now())),
    'open_reports', (select count(*) from reports where not resolved));
end $$;

revoke all on function public.admin_set_role(uuid, text), public.moderate_product(uuid, text, text), public.admin_stats() from public, anon;
grant execute on function public.admin_set_role(uuid, text), public.moderate_product(uuid, text, text), public.admin_stats() to authenticated;

-- 8) STORAGE: serverda ham hajm va tur cheklovi ---------------------------------
update storage.buckets set file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'] where id = 'images';
