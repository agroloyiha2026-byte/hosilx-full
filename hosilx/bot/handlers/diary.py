"""Dala daftari: dalalar va qaydlar (ekish, sug'orish, o'g'itlash, dori, mehnat, hosil, xarajat, kuzatuv) + yillik xulosa.
Ma'lumotlar faqat egasiga tegishli (user_id filtri repositoriyada); qayd takroriy bosishdan (client_ref) himoyalangan."""
from __future__ import annotations

from decimal import Decimal
from uuid import uuid4

from aiogram import F, Router
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery, Message

from ..services.summary import today_uz
from ..states import Diary
from ..ui import b, cancel_row, esc, kb, main_menu, menu_texts, require_user, send, show
from ..utils.diary import ENTRY_KINDS, UNITS, DiarySummary, summarize, summarize_by_field
from ..utils.finance import fmt_money
from ..utils.validators import clean_text, parse_amount, parse_date
from .common import is_uuid

router = Router(name="diary")
UID = r"[0-9a-f-]{36}"
FIELD_STEPS = (("name", "text", True), ("area_ha", "num", False), ("crop", "text", False), ("sown_on", "date", False))
ENTRY_STEPS = (("kind", "choice", True), ("entry_date", "date", True), ("amount", "num", False), ("unit", "choice", False), ("cost", "num", False), ("note", "text", False))
MAX_LEN = {"name": 80, "crop": 60, "note": 300}


def steps(flow: str):
    return FIELD_STEPS if flow == "field" else ENTRY_STEPS


def part(data: str, n: int) -> str:
    p = data.split(":")
    return p[n] if len(p) > n else ""


def _sum_text(s: DiarySummary, t) -> str:
    out = [f"{t('dy_entries')}: {s.count}"]
    if s.harvest:
        out.append(f"🌾 {t('dy_harvest')}: " + ", ".join(f"{fmt_money(v)} {t('du_' + u)}" for u, v in s.harvest.items()))
    if s.cost:
        out.append(f"💸 {t('dy_cost')}: " + ", ".join(f"{fmt_money(v)} {c}" for c, v in s.cost.items()))
    return "\n".join(out)


# ------------------------------------------------------------------ bosh panel, dalalar
@router.message(F.text.in_(menu_texts("m_diary")))
async def h_diary(message: Message, state: FSMContext, user, t, db_ok):
    await state.clear()
    if not await require_user(message, user, t, db_ok):
        return
    await message.answer(t("dy_menu"), reply_markup=kb([[b(t("dy_add_entry"), "dy:e"), b(t("dy_fields"), "dy:fl")], [b(t("dy_add_field"), "dy:fa"), b(t("dy_summary"), "dy:sum")]]))


