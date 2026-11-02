"""Bozor: qidirish, filtrlar, mahsulot, sotuvchi, so'rov, o'z e'lonlari, e'lon qo'shish."""
from __future__ import annotations

import base64  # noqa: F401
from uuid import uuid4

from aiogram import Bot, F, Router
from aiogram.exceptions import TelegramBadRequest
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery, Message

from ..states import AddProd, Inq, Search
from ..ui import b, cancel_row, esc, kb, main_menu, menu_texts, pager, regions_kb, require_user, send, show
from ..utils.finance import fmt_money
from ..utils.regions import region_by_index, region_label
from ..utils.validators import clean_text, parse_amount
from .common import fmt_price, is_seller, is_uuid

router = Router(name="market")
SIZE = 5
UNITS = ("kg", "tonna", "dona", "litr")


def cat_name(c: dict, lang: str) -> str:
    return c.get(f"name_{lang}") or c.get("name_uz") or c["slug"]


async def render_list(event, state: FSMContext, repo, t, lang: str, user, page: int = 0) -> None:
    f = (await state.get_data()).get("mk", {})
    rows, more = await repo.products(f.get("q", ""), f.get("cat"), f.get("reg"), page, SIZE)
    chips = [x for x in (f.get("q") and f"🔎 {esc(f['q'])}", f.get("cat") and f"🗂 {esc(f['cat'])}", f.get("reg") and f"📍 {esc(region_label(f['reg'], lang))}") if x]
    head = t("market_title") + (("\n" + " · ".join(chips)) if chips else "")
    if not rows:
        text = head + "\n\n" + t("no_products")
    else:
        text = head + "\n\n" + "\n".join(f"{i + 1}. <b>{esc(p['title'])}</b>\n   {fmt_price(p['price'], p['currency'], p['unit'])} · {esc(region_label(p['region'], lang))}" for i, p in enumerate(rows))
    markup = [[b(f"{i + 1}. {p['title'][:30]}", f"mk:p:{p['id']}")] for i, p in enumerate(rows)]
    pg = pager("mk:pg", page, more)
    if pg:
        markup.append(pg)
    markup.append([b(t("f_search"), "mk:f:q"), b(t("f_category"), "mk:f:cat"), b(t("f_region"), "mk:f:reg")])
    bottom = [b(t("f_clear"), "mk:f:clr")]
    if is_seller(user):
        bottom += [b(t("my_products"), "mk:mine:0"), b(t("add_product"), "mk:add")]
    markup.append(bottom)
    await show(event, text, kb(markup))


@router.message(F.text.in_(menu_texts("m_market")))
async def h_market(message: Message, state: FSMContext, repo, t, lang, user):
    await state.clear()
    await render_list(message, state, repo, t, lang, user, 0)


@router.callback_query(F.data.startswith("mk:pg:"))
async def cb_page(cb: CallbackQuery, state, repo, t, lang, user):
    arg = cb.data.split(":")[2]
    await render_list(cb, state, repo, t, lang, user, int(arg) if arg.isdigit() else 0)


@router.callback_query(F.data == "mk:f:q")
async def cb_filter_q(cb: CallbackQuery, state: FSMContext, t):
    await state.set_state(Search.query)
    await show(cb, t("ask_search"), kb([cancel_row(t)]))


@router.message(Search.query)
async def msg_search(message: Message, state, repo, t, lang, user):
    q = clean_text(message.text, 60)
    mk = {**(await state.get_data()).get("mk", {}), "q": q}
    await state.clear()
    await state.update_data(mk=mk)
    await render_list(message, state, repo, t, lang, user, 0)


@router.callback_query(F.data == "mk:f:cat")
async def cb_filter_cat(cb: CallbackQuery, repo, t, lang):
    cats = await repo.categories()
    await show(cb, t("pick_category"), kb([[b(cat_name(c, lang), f"mk:c:{c['slug']}")] for c in cats] + [[b(t("back"), "mk:pg:0")]]))


@router.callback_query(F.data.startswith("mk:c:"))
async def cb_set_cat(cb: CallbackQuery, state, repo, t, lang, user):
    slug = cb.data.split(":", 2)[2]
    if slug not in {c["slug"] for c in await repo.categories()}:  # callback_data'ga ishonilmaydi: bazadagi ro'yxat bilan solishtiriladi
        return await cb.answer()
    await state.update_data(mk={**(await state.get_data()).get("mk", {}), "cat": slug})
    await render_list(cb, state, repo, t, lang, user, 0)


