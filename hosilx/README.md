# Hosil X

1. supabase/schema.sql, migration2.sql, migration3.sql (shu tartibda, SQL Editor)
2. web/    : cp .env.example .env.local, to'ldiring; npm install && npm run dev  (Vercel'ga deploy)
3. bot/    : .env.example'dagi o'zgaruvchilar; pip install -r requirements.txt && python main.py  (Render)
4. mobile/ : flutter create . (platforma papkalarini yaratadi), keyin
             flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=WEB_URL=...

Admin yaratish: ro'yxatdan o'ting, keyin SQL: update profiles set role='admin' where id='<user id>';
