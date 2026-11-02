-- 12-migratsiya: Telegram bot integratsiyasi. ADDITIVE: mavjud jadval/ustunlar o'zgarmaydi, hech narsa o'chirilmaydi.
-- Production'da AVTOMATIK qo'llanmaydi: SQL Editor'da qo'lda, avval zaxira nusxa bilan.
-- Talab: schema.sql, migration2 (link_codes), migration4 (protect_role), migration6 (notifications). is_admin() mavjud bo'lsin.

-- 1) Telegram ichidagi ro'yxatdan o'tish QORALAMASI. Bu hisob emas: auth.users yaratmaydi va rol bermaydi.
--    status: draft (to'ldirilmoqda) -> pending_link (tayyor, hisobga ulanmagan) -> linked
create table if not exists public.telegram_registrations (
  telegram_id bigint primary key,
  language text not null default 'uz' check (language in ('uz','ru','en')),
  full_name text, role text check (role in ('farmer','buyer','warehouse_owner')),   -- admin bu yerga HECH QACHON yozilmaydi
  phone text, phone_from_telegram boolean not null default false,                   -- Telegram kontakti SMS tasdig'i EMAS
  region text, district text, business_name text, consent_at timestamptz,
  status text not null default 'draft' check (status in ('draft','pending_link','linked')),
  user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.telegram_registrations enable row level security;  -- ATAYLAB siyosatsiz: faqat service_role (bot) kira oladi

-- 2) Profil va bildirishnomalar
alter table public.profiles add column if not exists telegram_notify boolean not null default true;
alter table public.profiles add column if not exists telegram_linked_at timestamptz;
alter table public.notifications add column if not exists tg_sent_at timestamptz;     -- Telegram ishchisi qayta ishlagan (idempotentlik)
create index if not exists notifications_tg_pending_idx on public.notifications (created_at) where tg_sent_at is null;

-- 3) Moliya: takroriy yozuvdan himoya (bot "client_ref" yuboradi; mavjud qatorlarda NULL, ular ta'sirlanmaydi)
alter table public.finance_entries add column if not exists client_ref text;
create unique index if not exists finance_entries_client_ref_uidx on public.finance_entries (user_id, client_ref);

-- 4) telegram_id ni mijoz (ilova/sayt) to'g'ridan-to'g'ri o'zgartira olmasin: faqat bot (service_role) ulash kodi orqali.
--    Aks holda foydalanuvchi o'z profiliga BOSHQA odamning Telegram ID sini yozib, uning xabarlarini o'ziga bog'lab qo'yishi mumkin edi.
create or replace function public.protect_telegram_id() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.telegram_id is distinct from old.telegram_id and auth.uid() is not null and not public.is_admin() then
    raise exception 'telegram_id faqat bot orqali ulash kodi bilan o''zgartiriladi';
  end if;
  return new;
end $$;
drop trigger if exists profiles_protect_telegram on public.profiles;
create trigger profiles_protect_telegram before update on public.profiles for each row execute function public.protect_telegram_id();

-- 5) Bot rolni faqat shu funksiya orqali, faqat whitelist va faqat onboarding tugallanmagan profil uchun belgilaydi (set_my_role bilan bir xil qoida)
create or replace function public.bot_set_role(p_user uuid, p_role text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_role not in ('farmer','buyer','warehouse_owner') then raise exception 'ruxsat etilmagan rol'; end if;
  perform set_config('app.role_change', '1', true);
  update public.profiles set role = p_role where id = p_user and onboarded = false and role <> 'admin';
end $$;
revoke all on function public.bot_set_role(uuid, text) from public, anon, authenticated;
grant execute on function public.bot_set_role(uuid, text) to service_role;
