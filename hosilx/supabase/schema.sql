-- HOSIL X — Supabase sxemasi (web, bot va mobil uchun umumiy)
-- Supabase SQL Editor'da ishga tushiring.

create extension if not exists "pgcrypto";

-- ---------- PROFILLAR ----------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text,
  role text not null default 'farmer' check (role in ('farmer','buyer','warehouse_owner','admin')),
  language text not null default 'uz' check (language in ('uz','ru','en')),
  theme text not null default 'system' check (theme in ('light','dark','system')),
  telegram_id bigint unique,
  region text,
  onboarded boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

-- Yangi foydalanuvchi uchun profil (admin roli o'zi tanlanmaydi)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare r text := coalesce(new.raw_user_meta_data->>'role','farmer');
begin
  if r not in ('farmer','buyer','warehouse_owner') then r := 'farmer'; end if;
  insert into profiles (id, full_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), r);
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

-- Foydalanuvchi o'z rolini admin qilib qo'ymasligi uchun
create or replace function public.protect_role() returns trigger
language plpgsql as $$
begin
  if new.role <> old.role and not public.is_admin() then
    raise exception 'Rolni o''zgartirish taqiqlangan';
  end if;
  return new;
end $$;
create trigger profiles_protect_role before update on public.profiles
for each row execute function public.protect_role();

-- ---------- MAHSULOTLAR ----------
create table public.products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  category text not null check (category in ('fruit','vegetable','grain','dairy','other')),
  product_type text not null,                 -- masalan: "pomidor"
  price numeric(14,2) not null check (price > 0),
  currency text not null default 'UZS' check (currency in ('UZS','USD')),
  unit text not null check (unit in ('kg','tonna','dona','litr')),
  quantity numeric(14,2) not null check (quantity >= 0),
  region text not null,
  description text,
  image_url text,
  status text not null default 'active' check (status in ('active','sold','hidden')),
  created_at timestamptz not null default now()
);
create index on products (status, category, region);
create index on products (product_type, unit, region);

-- ---------- OMBORLAR ----------
create table public.warehouses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  name text not null,
  region text not null,
  address text,
  storage_type text not null check (storage_type in ('cold','dry','vegetable','grain','other')),
  capacity_tons numeric(12,2) not null check (capacity_tons > 0),
  free_tons numeric(12,2) not null check (free_tons >= 0),
  price_per_ton_month numeric(14,2),
  currency text not null default 'UZS',
  accepted_products text[] not null default '{}',
  conditions text,
  contact_phone text,
  image_url text,
  status text not null default 'active' check (status in ('active','hidden')),
  created_at timestamptz not null default now(),
  check (free_tons <= capacity_tons)
);

create table public.storage_requests (
  id uuid primary key default gen_random_uuid(),
  warehouse_id uuid not null references warehouses(id) on delete cascade,
  farmer_id uuid not null references profiles(id) on delete cascade,
  product_type text not null,
  quantity_tons numeric(12,2) not null check (quantity_tons > 0),
  message text,
  status text not null default 'new' check (status in ('new','accepted','rejected')),
  created_at timestamptz not null default now()
);

-- ---------- SO'ROVLAR (xaridor -> sotuvchi) ----------
create table public.inquiries (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  buyer_id uuid not null references profiles(id) on delete cascade,
  offered_price numeric(14,2),
  quantity numeric(14,2),
  message text,
  status text not null default 'new' check (status in ('new','accepted','rejected','closed')),
  created_at timestamptz not null default now()
);

create table public.saved_products (
  user_id uuid references profiles(id) on delete cascade,
  product_id uuid references products(id) on delete cascade,
  primary key (user_id, product_id)
);

-- ---------- VAZIFALAR ----------
create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  description text,
  due_at timestamptz not null,
  done boolean not null default false,
  reminded boolean not null default false,   -- bot eslatma yuborganini belgilaydi
  created_at timestamptz not null default now()
);
create index on tasks (user_id, due_at);
create index on tasks (reminded, done, due_at);

-- ---------- MOLIYA ----------
create table public.finance_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  kind text not null check (kind in ('income','expense')),
  category text not null check (category in
    ('sales','seeds','fertilizer','labor','transport','storage','other')),
  amount numeric(14,2) not null check (amount > 0),
  currency text not null default 'UZS' check (currency in ('UZS','USD')),
  planned boolean not null default false,
  entry_date date not null default current_date,
  note text,
  created_at timestamptz not null default now()
);
create index on finance_entries (user_id, entry_date);

