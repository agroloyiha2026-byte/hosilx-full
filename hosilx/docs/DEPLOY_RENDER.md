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
Bepul web xizmati 15 daqiqa TASHQARIDAN so'rov kelmasa uxlaydi; Telegramga chiqadigan polling so'rovlari buni to'xtatmaydi.
- **Avtomatik (kodda):** bot `RENDER_EXTERNAL_URL/health` ni har 10 daqiqada chaqiradi. Loglarda `keepalive: yoqilgan (...)` yozuvi chiqishi kerak. Sozlama shart emas (o'chirish: `KEEPALIVE=off`).
- **Ikkinchi qatlam (tavsiya):** uptimerobot.com (bepul) da HTTP monitor: `https://<xizmat>.onrender.com/health`, har 5 daqiqa. Bot qulab tushsa yoki qayta ishga tushsa ham tashqaridan kuzatadi.
- **Chegaralar (halol):** bepul tarif oyiga 750 soat beradi: bitta xizmat 24/7 ishlasa yetadi (744 soat), ikkinchi bepul xizmat qo'shsangiz yetmaydi. Render siyosati o'zgarishi mumkin va bepul tarifda ishlash kafolatlanmagan; qayta joylash yoki xizmat yangilanishida qisqa uzilish bo'ladi.
- **Kafolatli yechim:** pullik `Starter` tarif (uxlamaydi). Boshqa yo'l: webhook rejimi (`BOT_MODE=webhook`), lekin u uxlagan xizmatni faqat Telegram xabari kelganda uyg'otadi (birinchi javob sekin) va eslatma ishchisi uxlab turgan paytda ishlamaydi, shuning uchun "doimiy" talabga mos emas.