@router.callback_query(F.data == "dy:fl")
async def cb_fields(cb: CallbackQuery, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    rows = await repo.fields(user["id"])
    body = "\n".join(f"{i + 1}. <b>{esc(r['name'])}</b>" + (f" · {esc(r['crop'])}" if r.get("crop") else "") + (f" · {fmt_money(Decimal(str(r['area_ha'])))} ga" if r.get("area_ha") else "")
                     for i, r in enumerate(rows)) or t("dy_no_fields")
    markup = [[b(f"{i + 1}. {str(r['name'])[:30]}", f"dy:f:{r['id']}")] for i, r in enumerate(rows)]
    await show(cb, t("dy_fields") + "\n\n" + body, kb(markup + [[b(t("dy_add_field"), "dy:fa")]]))


@router.callback_query(F.data.regexp(rf"^dy:f:{UID}$"))
async def cb_field(cb: CallbackQuery, repo, user, t, lang, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    fid = part(cb.data, 2)
    f = await repo.get_field(user["id"], fid)  # faqat o'z dalasi
    if not f:
        return await cb.answer(t("listing_gone"), show_alert=True)
    entries = await repo.field_entries(user["id"], fid, 8)
    lines = [f"{e['entry_date']} · {t('dk_' + e['kind'])}" + (f" · {fmt_money(Decimal(str(e['amount'])))} {t('du_' + e['unit'])}" if e.get("amount") is not None and e.get("unit") else "")
             + (f" · {fmt_money(Decimal(str(e['cost'])))} {e['currency']}" if e.get("cost") is not None else "") + (f"\n   {esc(e['note'])}" if e.get("note") else "") for e in entries]
    head = f"<b>{esc(f['name'])}</b>" + (f" · {esc(f['crop'])}" if f.get("crop") else "") + (f"\n{t('dl_area_ha')}: {fmt_money(Decimal(str(f['area_ha'])))}" if f.get("area_ha") else "") + (f"\n{t('dl_sown_on')}: {f['sown_on']}" if f.get("sown_on") else "")
    await send(cb, head + "\n\n" + ("\n".join(lines) or t("dy_no_entries")),
               kb([[b(t("dy_add_entry"), f"dy:ea:{fid}")], [b(t("delete"), f"dy:fd:{fid}")], [b(t("back"), "dy:fl")]]))


@router.callback_query(F.data.regexp(rf"^dy:fd:{UID}$"))
async def cb_fd(cb: CallbackQuery, user, t, db_ok):
    if await require_user(cb, user, t, db_ok):
        fid = part(cb.data, 2)
        await show(cb, t("dy_confirm_delete"), kb([[b(t("confirm"), f"dy:fd2:{fid}"), b(t("cancel"), f"dy:f:{fid}")]]))


@router.callback_query(F.data.regexp(rf"^dy:fd2:{UID}$"))
async def cb_fd2(cb: CallbackQuery, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    ok = await repo.delete_field(user["id"], part(cb.data, 2))
    await send(cb, t("deleted") if ok else t("listing_gone"), main_menu(t))


# ------------------------------------------------------------------ umumiy qadamli mexanizm (dala qo'shish va qayd qo'shish)
async def ask(event, state: FSMContext, t, flow: str, idx: int) -> None:
    key, kind, required = steps(flow)[idx]
    await state.set_state(Diary.step)
    await state.update_data(flow=flow, idx=idx)
    rows = []
    if kind == "choice":
        opts, pre = (ENTRY_KINDS, "dk_") if key == "kind" else (UNITS, "du_")
        rows = [[b(t(pre + c), f"dy:ck:{c}") for c in opts[i:i + 2]] for i in range(0, len(opts), 2)]
    elif kind == "date":
        rows = [[b(t("today"), "dy:today")]]
    tail = ([] if required else [b(t("skip"), "dy:skip")]) + [b(t("cancel"), "x:cancel")]
    await send(event, t("ask_field", label=t(f"dl_{key}"), hint=t("hint_num") if kind == "num" else (t("hint_date") if kind == "date" else "")), kb(rows + [tail]))


async def advance(event, state: FSMContext, repo, user, t, lang, value) -> None:
    d = await state.get_data()
    flow, idx = d["flow"], d["idx"]
    st = steps(flow)
    vals = dict(d.get("vals", {}))
    if value is not None:
        vals[st[idx][0]] = value
    await state.update_data(vals=vals)
    nxt = idx + 1
    while nxt < len(st) and st[nxt][0] == "unit" and "amount" not in vals:  # birlik faqat miqdor kiritilsa so'raladi
        nxt += 1
    if nxt < len(st):
        return await ask(event, state, t, flow, nxt)
    if flow == "field":
        await state.clear()
        await repo.add_field(user["id"], {k: v for k, v in vals.items() if k in ("name", "area_ha", "crop", "sown_on")})
        return await send(event, t("dy_field_saved"), main_menu(t))
    tok = uuid4().hex
    await state.update_data(tok=tok)
    await state.set_state(Diary.confirm)
    f = await repo.get_field(user["id"], vals.get("field_id", ""))
    text = (f"<b>{t('preview_title')}</b>\n🌾 {esc(f['name'] if f else '—')}\n{t('dk_' + vals['kind'])} · {vals['entry_date']}"
            + (f"\n{fmt_money(Decimal(str(vals['amount'])))} {t('du_' + vals['unit'])}" if vals.get("amount") is not None and vals.get("unit") else "")
            + (f"\n💸 {fmt_money(Decimal(str(vals['cost'])))} UZS" if vals.get("cost") is not None else "") + (f"\n📝 {esc(vals['note'])}" if vals.get("note") else ""))
    await send(event, text, kb([[b(t("confirm"), f"dy:ok:{tok}")], cancel_row(t)]))


@router.callback_query(F.data == "dy:fa")
async def cb_add_field(cb: CallbackQuery, state: FSMContext, user, t, lang, db_ok):
    if await require_user(cb, user, t, db_ok):
        await state.set_data({"flow": "field", "idx": 0, "vals": {}})
        await ask(cb, state, t, "field", 0)


@router.callback_query(F.data == "dy:e")
async def cb_entry(cb: CallbackQuery, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    rows = await repo.fields(user["id"])
    if not rows:
        return await send(cb, t("dy_need_field"), kb([[b(t("dy_add_field"), "dy:fa")]]))
    await send(cb, t("dy_pick_field"), kb([[b(str(r["name"])[:40], f"dy:ea:{r['id']}")] for r in rows] + [cancel_row(t)]))


@router.callback_query(F.data.regexp(rf"^dy:ea:{UID}$"))
async def cb_entry_for(cb: CallbackQuery, state: FSMContext, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    fid = part(cb.data, 2)
    if not await repo.get_field(user["id"], fid):  # faqat o'z dalasiga qayd
        return await cb.answer(t("listing_gone"), show_alert=True)
    await state.set_data({"flow": "entry", "idx": 0, "vals": {"field_id": fid}})
    await ask(cb, state, t, "entry", 0)


@router.callback_query(Diary.step, F.data.startswith("dy:ck:"))
async def cb_choice(cb: CallbackQuery, state: FSMContext, repo, user, t, lang):
    d = await state.get_data()
    key, kind, _ = steps(d["flow"])[d["idx"]]
    val = part(cb.data, 2)
    if kind != "choice" or val not in (ENTRY_KINDS if key == "kind" else UNITS):
        return await cb.answer()
    await advance(cb, state, repo, user, t, lang, val)


@router.callback_query(Diary.step, F.data == "dy:today")
async def cb_today(cb: CallbackQuery, state: FSMContext, repo, user, t, lang):
    d = await state.get_data()
    if steps(d["flow"])[d["idx"]][1] != "date":
        return await cb.answer()
    await advance(cb, state, repo, user, t, lang, today_uz().isoformat())


@router.callback_query(Diary.step, F.data == "dy:skip")
async def cb_skip(cb: CallbackQuery, state: FSMContext, repo, user, t, lang):
    d = await state.get_data()
    if steps(d["flow"])[d["idx"]][2]:
        return await cb.answer(t("required_field"), show_alert=True)
    await advance(cb, state, repo, user, t, lang, None)


@router.message(Diary.step)
async def msg_step(message: Message, state: FSMContext, repo, user, t, lang):
    d = await state.get_data()
    key, kind, required = steps(d["flow"])[d["idx"]]
    if kind == "text":
        v = clean_text(message.text, MAX_LEN.get(key, 100))
        if len(v) < 1 or (required and len(v) < 2):
            return await message.answer(t("err_text_short"))
    elif kind == "num":
        a = parse_amount(message.text, Decimal("100000") if key == "area_ha" else Decimal("1000000000000"))
        if a is None:
            return await message.answer(t("err_amount"))
        v = float(a)
    elif kind == "date":
        dt = parse_date(message.text, today_uz())
        if dt is None:
            return await message.answer(t("err_date"))
        v = dt.isoformat()
    else:
        return await message.answer(t("use_buttons"))
    await advance(message, state, repo, user, t, lang, v)


@router.callback_query(Diary.confirm, F.data.startswith("dy:ok:"))
async def cb_ok(cb: CallbackQuery, state: FSMContext, repo, user, t):
    d = await state.get_data()
    if part(cb.data, 2) != d.get("tok") or not user:
        return await cb.answer(t("stale"), show_alert=True)
    vals = d.get("vals", {})
    await state.clear()  # takroriy bosish: holat yo'q; bazada (user_id, client_ref) unique
    if not await repo.get_field(user["id"], vals.get("field_id", "")):
        return await send(cb, t("listing_gone"), main_menu(t))
    data = {k: vals[k] for k in ("field_id", "kind", "entry_date", "amount", "unit", "cost", "note") if vals.get(k) is not None}
    await repo.add_field_entry(user["id"], {**data, "currency": "UZS"}, f"tg:{d['tok']}")
    await send(cb, t("dy_entry_saved"), main_menu(t))


# ------------------------------------------------------------------ yillik xulosa
@router.callback_query(F.data == "dy:sum")
async def cb_summary(cb: CallbackQuery, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    today = today_uz()
    entries = await repo.entries_since(user["id"], today.replace(month=1, day=1).isoformat())
    if not entries:
        return await send(cb, t("dy_no_entries"))
    names = {f["id"]: f["name"] for f in await repo.fields(user["id"])}
    parts = [f"📊 <b>{t('dy_summary')}: {today.year}</b>\n{_sum_text(summarize(entries), t)}"]
    for fid, s in summarize_by_field(entries).items():
        parts.append(f"<b>{esc(names.get(fid, '—'))}</b>\n{_sum_text(s, t)}")
    await send(cb, "\n\n".join(parts))
