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
  handlers/          start (ro'yxatdan o'tish, /link), menu, market, warehouses, planner, finance, ai, profile, reports, fallback
  services/          ai (adapter), notifier (bildirishnoma/eslatma), summary
  utils/             toza funksiyalar: validators, finance, prices, registration, links, notify, ai_prompts, pagination, regions, ratelimit
supabase/migration12_telegram_bot.sql
tests/               52 test
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
| Logistika, texnika ijarasi, agroapteka, dala daftari, Hosil Pasporti | Rejalashtirilgan: bazada jadval yo'q, bot "rejalashtirilgan" deydi |
| Logist/xizmat/agroapteka egasi rollari, SMS OTP, chat | Yo'q (bazada/provayderda mavjud emas) |

## Migratsiya (production'ga avtomatik qo'llanmaydi)
SQL Editor'da, zaxira nusxadan keyin: avval schema, migration2, 4, 6 (mavjud bo'lsa o'tkazing), keyin **`supabase/migration12_telegram_bot.sql`**. U additive: yangi jadval `telegram_registrations`, profil/bildirishnoma ustunlari, `finance_entries.client_ref`, `telegram_id` himoyasi va `bot_set_role()`. Ulanmagan holatda bot ishlamaydi (ustunlar topilmaydi).

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
`render.yaml` tayyor. Environment'ga `.env.example` dagi nomlar kiritiladi (kalitlar `sync: false`). **Bepul web xizmati 15 daqiqada uxlaydi**: polling to'xtaydi; webhook rejimida (`BOT_MODE=webhook`, `WEBHOOK_URL`, `WEBHOOK_SECRET`) Telegram so'rovi uyg'otadi, lekin eslatma ishchisi uxlagan paytda ishlamaydi. FSM holatini saqlash uchun `REDIS_URL` bering, aks holda qayta ishga tushganda yarim qolgan formalar (ro'yxatdan o'tish bundan mustasno, u bazada) yo'qoladi. Health: `GET /health`.

## Tekshiruvlar
Bajarilgan: 52 test (validatorlar, sozlamalar, sana/vaqt, moliya hisobi, narx, bildirishnoma qoidalari, ro'yxatdan o'tish mantig'i, tezlik cheklovi, soxta Supabase bilan egalik/ko'rinish/idempotentlik/ulash kodi, 3 til paritetini va kodda ishlatilgan har bir matn kaliti borligini tekshirish, import tutun testi).
**Bajarilmagan:** haqiqiy aiogram bilan handlerlarni ishga tushirish, haqiqiy Supabase/Telegram/AI bilan sinov (bu muhitda paket va tarmoq yo'q). Mock testlar o'tishi deployment ishlashini isbotlamaydi.
