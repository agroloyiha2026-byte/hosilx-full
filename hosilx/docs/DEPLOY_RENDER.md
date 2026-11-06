# Render'ga joylash (va "requirements.txt topilmadi" xatosi)

## 1. "Could not open requirements file" xatosining sababi
Render repository ILDIZIDA `requirements.txt` qidiradi. Bot esa papka ichida (`hosil-x-bot/`). Ikki yo'l:
- **Dashboard → Settings → Root Directory** ga bot papkasini yozing (masalan `hosil-x-bot`; ichida `requirements.txt` va `bot/` bo'lishi kerak). Yoki
- papka ichidagi fayllarni repository ildiziga ko'chiring.

## 2. Dashboard sozlamalari
| Maydon | Qiymat |
|---|---|
| Root Directory | `hosil-x-bot` (yoki requirements.txt turgan papka) |
| Build Command | `pip install -r requirements.txt` |
| Start Command | `python -m bot.main` (eski `python main.py` EMAS) |
| Health Check Path | `/health` |
| Environment | `PYTHON_VERSION=3.12.8`, `TELEGRAM_BOT_TOKEN` (yoki eski `BOT_TOKEN`), `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, ixtiyoriy `WEB_URL`, `ANTHROPIC_API_KEY`, `AI_MODEL` |

Python: Render standart 3.14 ni tanlaydi; `PYTHON_VERSION=3.12.8` qo'ying (papkada `.python-version` ham bor).
Eski bot xizmatini to'xtating: bir token bilan ikkita polling bo'lsa 409 Conflict chiqadi.

## 3. Bot uxlab qolmasligi uchun
Render hujjati: bepul web xizmati **15 daqiqa tashqi trafiksiz qolsa uxlaydi**, uxlagan xizmat keyingi so'rovda ~1 daqiqada uyg'onadi. Telegramga chiqadigan polling so'rovlari "trafik" hisoblanmaydi.
1. **Tekshiring (bu eng muhim):** deploydan keyin loglarda `keepalive: yoqilgan (...)` va, 30 soniyadan keyin, `keepalive: birinchi chaqiruv muvaffaqiyatli` yozuvi chiqishi kerak. `keepalive 3 marta ketma-ket ishlamadi` chiqsa, `KEEPALIVE_URL=https://<xizmat>.onrender.com` ni qo'lda kiriting.
2. **Tashqi monitor (majburiy deb hisoblang):** uptimerobot.com yoki cron-job.org (bepul), `https://<xizmat>.onrender.com/health`, har 5 daqiqa. Bot o'zini o'zi uyg'ota olmaydi: xizmat bir marta uxlab qolsa, faqat tashqi so'rov uni uyg'otadi.
3. **Botning tirikligini ko'rish:** brauzerda `/health` ni oching: `last_update_s_ago` oxirgi Telegram xabaridan beri o'tgan soniyalar, `uptime_s` esa xizmat qayta ishga tushganini ko'rsatadi (kichik bo'lsa, xizmat yaqinda qayta ishga tushgan).
4. **750 soat qoidasi:** bepul tarif butun workspace uchun oyiga 750 soat; bitta xizmat 24/7 ishlasa ~744 soat ketadi. Workspace'da boshqa bepul xizmat bo'lsa (eski bot, boshqa sayt), soat yetmaydi va xizmatlar oy oxirigacha to'xtatiladi. Kerak bo'lmagan xizmatlarni o'chiring.
5. **Kafolatli yechim:** Settings → Instance Type → **Starter (taxminan $7/oy)**. Pullik xizmat uxlamaydi. Bepul tarif sinov uchun mo'ljallangan: xizmat qayta ishga tushishi va qisqa uzilishlar bo'lishi mumkin.
6. Webhook rejimi (`BOT_MODE=webhook`) "doimiy" talabga mos emas: u uxlagan xizmatni faqat Telegram xabari kelganda uyg'otadi, eslatma/bildirishnoma ishchisi esa uxlab turganda ishlamaydi.

## 4. Fayllarni repository'ga joylash (ikki variant)
**A) Eski papkaga (hosilx/bot/) to'g'ridan-to'g'ri** (shu variantda ham ishlaydi): zipdagi `bot/` papkasi ICHIDAGI hamma narsa (`main.py`, `config.py`, `handlers/`, `services/`, `utils/` ...) `hosilx/bot/` ga, `requirements.txt` ham shu yerga. Root Directory = `hosilx/bot`, Start Command = `python main.py`.
  - **Eski fayllarni o'chiring** (eski `utils.py`, eski `main.py` qoldiqlari va boshqalar): ular yangi `utils/` papkasi bilan to'qnashishi mumkin.
  - `main.py` o'zini avtomatik paket sifatida ulaydi, shuning uchun `attempted relative import with no known parent package` xatosi chiqmaydi.
**B) Toza joylashuv:** `hosil-x-bot/` papkasini butunicha yuklang, Root Directory = `hosil-x-bot`, Start Command = `python -m bot.main`.

## 5. Python versiyasi
Log `Using Python version 3.14` ko'rsatsa, Environment'ga `PYTHON_VERSION=3.12.8` qo'shing. Hozirgi 3.14 da paketlar o'rnatildi, lekin 3.12 tekshirilgan va xavfsizroq tanlov.
