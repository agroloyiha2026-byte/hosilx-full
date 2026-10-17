# Hosil X Flutter ilova: yakuniy ro'yxat

HECH QAYSI QISM ISHGA TUSHIRIB SINALMAGAN (kompilyatsiya ham qilinmagan). Birinchi ishga tushirishda xato chiqishi kutiladi.

## 1. Baza (Supabase SQL Editor, shu tartibda)
Oldindan (sayt va bot uchun allaqachon ishga tushirilgan bo'lishi kerak): schema.sql, migration2.sql, migration3.sql, migration4.sql, migration5.sql.
1. supabase/00_precheck.sql (o'zgartirmaydi, natijani tekshiring)
2. Zaxira nusxa oling
3. supabase/migration6_flutter_app.sql
4. supabase/migration7_seller_public.sql
5. supabase/migration8_audit_triggers.sql
6. supabase/stage7_rls_tests.sql  -> oxirida kutilgan xato chiqadi; xabardagi barcha qatorlar PASS bo'lishi kerak.

## 2. Ilova
1. pubspec.yaml ni qo'ying, paketlarni yuklang (Pub get).
2. lib/core/config/env.dart: SUPABASE_URL, anon kalit, WEB_URL (AI uchun) ni kiriting. service_role kalitini HECH QACHON yozmang.
3. FlutLab Flutter/Dart versiyasi eski bo'lsa (Dart < 3.0): paketlar mos kelmaydi, xato matnini yuboring.
4. iOS: Info.plist ga NSPhotoLibraryUsageDescription (rasm tanlash).
5. Supabase > Authentication: email provayderi yoqilgan; (ixtiyoriy) email tasdiqlash.

## 3. Qo'lda tekshirish
- [ ] Ro'yxatdan o'tish, kirish, chiqish, sessiya ilova qayta ochilganda saqlanadi
- [ ] Profilni to'ldirish (rol tanlash) -> asosiy ekran
- [ ] Til (uz/ru/en) va mavzu (yorug'/tungi) o'zgaradi va saqlanadi
- [ ] Bosh sahifa: bannerlar, kategoriyalar, yangi e'lonlar
- [ ] Bozor: qidiruv, kategoriya, hudud, narx, valyuta, saralash, keyingi sahifa yuklanishi
- [ ] Mahsulot sahifasi, sevimliga qo'shish (saytda ham ko'rinadi), sotuvchiga so'rov
- [ ] E'lon qo'shish/tahrirlash, rasm yuklash (5 MB dan katta va gif rad etiladi)
- [ ] Omborlar, saqlash so'rovi (bo'sh joydan ko'p miqdor rad etiladi)
- [ ] So'rovlar (sotuvchi qabul/rad), bildirishnomalar
- [ ] AI yordamchi (WEB_URL va saytdagi ANTHROPIC_API_KEY bilan)
- [ ] Admin (faqat admin roli): statistika, rollar, moderatsiya, kategoriyalar, bannerlar, reklama, sozlamalar, shikoyatlar, audit
- [ ] Admin bo'lmagan foydalanuvchi /admin ga kira olmaydi va serverda amallar rad etiladi (stage7 testi)

## 4. Ma'lum cheklovlar (halol ro'yxat)
- Hech narsa sinalmagan: kompilyatsiya, testlar, SQL.
- Reklamalar ilovada ko'rsatilmaydi (faqat saytda); reklama statistikasi yo'q.
- Banner "url" turi ilovada ochilmaydi (url_launcher qo'shilmagan).
- Push-bildirishnomalar yo'q (faqat ilova ichidagi).
- Parolni tiklash havolasi saytga olib boradi, saytda yangi parol sahifasi hali yo'q.
- Google bilan kirish ilovaga qo'shilmagan (email/parol).
- Ombor egasi uchun ombor qo'shish/tahrirlash ilovada yo'q (saytda bor).
- E'lonni o'chirish va mavjud rasmni olib tashlash yo'q (yashirish bor).
- Foydalanuvchini bloklash yo'q. Savat va to'lov yo'q (so'rovga asoslangan jarayon).
- AI platforma narxlarini ko'rmaydi; talab prognozi yo'q.
- price_stats() moderatsiyani hisobga olmaydi.
- Banner/kategoriya/sozlama o'zgarishi build talab qilmaydi; ekranlar, ranglar, yangi funksiyalar talab qiladi.
