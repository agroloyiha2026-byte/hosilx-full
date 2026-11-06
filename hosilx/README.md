# Hosil X: Telegram bot

aiogram 3 asosidagi bot. Mobil ilova va sayt bilan **bitta Supabase bazasi va bitta akkaunt** (`profiles.id` = `auth.users.id`) orqali ishlaydi: bot hech qaysi jadvalning nusxasini yaratmaydi.

## Tuzilma
```
bot/
  main.py            ishga tushirish (polling/webhook), /health, bildirishnoma ishchisi
  config.py          environment (maxfiy qiymatlar logga yozilmaydi)
  db.py              Supabase mijozi (service_role)
  repositories.py    BARCHA bazaga murojaat; egalik va ko'rinish filtrlari shu yerda
  i18n.py            uz/ru/en matnlar (har kalit bitta qatorda uch tilda)
  middlewares.py     foydalanuvchi konteksti (profil, til), tezlik cheklovi, xato ushlagich
  handlers/          start (ro'yxatdan o'tish, /link), menu, market, warehouses, services (agroapteka, texnika, logistika), diary (dala daftari), planner, finance, ai, profile, reports, fallback
  services/          ai (adapter), notifier (bildirishnoma/eslatma), keepalive, specs (agroapteka/texnika/logistika tavsiflari), summary
  utils/             toza funksiyalar: validators, finance, prices, registration, links, notify, ai_prompts, pagination, regions, ratelimit
supabase/migration12_telegram_bot.sql
tests/               77 test
```

