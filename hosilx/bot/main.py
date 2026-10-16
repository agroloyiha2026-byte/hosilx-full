"""Hosil X Telegram bot (aiogram 3 + supabase-py).

Muhit o'zgaruvchilari: BOT_TOKEN, SUPABASE_URL, SUPABASE_SERVICE_KEY, WEB_URL, PORT
Service key faqat serverda (Render) saqlanadi, hech qachon klientga berilmaydi.
Ishga tushirish: python main.py
"""
import asyncio
import logging
import os
from datetime import datetime, timezone

from aiogram import Bot, Dispatcher, F, Router
from aiogram.filters import Command, CommandStart
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.types import (CallbackQuery, InlineKeyboardButton,
                           InlineKeyboardMarkup, Message)
from supabase import create_client
from aiohttp import web

logging.basicConfig(level=logging.INFO)
sb = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_KEY"])
WEB_URL = os.environ.get("WEB_URL", "https://hosilx.vercel.app")
router = Router()

T = {
    "uz": {"choose_lang": "Tilni tanlang", "menu": "🌾 Hosil X — asosiy menyu",
           "market": "🛒 Bozor", "wh": "🏭 Omborlar", "tasks": "✅ Vazifalarim",
           "ai": "🤖 AI yordamchi", "web": "🌐 Sayt va ilova", "lang": "🌐 Til",
           "empty_p": "Hozircha e'lonlar yo'q.", "empty_w": "Hozircha omborlar yo'q.",
           "need_link": "Vazifalarni ko'rish uchun profilingizni ulang: saytda Sozlamalar → Telegram.",
           "no_tasks": "Bugun vazifalar yo'q.", "ai_soon": "AI yordamchi saytda va ilovada ochiladi.",
           "reminder": "⏰ Eslatma", "free": "bo'sh", "back": "⬅️ Menyu"},
    "ru": {"choose_lang": "Выберите язык", "menu": "🌾 Hosil X — главное меню",
           "market": "🛒 Рынок", "wh": "🏭 Склады", "tasks": "✅ Мои задачи",
           "ai": "🤖 AI-помощник", "web": "🌐 Сайт и приложение", "lang": "🌐 Язык",
           "empty_p": "Пока нет объявлений.", "empty_w": "Пока нет складов.",
           "need_link": "Чтобы видеть задачи, привяжите профиль: на сайте Настройки → Telegram.",
           "no_tasks": "На сегодня задач нет.", "ai_soon": "AI-помощник доступен на сайте и в приложении.",
           "reminder": "⏰ Напоминание", "free": "свободно", "back": "⬅️ Меню"},
    "en": {"choose_lang": "Choose language", "menu": "🌾 Hosil X — main menu",
           "market": "🛒 Market", "wh": "🏭 Warehouses", "tasks": "✅ My tasks",
           "ai": "🤖 AI assistant", "web": "🌐 Website & app", "lang": "🌐 Language",
           "empty_p": "No listings yet.", "empty_w": "No warehouses yet.",
           "need_link": "To see tasks, link your profile: website Settings → Telegram.",
           "no_tasks": "No tasks for today.", "ai_soon": "The AI assistant is available on the website and app.",
           "reminder": "⏰ Reminder", "free": "free", "back": "⬅️ Menu"},
}
_lang_cache: dict[int, str] = {}


def get_profile(tg_id: int):
    r = sb.table("profiles").select("id,language").eq("telegram_id", tg_id).limit(1).execute()
    return r.data[0] if r.data else None


def lang_of(tg_id: int) -> str:
    p = get_profile(tg_id)
    if p:
        return p["language"]
    return _lang_cache.get(tg_id, "uz")


def menu_kb(l: str) -> InlineKeyboardMarkup:
    t = T[l]
    rows = [
        [InlineKeyboardButton(text=t["market"], callback_data="market"),
         InlineKeyboardButton(text=t["wh"], callback_data="wh")],
        [InlineKeyboardButton(text=t["tasks"], callback_data="tasks"),
         InlineKeyboardButton(text=t["ai"], callback_data="ai")],
        [InlineKeyboardButton(text=P[l]["add_btn"], callback_data="addp")],
        [InlineKeyboardButton(text=t["web"], url=WEB_URL),
         InlineKeyboardButton(text=t["lang"], callback_data="lang")],
    ]
    return InlineKeyboardMarkup(inline_keyboard=rows)


def lang_kb() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[[
        InlineKeyboardButton(text="🇺🇿 O'zbekcha", callback_data="setlang:uz"),
        InlineKeyboardButton(text="🇷🇺 Русский", callback_data="setlang:ru"),
        InlineKeyboardButton(text="🇬🇧 English", callback_data="setlang:en"),
    ]])