@router.callback_query(F.data == "mk:f:reg")
async def cb_filter_reg(cb: CallbackQuery, t, lang):
    await show(cb, t("pick_region"), regions_kb("mk:r", lang, [b(t("back"), "mk:pg:0")]))


@router.callback_query(F.data.startswith("mk:r:"))
async def cb_set_reg(cb: CallbackQuery, state, repo, t, lang, user):
    arg = cb.data.split(":")[2]
    region = region_by_index(int(arg)) if arg.isdigit() else None
    if region:
        await state.update_data(mk={**(await state.get_data()).get("mk", {}), "reg": region})
    await render_list(cb, state, repo, t, lang, user, 0)


@router.callback_query(F.data == "mk:f:clr")
async def cb_clear(cb: CallbackQuery, state, repo, t, lang, user):
    await state.update_data(mk={})
    await render_list(cb, state, repo, t, lang, user, 0)


@router.callback_query(F.data.startswith("mk:p:"))
async def cb_product(cb: CallbackQuery, repo, t, lang):
    pid = cb.data.split(":", 2)[2]
    p = await repo.product(pid) if is_uuid(pid) else None
    if not p:
        return await cb.answer(t("product_gone"), show_alert=True)
    seller = await repo.seller(p["seller_id"])
    text = (f"<b>{esc(p['title'])}</b>\n{fmt_price(p['price'], p['currency'], p['unit'])}\n{t('qty')}: {fmt_money(__import__('decimal').Decimal(str(p['quantity'])))} {esc(p['unit'])}\n"
            f"{t('region')}: {esc(region_label(p['region'], lang))}\n" + (f"\n{esc((p.get('description') or '')[:500])}\n" if p.get("description") else "") +
            f"\n{t('seller')}: {esc((seller or {}).get('full_name') or '—')}")
    markup = kb([[b(t("send_inquiry"), f"mk:i:{pid}"), b(t("seller_profile"), f"mk:s:{p['seller_id']}")], [b(t("report"), f"rp:p:{pid}")], [b(t("back"), "mk:pg:0")]])
    imgs = sorted(p.get("product_images") or [], key=lambda x: x.get("sort_order") or 0)
    url = p.get("image_url") or (imgs[0]["url"] if imgs else None)
    if url:
        try:  # Telegram rasmni URL orqali yuklay olmasa, matnga qaytamiz
            await cb.message.answer_photo(url, caption=text[:1000], reply_markup=markup)
            return await cb.answer()
        except TelegramBadRequest:
            pass
    await send(cb, text, markup)


@router.callback_query(F.data.startswith("mk:s:"))
async def cb_seller(cb: CallbackQuery, repo, t, lang):
    sid = cb.data.split(":", 2)[2]
    s = await repo.seller(sid) if is_uuid(sid) else None
    if not s:
        return await cb.answer(t("seller_gone"), show_alert=True)
    # faqat ommaviy ma'lumot: ism va hudud (telefon, email, moliya, koordinata ko'rsatilmaydi)
    await send(cb, f"<b>{esc(s.get('full_name') or '—')}</b>\n{t('region')}: {esc(region_label(s.get('region') or '', lang) or '—')}")