## Ro'yxatdan o'tish va hisobni ulash (qaror va sabab)
1. `/start`: til, ism, rol (faqat farmer/buyer/ombor egasi; admin tanlanmaydi), telefon (Telegram kontakti yoki qo'lda), viloyat, tuman, xo'jalik nomi (ixtiyoriy), rozilik, tasdiq. Har qadamdan keyin qoralama bazaga saqlanadi (bot qayta ishga tushsa ham davom etadi), "Orqaga" va `/cancel` ishlaydi.
2. Natija **hisob emas, `pending_link` qoralamasi**. Telegram kontakti SMS tasdig'i emas; bot buni "tasdiqlanmagan" deb belgilaydi. SMS OTP provayderi yo'q.
3. Hisob saytda yoki ilovada yaratiladi (Supabase Auth). U yerda **Sozlamalar → Telegram → "Ulash kodini olish"** (ilovada bor) va botga `/link KOD` yuboriladi. Kod: bir martalik (o'chirilib keyin tekshiriladi), 15 daqiqa, faqat tizimga kirgan egasi yarata oladi.
   *Nega botning o'zi hisob yaratmaydi?* Telegram egasi bilan hisob (email) egasi bir odam ekanini isbotlash faqat kirgan sessiyadagi kod bilan mumkin. Aks holda birov begona email bilan hisob ochib, o'z Telegramini ulab olishi mumkin edi.
4. Ulangach qoralamadan ism/telefon/hudud profilga **faqat bo'sh joylarga** qo'shiladi (mavjud qiymat ustidan yozilmaydi); rol faqat `bot_set_role()` orqali va faqat onboarding tugallanmagan bo'lsa.
5. Ulanmagan foydalanuvchi: bozor va omborlarni ko'ra oladi; shaxsiy bo'limlar (vazifa, moliya, AI, so'rov, shikoyat, e'lon) uchun hisob ulanishi talab qilinadi.

## Xavfsizlik
- `SUPABASE_SERVICE_KEY` RLS'ni chetlab o'tadi: shuning uchun har bir so'rov egalikni o'zi tekshiradi (`user_id`/`seller_id`/`owner_id` filtrlari) va bu testlangan (`tests/test_repo.py`). Kalit faqat bot muhitida.
- Rol, ruxsat va identifikatsiya faqat bazadagi profildan; `callback_data`, username yoki foydalanuvchi matni ishonchli emas (ID'lar UUID tekshiruvidan, tanlovlar bazadagi ro'yxatdan o'tkaziladi).
- Admin funksiyalari botda YO'Q (admin sayt/ilovada, RLS orqali).
- Foydalanuvchi matni HTML-escape qilinadi; xatolarda maxfiy qiymatlar chiqmaydi; tezlik cheklovi (10 yangilanish/10 s).
- Moliya: ko'rib chiqish → tasdiq; takroriy bosishdan `(user_id, client_ref)` unique indeks himoyalaydi.

## Modul holatlari
| Modul | Holat |
|---|---|
| Ro'yxatdan o'tish (qoralama), til, /link | Kod tayyor (Telegram bilan sinalmagan); `migration12` kerak |
| Bozor: qidiruv, kategoriya/hudud filtri, rasm, sotuvchi (ism/hudud), so'rov, o'z e'lonlari, e'lon qo'shish | Kod tayyor (sinalmagan) |
| Omborlar: qidiruv, saqlash so'rovi, egasi: bo'sh joy va so'rovlar | Kod tayyor (sinalmagan) |
| Maqsadlar va vazifalar | Kod tayyor (ustuvorlik va maqsadga bog'lash bazada yo'q) |
| Moliya: daromad/xarajat, hisobot | Kod tayyor (sinalmagan); kengaytirilgan turkumlar uchun migration10 + `FINANCE_EXTENDED_CATEGORIES=true` |
| AI: Doctor, Agro, Finance, General | Sozlanmoqda: `ANTHROPIC_API_KEY` va `AI_MODEL` kerak |
| AI Narx | Ishlaydi sxemada: AI emas, faol e'lonlardan hisoblanadi (sinalmagan) |
| Shikoyat (mahsulot, ombor) | Kod tayyor (sinalmagan) |
| Bildirishnoma va vazifa eslatmasi | Kod tayyor; `migration12` kerak |
| Agroapteka: aptekalar va mahsulotlar (katalog, qidiruv, hudud/turkum filtri, so'rov, shikoyat, egasi paneli) | Kod tayyor (sinalmagan); `migration13` kerak |
| Texnika ijarasi: e'lonlar, filtr, so'rov, shikoyat, egasi paneli | Kod tayyor (sinalmagan); `migration13` kerak |
| Logistika: tashuvchi e'lonlari (qaytish yo'li, boshqa yuk bilan), so'rov, shikoyat, egasi paneli | Kod tayyor (sinalmagan); `migration13` kerak |
| Dala daftari: dalalar, 8 turdagi qayd (ekish, sug'orish, o'g'it, dori, mehnat, hosil, xarajat, kuzatuv), yillik xulosa | Kod tayyor (sinalmagan); `migration13` kerak |
| Hosil Pasporti (QR) | Rejalashtirilgan: ochiq tekshiruv sahifasi (sayt) va QR xizmati yo'q, shuning uchun bot uni uydirmaydi |
| Maxsus logist/agroapteka rollari, SMS OTP, bot ichidagi chat | Yo'q. Yangi modullar uchun rol shart emas: har qanday ulangan foydalanuvchi e'lon qo'sha oladi; aloqa e'londagi telefon yoki so'rov matni orqali |

## Migratsiya (production'ga avtomatik qo'llanmaydi)
SQL Editor'da, zaxira nusxadan keyin: avval schema, migration2, 4, 6 (mavjud bo'lsa o'tkazing), keyin **`supabase/migration12_telegram_bot.sql`**, keyin **`supabase/migration13_services.sql`** (agroapteka, texnika, logistika, dala daftari; additive). U additive: yangi jadval `telegram_registrations`, profil/bildirishnoma ustunlari, `finance_entries.client_ref`, `telegram_id` himoyasi va `bot_set_role()`. Ulanmagan holatda bot ishlamaydi (ustunlar topilmaydi).

## Lokal ishga tushirish
```bash
python -m venv .venv && source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env     # qiymatlarni o'zingiz kiriting; keyin muhitga yuklang
export $(grep -v '^#' .env | xargs)    # Windows PowerShell'da $env:NAME="..." bilan
python -m bot.main
python -m unittest discover -s tests -t .     # testlar (internet va kalit kerak emas)
```
Bir token uchun bir vaqtda faqat BITTA polling nusxasi ishlashi kerak (aks holda 409 Conflict). Eski botni (`hosilx/bot`) to'xtating.

## Deploy (Render)
To'liq yo'riqnoma: `docs/DEPLOY_RENDER.md` ("requirements.txt topilmadi" xatosi: **Root Directory** bot papkasiga qaratilishi kerak). Start: `python -m bot.main`, Python 3.12 (`PYTHON_VERSION=3.12.8`), health: `/health`.
**Uxlab qolish:** bepul web xizmati 15 daqiqa tashqi trafiksiz uxlaydi. Bot `RENDER_EXTERNAL_URL/health` ni har 10 daqiqada o'zi chaqiradi (keep-alive) va uptimerobot.com'da qo'shimcha monitor tavsiya etiladi; lekin bepul tarifda doimiy ishlash KAFOLATLANMAGAN: kafolat uchun pullik tarif. FSM holatini saqlash uchun `REDIS_URL` bering.

## Tekshiruvlar
Bajarilgan: 77 test (validatorlar, sozlamalar, sana/vaqt, moliya hisobi, narx, bildirishnoma qoidalari, ro'yxatdan o'tish mantig'i, tezlik cheklovi, soxta Supabase bilan egalik/ko'rinish/idempotentlik/ulash kodi, 3 til paritetini va kodda ishlatilgan har bir matn kaliti borligini tekshirish, import tutun testi).
**Bajarilmagan:** haqiqiy aiogram bilan handlerlarni ishga tushirish, haqiqiy Supabase/Telegram/AI bilan sinov (bu muhitda paket va tarmoq yo'q). Mock testlar o'tishi deployment ishlashini isbotlamaydi.

## Yangi modullar: bilish kerak bo'lgan cheklovlar
- Ilova va sayt bu jadvallar (`pharmacies`, `machinery_listings`, `freight_listings`, `farm_fields`, ...) uchun hali ekranga ega emas: ma'lumot bot va Supabase'da turadi, bazada umumiy.
- E'lonlar darhol ko'rinadi (`moderation_status='approved'`). Admin uchun hozircha alohida ekran yo'q: yashirish Supabase Table Editor'da `moderation_status='rejected'` qilish bilan.
- Pestitsid e'lonlarida "sotuvchi kiritgan, tekshirilmagan" ogohlantirishi chiqadi; bot me'yor yoki sertifikat uydirmaydi.
- Bot ichida chat yo'q: so'rov egasiga bildirishnoma boradi (ilova, sayt va Telegram), qabul/rad qilinsa so'rovchiga xabar boradi. Aloqa uchun so'rov matniga telefon yozing.