@router.message(CommandStart())
async def start(m: Message):
    await m.answer(T["uz"]["choose_lang"] + " / Выберите язык / Choose language",
                   reply_markup=lang_kb())


@router.callback_query(F.data == "lang")
async def change_lang(c: CallbackQuery):
    await c.message.edit_text(T[lang_of(c.from_user.id)]["choose_lang"], reply_markup=lang_kb())
    await c.answer()


@router.callback_query(F.data.startswith("setlang:"))
async def set_lang(c: CallbackQuery):
    l = c.data.split(":")[1]
    if l not in T:
        return await c.answer()
    _lang_cache[c.from_user.id] = l
    if get_profile(c.from_user.id):  # profil bilan sinxron
        sb.table("profiles").update({"language": l}).eq("telegram_id", c.from_user.id).execute()
    await c.message.edit_text(T[l]["menu"], reply_markup=menu_kb(l))
    await c.answer()


def back_kb(l: str) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=[[
        InlineKeyboardButton(text=T[l]["back"], callback_data="menu")]])


@router.callback_query(F.data == "menu")
async def to_menu(c: CallbackQuery):
    l = lang_of(c.from_user.id)
    await c.message.edit_text(T[l]["menu"], reply_markup=menu_kb(l))
    await c.answer()


@router.callback_query(F.data == "market")
async def market(c: CallbackQuery):
    l = lang_of(c.from_user.id)
    r = (sb.table("products").select("title,price,currency,unit,quantity,region")
         .eq("status", "active").order("created_at", desc=True).limit(8).execute())
    if not r.data:
        text = T[l]["empty_p"]
    else:
        text = "\n\n".join(
            f"🌿 <b>{p['title']}</b>\n{p['price']:,.0f} {p['currency']}/{p['unit']} · "
            f"{p['quantity']:g} {p['unit']}\n📍 {p['region']}" for p in r.data)
    await c.message.edit_text(text, parse_mode="HTML", reply_markup=back_kb(l))
    await c.answer()


@router.callback_query(F.data == "wh")
async def warehouses(c: CallbackQuery):
    l = lang_of(c.from_user.id)
    r = (sb.table("warehouses").select("name,region,storage_type,free_tons,capacity_tons")
         .eq("status", "active").order("created_at", desc=True).limit(8).execute())
    if not r.data:
        text = T[l]["empty_w"]
    else:
        text = "\n\n".join(
            f"🏭 <b>{w['name']}</b>\n📍 {w['region']} · {w['storage_type']}\n"
            f"{w['free_tons']:g}/{w['capacity_tons']:g} t {T[l]['free']}" for w in r.data)
    await c.message.edit_text(text, parse_mode="HTML", reply_markup=back_kb(l))
    await c.answer()


@router.callback_query(F.data == "tasks")
async def my_tasks(c: CallbackQuery):
    l = lang_of(c.from_user.id)
    p = get_profile(c.from_user.id)
    if not p:
        text = T[l]["need_link"]
    else:
        end = datetime.now(timezone.utc).replace(hour=23, minute=59, second=59)
        r = (sb.table("tasks").select("title,due_at").eq("user_id", p["id"]).eq("done", False)
             .lte("due_at", end.isoformat()).order("due_at").limit(10).execute())
        text = "\n".join(f"▫️ {t['due_at'][11:16]} — {t['title']}" for t in r.data) or T[l]["no_tasks"]
    await c.message.edit_text(text, reply_markup=back_kb(l))
    await c.answer()


@router.callback_query(F.data == "ai")
async def ai(c: CallbackQuery):
    l = lang_of(c.from_user.id)
    kb = InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text=T[l]["ai"], url=f"{WEB_URL}/ai")],
        [InlineKeyboardButton(text=T[l]["back"], callback_data="menu")]])
    await c.message.edit_text(T[l]["ai_soon"], reply_markup=kb)
    await c.answer()