# ---- sotuvchiga so'rov ----
@router.callback_query(F.data.startswith("mk:i:"))
async def cb_inquiry(cb: CallbackQuery, state: FSMContext, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    pid = cb.data.split(":", 2)[2]
    p = await repo.product(pid) if is_uuid(pid) else None
    if not p:
        return await cb.answer(t("product_gone"), show_alert=True)
    if p["seller_id"] == user["id"]:
        return await cb.answer(t("own_product"), show_alert=True)
    await state.set_state(Inq.message)
    await state.update_data(pid=pid)
    await send(cb, t("ask_inquiry"), kb([cancel_row(t)]))


@router.message(Inq.message)
async def msg_inq_text(message: Message, state, t):
    text = clean_text(message.text, 500)
    if len(text) < 3:
        return await message.answer(t("err_text_short"))
    await state.update_data(msg=text)
    await state.set_state(Inq.offer)
    await message.answer(t("ask_offer"), reply_markup=kb([[b(t("skip"), "inq:skip")], cancel_row(t)]))


async def _finish_inquiry(event, state, repo, user, t, offer):
    d = await state.get_data()
    p = await repo.product(d.get("pid", ""))  # yuborish paytida qayta tekshiriladi
    await state.clear()
    if not p or p["seller_id"] == user["id"]:
        return await send(event, t("product_gone"), main_menu(t))
    await repo.create_inquiry(p["id"], user["id"], d.get("msg"), float(offer) if offer is not None else None)
    await send(event, t("inquiry_sent"), main_menu(t))


@router.callback_query(Inq.offer, F.data == "inq:skip")
async def cb_offer_skip(cb: CallbackQuery, state, repo, user, t):
    await _finish_inquiry(cb, state, repo, user, t, None)


@router.message(Inq.offer)
async def msg_offer(message: Message, state, repo, user, t):
    v = parse_amount(message.text)
    if v is None:
        return await message.answer(t("err_amount"))
    await _finish_inquiry(message, state, repo, user, t, v)


# ---- o'z e'lonlari ----
async def _render_mine(event, repo, user, t, page: int) -> None:
    rows, more = await repo.my_products(user["id"], page, SIZE)
    text = t("my_products") + "\n\n" + ("\n".join(f"{i + 1}. <b>{esc(p['title'])}</b> · {fmt_price(p['price'], p['currency'], p['unit'])} · {t('st_' + p['status'])}" for i, p in enumerate(rows)) or t("no_products"))
    markup = [[b(f"{'🙈' if p['status'] == 'active' else '👁'} {p['title'][:26]}", f"mk:tg:{p['id']}")] for p in rows]
    if pager("mk:mine", page, more):
        markup.append(pager("mk:mine", page, more))
    markup.append([b(t("back"), "mk:pg:0")])
    await show(event, text, kb(markup))


@router.callback_query(F.data.startswith("mk:mine:"))
async def cb_mine(cb: CallbackQuery, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    if not is_seller(user):
        return await cb.answer(t("ah_not_for_role"), show_alert=True)
    arg = cb.data.split(":")[2]
    await _render_mine(cb, repo, user, t, int(arg) if arg.isdigit() else 0)


@router.callback_query(F.data.startswith("mk:tg:"))
async def cb_toggle(cb: CallbackQuery, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    pid = cb.data.split(":", 2)[2]
    new = await repo.toggle_product(user["id"], pid) if is_uuid(pid) else None  # faqat o'zining e'loni
    await cb.answer(t("toggled") if new else t("product_gone"), show_alert=not new)
    await _render_mine(cb, repo, user, t, 0)  # aiogram obyektlari o'zgarmas (frozen): cb.data ni o'zgartirib bo'lmaydi


# ---- e'lon qo'shish (FSM) ----
@router.callback_query(F.data == "mk:add")
async def ap_start(cb: CallbackQuery, state: FSMContext, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    if not is_seller(user):
        return await cb.answer(t("ah_not_for_role"), show_alert=True)
    await state.set_state(AddProd.title)
    await state.update_data(ap={})
    await send(cb, t("ap_title"), kb([cancel_row(t)]))


async def _ap(state, **kw) -> dict:
    d = {**(await state.get_data()).get("ap", {}), **kw}
    await state.update_data(ap=d)
    return d


@router.message(AddProd.title)
async def ap_title(message: Message, state, t):
    v = clean_text(message.text, 100)
    if len(v) < 3:
        return await message.answer(t("err_text_short"))
    await _ap(state, title=v)
    await state.set_state(AddProd.ptype)
    await message.answer(t("ap_type"), reply_markup=kb([cancel_row(t)]))


@router.message(AddProd.ptype)
async def ap_ptype(message: Message, state, repo, t, lang):
    v = clean_text(message.text, 60).lower()
    if len(v) < 2:
        return await message.answer(t("err_text_short"))
    await _ap(state, product_type=v)
    await state.set_state(AddProd.category)
    cats = await repo.categories()
    await message.answer(t("pick_category"), reply_markup=kb([[b(cat_name(c, lang), f"ap:c:{c['slug']}")] for c in cats] + [cancel_row(t)]))


@router.callback_query(AddProd.category, F.data.startswith("ap:c:"))
async def ap_cat(cb: CallbackQuery, state, repo, t):
    slug = cb.data.split(":", 2)[2]
    if slug not in {c["slug"] for c in await repo.categories()}:
        return await cb.answer()
    await _ap(state, category=slug)
    await state.set_state(AddProd.price)
    await send(cb, t("ap_price"), kb([cancel_row(t)]))


@router.message(AddProd.price)
async def ap_price(message: Message, state, t):
    v = parse_amount(message.text)
    if v is None:
        return await message.answer(t("err_amount"))
    await _ap(state, price=float(v))
    await state.set_state(AddProd.currency)
    await message.answer(t("ap_currency"), reply_markup=kb([[b("UZS", "ap:cur:UZS"), b("USD", "ap:cur:USD")], cancel_row(t)]))


@router.callback_query(AddProd.currency, F.data.startswith("ap:cur:"))
async def ap_cur(cb: CallbackQuery, state, t):
    cur = cb.data.split(":")[2]
    if cur not in ("UZS", "USD"):
        return await cb.answer()
    await _ap(state, currency=cur)
    await state.set_state(AddProd.unit)
    await send(cb, t("ap_unit"), kb([[b(u, f"ap:u:{u}") for u in UNITS], cancel_row(t)]))


@router.callback_query(AddProd.unit, F.data.startswith("ap:u:"))
async def ap_unit(cb: CallbackQuery, state, t):
    u = cb.data.split(":")[2]
    if u not in UNITS:
        return await cb.answer()
    await _ap(state, unit=u)
    await state.set_state(AddProd.quantity)
    await send(cb, t("ap_qty"), kb([cancel_row(t)]))


@router.message(AddProd.quantity)
async def ap_qty(message: Message, state, t, lang):
    v = parse_amount(message.text)
    if v is None:
        return await message.answer(t("err_amount"))
    await _ap(state, quantity=float(v))
    await state.set_state(AddProd.region)
    await message.answer(t("pick_region"), reply_markup=regions_kb("ap:r", lang, cancel_row(t)))


@router.callback_query(AddProd.region, F.data.startswith("ap:r:"))
async def ap_region(cb: CallbackQuery, state, t):
    arg = cb.data.split(":")[2]
    region = region_by_index(int(arg)) if arg.isdigit() else None
    if not region:
        return await cb.answer()
    await _ap(state, region=region)
    await state.set_state(AddProd.photo)
    await send(cb, t("ap_photo"), kb([[b(t("skip"), "ap:skip")], cancel_row(t)]))


async def _ap_preview(event, state, t, lang):
    d = (await state.get_data()).get("ap", {})
    await state.set_state(AddProd.confirm)
    text = (f"<b>{esc(d['title'])}</b> ({esc(d['product_type'])})\n{fmt_price(d['price'], d['currency'], d['unit'])}\n{t('qty')}: {d['quantity']:g} {esc(d['unit'])}\n"
            f"{t('region')}: {esc(region_label(d['region'], lang))}\n{'📷 ' + t('photo_added') if d.get('image_url') else ''}")
    await send(event, text, kb([[b(t("confirm"), "ap:ok")], cancel_row(t)]))


@router.callback_query(AddProd.photo, F.data == "ap:skip")
async def ap_skip(cb: CallbackQuery, state, t, lang):
    await _ap_preview(cb, state, t, lang)


@router.message(AddProd.photo, F.photo)
async def ap_photo(message: Message, state, bot: Bot, repo, user, t, lang):
    photo = message.photo[-1]
    if (photo.file_size or 0) > 5 * 1024 * 1024:
        return await message.answer(t("err_photo"))
    data = (await bot.download(photo)).getvalue()
    url = await repo.upload_photo(user["id"], data, uuid4().hex)
    await _ap(state, image_url=url)
    await _ap_preview(message, state, t, lang)


@router.message(AddProd.photo)
async def ap_photo_bad(message: Message, t):
    await message.answer(t("err_photo"))


@router.callback_query(AddProd.confirm, F.data == "ap:ok")
async def ap_confirm(cb: CallbackQuery, state, repo, user, t):
    d = (await state.get_data()).get("ap", {})
    await state.clear()  # takroriy bosish ikkinchi e'lon yaratmaydi
    if not d or not is_seller(user):
        return await cb.answer()
    await repo.add_product(user["id"], {**d, "status": "active"})
    await send(cb, t("ap_done"), main_menu(t))
