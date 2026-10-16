-- 2-qism: Storage siyosatlari va Telegram ulash kodlari
create policy "img: hamma ko'radi" on storage.objects for select using (bucket_id = 'images');
create policy "img: o'z papkasiga yuklaydi" on storage.objects for insert to authenticated
  with check (bucket_id = 'images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "img: o'zinikini o'chiradi" on storage.objects for delete to authenticated
  using (bucket_id = 'images' and (storage.foldername(name))[1] = auth.uid()::text);

create table public.link_codes (
  code text primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  expires_at timestamptz not null default now() + interval '15 minutes'
);
alter table public.link_codes enable row level security;
create policy "kod: o'zi yaratadi" on link_codes for insert with check (user_id = auth.uid());
create policy "kod: o'zi ko'radi" on link_codes for select using (user_id = auth.uid());
-- Bot service key bilan ishlaydi (RLS'ni chetlab o'tadi).