P = {
    "uz": {"add_btn": "➕ Mahsulot qo'shish", "title": "Mahsulot nomini yozing:", "ptype": "Mahsulot turi (masalan: pomidor):",
           "cat": "Kategoriyani tanlang:", "price": "Narxi (so'm, 1 kg uchun):", "qty": "Miqdori (kg):", "region": "Hudud:",
           "done": "✅ E'lon joylandi!", "bad": "Iltimos, to'g'ri son kiriting.", "need": "Avval profilni ulang: saytda Sozlamalar → Telegram, so'ng /link KOD.",
           "linked": "✅ Profil ulandi.", "badcode": "Kod noto'g'ri yoki muddati o'tgan.", "cancel": "Bekor qilindi."},
    "ru": {"add_btn": "➕ Добавить продукт", "title": "Введите название продукта:", "ptype": "Тип продукта (например: помидоры):",
           "cat": "Выберите категорию:", "price": "Цена (сум за 1 кг):", "qty": "Количество (кг):", "region": "Регион:",
           "done": "✅ Объявление размещено!", "bad": "Введите корректное число.", "need": "Сначала привяжите профиль: на сайте Настройки → Telegram, затем /link КОД.",
           "linked": "✅ Профиль привязан.", "badcode": "Код неверный или истёк.", "cancel": "Отменено."},
    "en": {"add_btn": "➕ Add product", "title": "Enter the product title:", "ptype": "Product type (e.g. tomato):",
           "cat": "Choose a category:", "price": "Price (UZS per 1 kg):", "qty": "Quantity (kg):", "region": "Region:",
           "done": "✅ Listing posted!", "bad": "Please enter a valid number.", "need": "Link your profile first: website Settings → Telegram, then /link CODE.",
           "linked": "✅ Profile linked.", "badcode": "Invalid or expired code.", "cancel": "Cancelled."},
}


class Add(StatesGroup):
    title = State()
    ptype = State()
    price = State()
    qty = State()
    region = State()
    photo = State()


CATS = [("🍎", "fruit"), ("🥕", "vegetable"), ("🌾", "grain"), ("🥛", "dairy"), ("📦", "other")]


@router.message(Command("link"))
async def link(m: Message):
    l = lang_of(m.from_user.id)
    parts = (m.text or "").split()
    if len(parts) != 2:
        return await m.answer(P[l]["badcode"])
    r = sb.table("link_codes").select("user_id,expires_at").eq("code", parts[1].upper()).limit(1).execute()
    if not r.data or r.data[0]["expires_at"] < datetime.now(timezone.utc).isoformat():
        return await m.answer(P[l]["badcode"])
    sb.table("profiles").update({"telegram_id": m.from_user.id}).eq("id", r.data[0]["user_id"]).execute()
    sb.table("link_codes").delete().eq("code", parts[1].upper()).execute()
    await m.answer(P[lang_of(m.from_user.id)]["linked"])


@router.message(Command("cancel"))
async def cancel(m: Message, state: FSMContext):
    await state.clear()
    await m.answer(P[lang_of(m.from_user.id)]["cancel"])


@router.callback_query(F.data == "addp")
async def addp(c: CallbackQuery, state: FSMContext):
    l = lang_of(c.from_user.id)
    if not get_profile(c.from_user.id):
        await c.message.answer(P[l]["need"])
        return await c.answer()
    await state.set_state(Add.title)
    await c.message.answer(P[l]["title"])
    await c.answer()


@router.message(Add.title)
async def a_title(m: Message, state: FSMContext):
    await state.update_data(title=(m.text or "")[:100])
    await state.set_state(Add.ptype)
    await m.answer(P[lang_of(m.from_user.id)]["ptype"])


@router.message(Add.ptype)
async def a_type(m: Message, state: FSMContext):
    await state.update_data(ptype=(m.text or "")[:60].lower())
    kb = InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(text=e, callback_data=f"cat:{k}") for e, k in CATS]])
    await m.answer(P[lang_of(m.from_user.id)]["cat"], reply_markup=kb)


@router.callback_query(F.data.startswith("cat:"))
async def a_cat(c: CallbackQuery, state: FSMContext):
    if await state.get_state() != Add.ptype.state:
        return await c.answer()
    await state.update_data(cat=c.data.split(":")[1])
    await state.set_state(Add.price)
    await c.message.answer(P[lang_of(c.from_user.id)]["price"])
    await c.answer()


from utils import num


@router.message(Add.price)
async def a_price(m: Message, state: FSMContext):
    l = lang_of(m.from_user.id)
    v = num(m.text)
    if v is None:
        return await m.answer(P[l]["bad"])
    await state.update_data(price=v)
    await state.set_state(Add.qty)
    await m.answer(P[l]["qty"])


@router.message(Add.qty)
async def a_qty(m: Message, state: FSMContext):
    l = lang_of(m.from_user.id)
    v = num(m.text)
    if v is None:
        return await m.answer(P[l]["bad"])
    await state.update_data(qty=v)
    await state.set_state(Add.region)
    await m.answer(P[l]["region"])


PH = {"uz": "Rasm yuboring yoki /skip yozing:", "ru": "Отправьте фото или напишите /skip:", "en": "Send a photo or type /skip:"}


@router.message(Add.region)
async def a_region(m: Message, state: FSMContext):
    await state.update_data(region=(m.text or "")[:80])
    await state.set_state(Add.photo)
    await m.answer(PH[lang_of(m.from_user.id)])