-- ---------- AI SUHBAT TARIXI ----------
create table public.ai_messages (
  id bigserial primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null check (role in ('user','assistant')),
  content text not null,
  created_at timestamptz not null default now()
);

-- ---------- SHIKOYATLAR ----------
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles(id) on delete cascade,
  product_id uuid references products(id) on delete cascade,
  warehouse_id uuid references warehouses(id) on delete cascade,
  reason text not null,
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------- NARX TAHLILI (faqat haqiqiy e'lonlardan) ----------
-- Tahlil faqat bir xil product_type + unit + currency bo'yicha guruhlanadi.
-- Mijoz tomonda: observations < 5 bo'lsa "ma'lumot yetarli emas" ko'rsating.
create or replace function public.price_stats(p_type text, p_region text default null)
returns table (unit text, currency text, region text, observations bigint,
               min_price numeric, max_price numeric, median_price numeric,
               last_date date)
language sql stable security definer set search_path = public as $$
  select unit, currency, coalesce(p_region, 'all') as region, count(*),
         min(price), max(price),
         percentile_cont(0.5) within group (order by price)::numeric,
         max(created_at)::date
  from products
  where status = 'active' and product_type = p_type
    and (p_region is null or region = p_region)
  group by unit, currency;
$$;

-- ---------- RLS ----------
alter table profiles enable row level security;
alter table products enable row level security;
alter table warehouses enable row level security;
alter table storage_requests enable row level security;
alter table inquiries enable row level security;
alter table saved_products enable row level security;
alter table tasks enable row level security;
alter table finance_entries enable row level security;
alter table ai_messages enable row level security;
alter table reports enable row level security;

create policy "profil: o'zi yoki admin" on profiles for select
  using (id = auth.uid() or public.is_admin());
create policy "profil: o'zini yangilash" on profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

create policy "mahsulot: faol hammaga" on products for select
  using (status = 'active' or seller_id = auth.uid() or public.is_admin());
create policy "mahsulot: sotuvchi qo'shadi" on products for insert
  with check (seller_id = auth.uid());
create policy "mahsulot: egasi yoki admin o'zgartiradi" on products for update
  using (seller_id = auth.uid() or public.is_admin());
create policy "mahsulot: egasi yoki admin o'chiradi" on products for delete
  using (seller_id = auth.uid() or public.is_admin());

create policy "ombor: faol hammaga" on warehouses for select
  using (status = 'active' or owner_id = auth.uid() or public.is_admin());
create policy "ombor: egasi qo'shadi" on warehouses for insert
  with check (owner_id = auth.uid());
create policy "ombor: egasi yoki admin o'zgartiradi" on warehouses for update
  using (owner_id = auth.uid() or public.is_admin());
create policy "ombor: egasi yoki admin o'chiradi" on warehouses for delete
  using (owner_id = auth.uid() or public.is_admin());

create policy "saqlash so'rovi: ko'rish" on storage_requests for select
  using (farmer_id = auth.uid()
         or exists (select 1 from warehouses w where w.id = warehouse_id and w.owner_id = auth.uid()));
create policy "saqlash so'rovi: yuborish" on storage_requests for insert
  with check (farmer_id = auth.uid());
create policy "saqlash so'rovi: ombor egasi holatni o'zgartiradi" on storage_requests for update
  using (exists (select 1 from warehouses w where w.id = warehouse_id and w.owner_id = auth.uid()));

create policy "so'rov: xaridor yoki sotuvchi ko'radi" on inquiries for select
  using (buyer_id = auth.uid()
         or exists (select 1 from products p where p.id = product_id and p.seller_id = auth.uid()));
create policy "so'rov: xaridor yuboradi" on inquiries for insert
  with check (buyer_id = auth.uid());
create policy "so'rov: sotuvchi javob beradi" on inquiries for update
  using (exists (select 1 from products p where p.id = product_id and p.seller_id = auth.uid())
         or buyer_id = auth.uid());

create policy "saqlanganlar: o'zi" on saved_products for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "vazifa: o'zi" on tasks for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "moliya: o'zi" on finance_entries for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "ai: o'zi" on ai_messages for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "shikoyat: yuborish" on reports for insert with check (reporter_id = auth.uid());
create policy "shikoyat: admin ko'radi" on reports for select using (public.is_admin());
create policy "shikoyat: admin hal qiladi" on reports for update using (public.is_admin());

-- Storage: rasmlar uchun ommaviy bucket (Dashboard > Storage da ham yaratish mumkin)
insert into storage.buckets (id, name, public) values ('images','images', true)
on conflict do nothing;
