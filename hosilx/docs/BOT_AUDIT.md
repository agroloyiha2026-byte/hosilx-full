# Bot auditi (1-bosqich)

Ko'rilgan: mening ish nusxamdagi eski bot (`hosilx/bot/main.py`, 397 qator, bitta fayl), SQL migratsiyalar (schema, migration2-12), Flutter loyihasi (`hosilx_flutter`) va sayt (`hosil-x-website`). Sizning `D:` yoki GitHub nusxangizga kira olmayman.

## Eski bot
Bitta faylli aiogram boti: menyu, mahsulotlar, omborlar, vazifalar, `/link`, mahsulot qo'shish (rasm bilan), eslatma va bildirishnoma sikllari. FSM xotirada, test yo'q, ro'yxatdan o'tish yo'q, til faqat xotirada.

## Bazada MAVJUD (bot ishlata oladi)
profiles, products, product_images, product_categories, warehouses, storage_requests, inquiries, tasks, finance_entries, notifications, reports, ai_messages, link_codes, saved_products, banners, ads, news, site_settings, audit_logs, map_places.
RPC: seller_public, set_my_role, admin_stats, notify (ichki).

## Bazada YO'Q (bot uydirmaydi: "Rejalashtirilgan")
Logistika (tashuvchi, buyurtma), texnika ijarasi, agroapteka, dala daftari, Hosil Pasporti (`harvest_passports`, `verify-harvest-passport` funksiyasi ham topilmadi), service_listings, chat jadvallari.
Rollar: `profiles.role` cheklovi faqat farmer, buyer, warehouse_owner, admin. Logist, xizmat ko'rsatuvchi va agroapteka egasi rollari bazada yo'q, shuning uchun ro'yxatdan o'tishda ham yo'q.

## Muhim topilmalar
1. `price_stats` RPC bazada yo'q (sayt ham narxni mijozda hisoblaydi): bot narxni faol e'lonlardan o'zi hisoblaydi.
2. `protect_role` triggeri service_role'ni ham to'xtatadi: bot rolni to'g'ridan-to'g'ri o'zgartira olmaydi; migration12 dagi `bot_set_role()` (whitelist, faqat onboarding tugamagan profil) orqali o'zgartiradi.
3. RLS siyosatlari profilning HAMMA ustunini egasiga yangilashga ruxsat beradi, shu jumladan `telegram_id`. Bu xavfli (boshqa odamning Telegram ID sini o'z profiliga yozish mumkin): migration12 buni trigger bilan yopadi.
4. Veb AI endpointi (`/api/ai`) foydalanuvchi JWT tokenini talab qiladi; bot service_role bilan ishlaydi va JWT yarata olmaydi. Shuning uchun bot o'zining AI adapteriga ega (kalit/model environment'da), kunlik limit esa `ai_messages` orqali sayt bilan umumiy.
