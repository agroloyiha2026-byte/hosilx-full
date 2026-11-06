-- 13-migratsiya: agroapteka, texnika ijarasi, logistika va dala daftari. ADDITIVE: mavjud jadvallarga tegmaydi.
-- Production'da AVTOMATIK qo'llanmaydi: SQL Editor'da qo'lda, avval zaxira nusxa bilan.
-- Talab: schema.sql (profiles, is_admin), migration6 (notifications, notify()).
-- E'lonlar sukut bo'yicha darhol ko'rinadi (moderation_status = 'approved'); admin keyin 'rejected' qilib yashira oladi.
-- DIQQAT: ilova va sayt bu jadvallar uchun hali ekran yozilmagan: ma'lumot bot va Supabase'da turadi, bazada umumiy.

-- ======================= AGROAPTEKA =======================
create table if not exists public.pharmacies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 120),
  description text check (description is null or char_length(description) <= 600),
  region text not null, district text, address text check (address is null or char_length(address) <= 160),
  phone text, work_hours text check (work_hours is null or char_length(work_hours) <= 80),
  status text not null default 'active' check (status in ('active','hidden')),
  moderation_status text not null default 'approved' check (moderation_status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);
create table if not exists public.pharmacy_items (
  id uuid primary key default gen_random_uuid(),
  pharmacy_id uuid not null references public.pharmacies(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 120),
  category text not null check (category in ('seed','seedling','fertilizer','pesticide','other')),
  price numeric(14,2) check (price is null or price >= 0),
  currency text not null default 'UZS' check (currency in ('UZS','USD')),
  unit text check (unit is null or char_length(unit) <= 20),
  in_stock boolean not null default true,
  usage_note text check (usage_note is null or char_length(usage_note) <= 300),   -- sotuvchi kiritgan, TEKSHIRILMAGAN ma'lumot
  status text not null default 'active' check (status in ('active','hidden')),
  created_at timestamptz not null default now()
);

-- ======================= TEXNIKA IJARASI =======================
create table if not exists public.machinery_listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('tractor','combine','seeder','sprayer','other')),
  title text not null check (char_length(title) between 2 and 120),
  description text check (description is null or char_length(description) <= 600),
  region text not null, district text check (district is null or char_length(district) <= 80),
  price numeric(14,2) not null check (price > 0),
  currency text not null default 'UZS' check (currency in ('UZS','USD')),
  price_unit text not null check (price_unit in ('hour','day','month')),
  with_operator boolean not null default false, delivery boolean not null default false, phone text,
  status text not null default 'active' check (status in ('active','hidden')),
  moderation_status text not null default 'approved' check (moderation_status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);

-- ======================= LOGISTIKA =======================
create table if not exists public.freight_listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  vehicle_type text not null check (vehicle_type in ('truck','refrigerator','pickup','trailer','other')),
  title text not null check (char_length(title) between 2 and 120),
  capacity_tons numeric(8,2) not null check (capacity_tons > 0),
  from_region text not null, to_region text,
  price numeric(14,2) check (price is null or price >= 0),
  currency text not null default 'UZS' check (currency in ('UZS','USD')),
  price_unit text not null default 'negotiable' check (price_unit in ('km','ton','trip','negotiable')),
  return_trip boolean not null default false, shared_load boolean not null default false, phone text,
  description text check (description is null or char_length(description) <= 600),
  status text not null default 'active' check (status in ('active','hidden')),
  moderation_status text not null default 'approved' check (moderation_status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);

-- ======================= SO'ROVLAR VA SHIKOYATLAR (umumiy) =======================
create table if not exists public.service_requests (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('pharmacy_item','machinery','freight')),
  target_id uuid not null,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  message text check (message is null or char_length(message) <= 500),
  details jsonb not null default '{}'::jsonb,
  status text not null default 'new' check (status in ('new','accepted','rejected','done')),
  created_at timestamptz not null default now(),
  check (requester_id <> owner_id)
);
create table if not exists public.service_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_kind text not null check (target_kind in ('pharmacy','pharmacy_item','machinery','freight')),
  target_id uuid not null,
  reason text not null check (char_length(reason) <= 500),
  created_at timestamptz not null default now()
);

-- ======================= DALA DAFTARI =======================
create table if not exists public.farm_fields (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  area_ha numeric(10,2) check (area_ha is null or area_ha > 0),
  crop text check (crop is null or char_length(crop) <= 60),
  sown_on date,
  created_at timestamptz not null default now()
);
create table if not exists public.field_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  field_id uuid not null references public.farm_fields(id) on delete cascade,
  kind text not null check (kind in ('sowing','irrigation','fertilizing','treatment','labor','harvest','expense','observation')),
  entry_date date not null,
  amount numeric(14,2) check (amount is null or amount >= 0),
  unit text check (unit is null or unit in ('kg','t','l','m3','ha')),
  cost numeric(14,2) check (cost is null or cost >= 0),
  currency text not null default 'UZS' check (currency in ('UZS','USD')),
  note text check (note is null or char_length(note) <= 500),
  client_ref text,
  created_at timestamptz not null default now()
);
create unique index if not exists field_entries_client_ref_uidx on public.field_entries (user_id, client_ref);   -- takroriy yozuvdan himoya

