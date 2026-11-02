from __future__ import annotations

from aiogram import F, Router
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery, Message

from ..states import FreeT, Search, Stor
from ..ui import b, cancel_row, esc, kb, main_menu, menu_texts, pager, regions_kb, require_user, send, show
from ..utils.regions import region_by_index, region_label
from ..utils.validators import clean_text, parse_amount
from .common import fmt_dt, fmt_price, is_uuid

router = Router(name="warehouses")
SIZE = 5


def is_owner(user) -> bool:
    return bool(user) and user.get("role") in ("warehouse_owner", "admin")


async def render(event, state, repo, t, lang, user, page=0):
    f = (await state.get_data()).get("wh", {})
    rows, more = await repo.warehouses(f.get("q", ""), f.get("reg"), page, SIZE)
    head = t("wh_title") + (f"\n📍 {esc(region_label(f['reg'], lang))}" if f.get("reg") else "") + (f"\n🔎 {esc(f['q'])}" if f.get("q") else "")
    body = "\n".join(f"{i + 1}. <b>{esc(w['name'])}</b>\n   {esc(region_label(w['region'], lang))} · {t('st_' + w['storage_type'])} · {t('free')}: {float(w['free_tons']):g}/{float(w['capacity_tons']):g} {t('tons')}"
                     for i, w in enumerate(rows)) or t("no_warehouses")
    markup = [[b(f"{i + 1}. {w['name'][:30]}", f"wh:d:{w['id']}")] for i, w in enumerate(rows)]
    if pager("wh:pg", page, more):
        markup.append(pager("wh:pg", page, more))
    markup.append([b(t("f_search"), "wh:f:q"), b(t("f_region"), "wh:f:reg"), b(t("f_clear"), "wh:f:clr")])
    if is_owner(user):
        markup.append([b(t("my_warehouses"), "wh:mine"), b(t("storage_requests"), "wh:reqs")])
    await show(event, head + "\n\n" + body, kb(markup))


@router.message(F.text.in_(menu_texts("m_wh")))
async def h_wh(message: Message, state: FSMContext, repo, t, lang, user):
    await state.clear()
    await render(message, state, repo, t, lang, user, 0)


@router.callback_query(F.data.startswith("wh:pg:"))
async def cb_page(cb: CallbackQuery, state, repo, t, lang, user):
    a = cb.data.split(":")[2]
    await render(cb, state, repo, t, lang, user, int(a) if a.isdigit() else 0)


@router.callback_query(F.data == "wh:f:q")
async def cb_q(cb: CallbackQuery, state, t):
    await state.set_state(Search.wh_query)
    await show(cb, t("ask_search"), kb([cancel_row(t)]))


@router.message(Search.wh_query)
async def msg_q(message: Message, state, repo, t, lang, user):
    wh = {**(await state.get_data()).get("wh", {}), "q": clean_text(message.text, 60)}
    await state.clear()
    await state.update_data(wh=wh)
    await render(message, state, repo, t, lang, user, 0)


@router.callback_query(F.data == "wh:f:reg")
async def cb_reg(cb: CallbackQuery, t, lang):
    await show(cb, t("pick_region"), regions_kb("wh:r", lang, [b(t("back"), "wh:pg:0")]))


@router.callback_query(F.data.startswith("wh:r:"))
async def cb_set_reg(cb: CallbackQuery, state, repo, t, lang, user):
    a = cb.data.split(":")[2]
    region = region_by_index(int(a)) if a.isdigit() else None
    if region:
        await state.update_data(wh={**(await state.get_data()).get("wh", {}), "reg": region})
    await render(cb, state, repo, t, lang, user, 0)


@router.callback_query(F.data == "wh:f:clr")
async def cb_clear(cb: CallbackQuery, state, repo, t, lang, user):
    await state.update_data(wh={})
    await render(cb, state, repo, t, lang, user, 0)


@router.callback_query(F.data.startswith("wh:d:"))
async def cb_detail(cb: CallbackQuery, repo, t, lang):
    wid = cb.data.split(":", 2)[2]
    w = await repo.warehouse(wid) if is_uuid(wid) else None
    if not w:
        return await cb.answer(t("product_gone"), show_alert=True)
    price = t("price_na") if w.get("price_per_ton_month") is None else f"{fmt_price(w['price_per_ton_month'], w['currency'], t('per_ton_month'))}"
    text = (f"<b>{esc(w['name'])}</b>\n{esc(region_label(w['region'], lang))}{(' · ' + esc(w['address'])) if w.get('address') else ''}\n{t('st_' + w['storage_type'])}\n"
            f"{t('capacity')}: {float(w['capacity_tons']):g} {t('tons')} · {t('free')}: {float(w['free_tons']):g} {t('tons')}\n{price}"
            + (f"\n{t('accepted')}: {esc(', '.join(w['accepted_products']))}" if w.get("accepted_products") else "")
            + (f"\n{t('conditions')}: {esc(w['conditions'])}" if w.get("conditions") else "") + (f"\n{t('contact')}: {esc(w['contact_phone'])}" if w.get("contact_phone") else ""))
    await send(cb, text, kb([[b(t("request_storage"), f"wh:q:{wid}")], [b(t("report"), f"rp:w:{wid}")], [b(t("back"), "wh:pg:0")]]))