async def finish_product(m: Message, state: FSMContext, image_url):
    l = lang_of(m.from_user.id)
    d = await state.get_data()
    p = get_profile(m.from_user.id)
    await state.clear()
    if not p:
        return await m.answer(P[l]["need"])
    sb.table("products").insert({
        "seller_id": p["id"], "title": d["title"], "category": d["cat"], "product_type": d["ptype"],
        "price": d["price"], "currency": "UZS", "unit": "kg", "quantity": d["qty"],
        "region": d["region"], "image_url": image_url}).execute()
    await m.answer(P[l]["done"], reply_markup=menu_kb(l))


@router.message(Add.photo, Command("skip"))
async def a_skip(m: Message, state: FSMContext):
    await finish_product(m, state, None)


@router.message(Add.photo, F.photo)
async def a_photo(m: Message, state: FSMContext, bot: Bot):
    p = get_profile(m.from_user.id)
    url = None
    try:
        photo = m.photo[-1]
        if photo.file_size and photo.file_size > 5 * 1024 * 1024:
            raise ValueError("too big")
        f = await bot.get_file(photo.file_id)
        buf = await bot.download_file(f.file_path)
        path = f"{p['id']}/{photo.file_unique_id}.jpg"
        sb.storage.from_("images").upload(path, buf.read(), {"content-type": "image/jpeg"})
        url = sb.storage.from_("images").get_public_url(path)
    except Exception:
        logging.exception("photo upload failed")
    await finish_product(m, state, url)


N = {"uz": ("📩 Yangi so'rov", "📦 Yangi saqlash so'rovi"),
     "ru": ("📩 Новый запрос", "📦 Новый запрос на хранение"),
     "en": ("📩 New inquiry", "📦 New storage request")}


async def push(bot: Bot, user_id: str, key: int, text: str):
    p = sb.table("profiles").select("telegram_id,language").eq("id", user_id).single().execute().data
    if p and p["telegram_id"]:
        try:
            await bot.send_message(p["telegram_id"], f"{N[p['language']][key]}: {text}")
        except Exception:
            logging.exception("push failed")


async def notify_loop(bot: Bot):
    """Yangi xaridor va saqlash so'rovlari haqida egasiga xabar yuboradi."""
    while True:
        try:
            r = (sb.table("inquiries").select("id,offered_price,message,products(title,seller_id)")
                 .eq("notified", False).limit(50).execute())
            for x in r.data:
                if x.get("products"):
                    await push(bot, x["products"]["seller_id"], 0, f"{x['products']['title']} {x['message'] or ''}")
                sb.table("inquiries").update({"notified": True}).eq("id", x["id"]).execute()
            r = (sb.table("storage_requests").select("id,product_type,quantity_tons,warehouses(name,owner_id)")
                 .eq("notified", False).limit(50).execute())
            for x in r.data:
                if x.get("warehouses"):
                    await push(bot, x["warehouses"]["owner_id"], 1,
                               f"{x['warehouses']['name']} · {x['product_type']} · {x['quantity_tons']} t")
                sb.table("storage_requests").update({"notified": True}).eq("id", x["id"]).execute()
        except Exception:
            logging.exception("notify loop")
        await asyncio.sleep(30)


async def reminder_loop(bot: Bot):
    """Har daqiqada muddati kelgan vazifalar uchun eslatma yuboradi."""
    while True:
        try:
            now = datetime.now(timezone.utc).isoformat()
            r = (sb.table("tasks").select("id,title,user_id").eq("done", False)
                 .eq("reminded", False).lte("due_at", now).limit(50).execute())
            for t in r.data:
                p = sb.table("profiles").select("telegram_id,language").eq("id", t["user_id"]).single().execute().data
                if p and p["telegram_id"]:
                    try:
                        await bot.send_message(p["telegram_id"], f"{T[p['language']]['reminder']}: {t['title']}")
                    except Exception:
                        logging.exception("send failed")
                sb.table("tasks").update({"reminded": True}).eq("id", t["id"]).execute()
        except Exception:
            logging.exception("reminder loop")
        await asyncio.sleep(60)


async def start_http():
    """Render.com uchun soxta HTTP server (Health Check)."""
    async def health(_):
        return web.Response(text="ok")
    app = web.Application()
    app.router.add_get("/", health)
    runner = web.AppRunner(app)
    await runner.setup()
    await web.TCPSite(runner, "0.0.0.0", int(os.environ.get("PORT", "10000"))).start()


async def main():
    bot = Bot(os.environ["BOT_TOKEN"])
      await start_http()
    dp = Dispatcher()
    dp.include_router(router)
    
    # Background tasklar
    asyncio.create_task(start_http())  # <--- HTTP port ochish funksiyasi qo'shildi
    asyncio.create_task(reminder_loop(bot))
    asyncio.create_task(notify_loop(bot))
    
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