create index if not exists pharmacies_list_idx on public.pharmacies (status, moderation_status, region);
create index if not exists pharmacy_items_store_idx on public.pharmacy_items (pharmacy_id, status);
create index if not exists machinery_list_idx on public.machinery_listings (status, moderation_status, region, kind);
create index if not exists freight_list_idx on public.freight_listings (status, moderation_status, from_region);
create index if not exists service_requests_owner_idx on public.service_requests (owner_id, status, created_at desc);
create index if not exists field_entries_field_idx on public.field_entries (field_id, entry_date desc);

-- ======================= RLS =======================
do $$
declare t text;
begin
  foreach t in array array['pharmacies','machinery_listings','freight_listings'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_public_read', t);
    execute format('create policy %I on public.%I for select using (status = ''active'' and moderation_status = ''approved'')', t || '_public_read', t);
    execute format('drop policy if exists %I on public.%I', t || '_owner_all', t);
    execute format('create policy %I on public.%I for all using (owner_id = auth.uid()) with check (owner_id = auth.uid())', t || '_owner_all', t);
    execute format('drop policy if exists %I on public.%I', t || '_admin_all', t);
    execute format('create policy %I on public.%I for all using (public.is_admin()) with check (public.is_admin())', t || '_admin_all', t);
  end loop;
  foreach t in array array['farm_fields','field_entries'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_owner_all', t);
    execute format('create policy %I on public.%I for all using (user_id = auth.uid()) with check (user_id = auth.uid())', t || '_owner_all', t);
  end loop;
end $$;

alter table public.pharmacy_items enable row level security;
drop policy if exists pharmacy_items_public_read on public.pharmacy_items;
create policy pharmacy_items_public_read on public.pharmacy_items for select using (
  status = 'active' and exists (select 1 from public.pharmacies p where p.id = pharmacy_id and p.status = 'active' and p.moderation_status = 'approved'));
drop policy if exists pharmacy_items_owner_all on public.pharmacy_items;
create policy pharmacy_items_owner_all on public.pharmacy_items for all using (owner_id = auth.uid())
  with check (owner_id = auth.uid() and exists (select 1 from public.pharmacies p where p.id = pharmacy_id and p.owner_id = auth.uid()));
drop policy if exists pharmacy_items_admin_all on public.pharmacy_items;
create policy pharmacy_items_admin_all on public.pharmacy_items for all using (public.is_admin()) with check (public.is_admin());

alter table public.service_requests enable row level security;
drop policy if exists service_requests_read on public.service_requests;
create policy service_requests_read on public.service_requests for select using (requester_id = auth.uid() or owner_id = auth.uid() or public.is_admin());
drop policy if exists service_requests_insert on public.service_requests;
create policy service_requests_insert on public.service_requests for insert with check (requester_id = auth.uid() and status = 'new' and owner_id <> auth.uid());
drop policy if exists service_requests_owner_update on public.service_requests;
create policy service_requests_owner_update on public.service_requests for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

alter table public.service_reports enable row level security;
drop policy if exists service_reports_insert on public.service_reports;
create policy service_reports_insert on public.service_reports for insert with check (reporter_id = auth.uid());
drop policy if exists service_reports_admin_read on public.service_reports;
create policy service_reports_admin_read on public.service_reports for select using (public.is_admin());

-- So'rov egasi faqat HOLATni o'zgartira oladi (boshqa ustunlarni emas)
create or replace function public.service_requests_guard() returns trigger language plpgsql as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    if (new.kind, new.target_id, new.requester_id, new.owner_id, new.message, new.details, new.created_at)
       is distinct from (old.kind, old.target_id, old.requester_id, old.owner_id, old.message, old.details, old.created_at) then
      raise exception 'faqat holatni o''zgartirish mumkin';
    end if;
    if new.status not in ('accepted','rejected','done') then raise exception 'noto''g''ri holat'; end if;
  end if;
  return new;
end $$;
drop trigger if exists service_requests_guard on public.service_requests;
create trigger service_requests_guard before update on public.service_requests for each row execute function public.service_requests_guard();

-- Bildirishnomalar (ilova ichida va Telegramda ko'rinadi): yangi so'rov -> egasiga, holat o'zgarsa -> so'rovchiga
create or replace function public.trg_service_request_notify() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform notify(new.owner_id, 'service', 'new_service_request', left(coalesce(new.message, ''), 200), jsonb_build_object('request_id', new.id, 'kind', new.kind));
  elsif new.status is distinct from old.status then
    perform notify(new.requester_id, 'service', 'service_request_' || new.status, '', jsonb_build_object('request_id', new.id, 'kind', new.kind));
  end if;
  return new;
end $$;
drop trigger if exists service_requests_notify on public.service_requests;
create trigger service_requests_notify after insert or update of status on public.service_requests for each row execute function public.trg_service_request_notify();