@router.callback_query(F.data.startswith("wh:q:"))
async def cb_request(cb: CallbackQuery, state: FSMContext, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    wid = cb.data.split(":", 2)[2]
    w = await repo.warehouse(wid) if is_uuid(wid) else None
    if not w:
        return await cb.answer(t("product_gone"), show_alert=True)
    if w["owner_id"] == user["id"]:
        return await cb.answer(t("own_warehouse"), show_alert=True)
    if float(w["free_tons"]) <= 0:
        return await cb.answer(t("no_free_space"), show_alert=True)
    await state.set_state(Stor.ptype)
    await state.update_data(wid=wid, free=float(w["free_tons"]))
    await send(cb, t("ask_storage_type"), kb([cancel_row(t)]))


@router.message(Stor.ptype)
async def msg_ptype(message: Message, state, t):
    v = clean_text(message.text, 60)
    if len(v) < 2:
        return await message.answer(t("err_text_short"))
    await state.update_data(ptype=v)
    await state.set_state(Stor.tons)
    await message.answer(t("ask_tons"), reply_markup=kb([cancel_row(t)]))


@router.message(Stor.tons)
async def msg_tons(message: Message, state, t):
    v = parse_amount(message.text)
    d = await state.get_data()
    if v is None or float(v) > d.get("free", 0):  # bo'sh joydan ko'p so'rab bo'lmaydi
        return await message.answer(t("err_tons"))
    await state.update_data(tons=float(v))
    await state.set_state(Stor.message)
    await message.answer(t("ask_note"), reply_markup=kb([[b(t("skip"), "stor:skip")], cancel_row(t)]))


async def _finish(event, state, repo, user, t, note):
    d = await state.get_data()
    await state.clear()
    w = await repo.warehouse(d.get("wid", ""))
    if not w or w["owner_id"] == user["id"] or d.get("tons", 0) > float(w["free_tons"]):
        return await send(event, t("err_tons"), main_menu(t))
    await repo.request_storage(w["id"], user["id"], d["ptype"], d["tons"], note)
    await send(event, t("storage_sent"), main_menu(t))


@router.callback_query(Stor.message, F.data == "stor:skip")
async def cb_skip(cb: CallbackQuery, state, repo, user, t):
    await _finish(cb, state, repo, user, t, None)


@router.message(Stor.message)
async def msg_note(message: Message, state, repo, user, t):
    await _finish(message, state, repo, user, t, clean_text(message.text, 300) or None)


# ---- ombor egasi ----
@router.callback_query(F.data == "wh:mine")
async def cb_mine(cb: CallbackQuery, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok) or not is_owner(user):
        return
    rows = await repo.my_warehouses(user["id"])
    text = t("my_warehouses") + "\n\n" + ("\n".join(f"<b>{esc(w['name'])}</b> · {t('free')}: {float(w['free_tons']):g}/{float(w['capacity_tons']):g} {t('tons')}" for w in rows) or t("no_warehouses"))
    await show(cb, text, kb([[b(f"✏️ {w['name'][:28]}", f"wh:ft:{w['id']}")] for w in rows] + [[b(t("back"), "wh:pg:0")]]))


@router.callback_query(F.data.startswith("wh:ft:"))
async def cb_ft(cb: CallbackQuery, state, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok) or not is_owner(user):
        return
    wid = cb.data.split(":", 2)[2]
    if not is_uuid(wid):
        return await cb.answer()
    await state.set_state(FreeT.tons)
    await state.update_data(wid=wid)
    await send(cb, t("ask_free_tons"), kb([cancel_row(t)]))


@router.message(FreeT.tons)
async def msg_ft(message: Message, state, repo, user, t):
    v = parse_amount(message.text)
    wid = (await state.get_data()).get("wid", "")
    if v is None and (message.text or "").strip() != "0":
        return await message.answer(t("err_amount"))
    ok = await repo.set_free_tons(user["id"], wid, float(v or 0))  # faqat o'z omboringiz va sig'imdan oshmasin
    await state.clear()
    await message.answer(t("saved_ok") if ok else t("err_tons"), reply_markup=main_menu(t))


@router.callback_query(F.data == "wh:reqs")
async def cb_reqs(cb: CallbackQuery, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok) or not is_owner(user):
        return
    rows = await repo.wh_requests(user["id"])
    if not rows:
        return await show(cb, t("no_requests"), kb([[b(t("back"), "wh:pg:0")]]))
    text = t("storage_requests") + "\n\n" + "\n\n".join(f"{i + 1}. <b>{esc(r['product_type'])}</b> · {float(r['quantity_tons']):g} {t('tons')} · {fmt_dt(r['created_at'])}" + (f"\n{esc(r['message'])}" if r.get("message") else "") for i, r in enumerate(rows))
    markup = [[b(f"✅ {i + 1}", f"wh:rs:{r['id']}:a"), b(f"❌ {i + 1}", f"wh:rs:{r['id']}:r")] for i, r in enumerate(rows)]
    await show(cb, text, kb(markup + [[b(t("back"), "wh:pg:0")]]))


@router.callback_query(F.data.startswith("wh:rs:"))
async def cb_req_status(cb: CallbackQuery, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok) or not is_owner(user):
        return
    _, _, rid, code = cb.data.split(":")
    ok = is_uuid(rid) and code in ("a", "r") and await repo.set_request_status(user["id"], rid, "accepted" if code == "a" else "rejected")
    await cb.answer(t("saved_ok") if ok else t("err_generic"), show_alert=not ok)
    await cb_reqs(cb, repo, user, t, db_ok)
