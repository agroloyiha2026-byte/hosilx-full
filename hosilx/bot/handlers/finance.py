from __future__ import annotations

from uuid import uuid4

from aiogram import F, Router
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery, Message

from ..services.summary import period_totals, today_uz
from ..states import Fin
from ..ui import b, cancel_row, esc, kb, main_menu, menu_texts, require_user, send
from ..utils.finance import CURRENCIES, categories, fmt_money, month_bounds
from ..utils.validators import clean_text, parse_amount, parse_date

router = Router(name="finance")


def _cats_kb(kind: str, extended: bool, t):
    cs = categories(kind, extended)
    return kb([[b(t(f"fc_{c}"), f"fn:c:{c}") for c in cs[i:i + 2]] for i in range(0, len(cs), 2)] + [cancel_row(t)])


@router.message(F.text.in_(menu_texts("m_finance")))
async def h_fin(message: Message, state: FSMContext, user, t, db_ok):
    await state.clear()
    if not await require_user(message, user, t, db_ok):
        return
    await message.answer(t("fin_menu"), reply_markup=kb([[b(t("fin_income"), "fn:k:income"), b(t("fin_expense"), "fn:k:expense")],
                                                         [b(t("rep_month"), "fn:rep:m"), b(t("rep_prev"), "fn:rep:pm")], [b(t("rep_year"), "fn:rep:y")]]))


@router.callback_query(F.data.startswith("fn:k:"))
async def cb_kind(cb: CallbackQuery, state: FSMContext, user, t, settings, db_ok):
    kind = cb.data.split(":")[2]
    if not await require_user(cb, user, t, db_ok) or kind not in ("income", "expense"):
        return
    await state.set_state(Fin.category)
    await state.update_data(fn={"kind": kind, "token": uuid4().hex})
    await send(cb, t("pick_fin_category"), _cats_kb(kind, settings.finance_extended, t))


async def _fn(state, **kw) -> dict:
    d = {**(await state.get_data()).get("fn", {}), **kw}
    await state.update_data(fn=d)
    return d


@router.callback_query(Fin.category, F.data.startswith("fn:c:"))
async def cb_cat(cb: CallbackQuery, state, t, settings):
    d = (await state.get_data()).get("fn", {})
    cat = cb.data.split(":", 2)[2]
    if cat not in categories(d.get("kind", ""), settings.finance_extended):  # tur bo'yicha ruxsat etilgan turkumlar
        return await cb.answer()
    await _fn(state, category=cat)
    await state.set_state(Fin.amount)
    await send(cb, t("ask_amount"), kb([cancel_row(t)]))


@router.message(Fin.amount)
async def msg_amount(message: Message, state, t):
    v = parse_amount(message.text)
    if v is None:
        return await message.answer(t("err_amount"))
    await _fn(state, amount=str(v))
    await state.set_state(Fin.currency)
    await message.answer(t("ask_currency"), reply_markup=kb([[b(c, f"fn:cur:{c}") for c in CURRENCIES], cancel_row(t)]))


@router.callback_query(Fin.currency, F.data.startswith("fn:cur:"))
async def cb_cur(cb: CallbackQuery, state, t):
    cur = cb.data.split(":")[2]
    if cur not in CURRENCIES:
        return await cb.answer()
    await _fn(state, currency=cur)
    await state.set_state(Fin.date)
    await send(cb, t("ask_date"), kb([[b(t("today"), "fn:today")], cancel_row(t)]))


async def _after_date(event, state, t):
    await state.set_state(Fin.note)
    await send(event, t("ask_note"), kb([[b(t("skip"), "fn:skip")], cancel_row(t)]))


@router.callback_query(Fin.date, F.data == "fn:today")
async def cb_today(cb: CallbackQuery, state, t):
    await _fn(state, date=today_uz().isoformat())
    await _after_date(cb, state, t)


@router.message(Fin.date)
async def msg_date(message: Message, state, t):
    d = parse_date(message.text, today_uz())
    if d is None:
        return await message.answer(t("err_date"))
    await _fn(state, date=d.isoformat())
    await _after_date(message, state, t)


async def _preview(event, state, t):
    d = (await state.get_data()).get("fn", {})
    await state.set_state(Fin.confirm)
    text = t("fin_preview", kind=t(f"fin_{d['kind']}"), cat=t(f"fc_{d['category']}"), amount=fmt_money(__import__("decimal").Decimal(d["amount"])), cur=d["currency"], date=d["date"], note=esc(d.get("note") or "—"))
    await send(event, text, kb([[b(t("confirm"), f"fn:ok:{d['token']}")], cancel_row(t)]))


@router.callback_query(Fin.note, F.data == "fn:skip")
async def cb_note_skip(cb: CallbackQuery, state, t):
    await _preview(cb, state, t)


@router.message(Fin.note)
async def msg_note(message: Message, state, t):
    await _fn(state, note=clean_text(message.text, 200) or None)
    await _preview(message, state, t)


@router.callback_query(Fin.confirm, F.data.startswith("fn:ok:"))
async def cb_confirm(cb: CallbackQuery, state, repo, user, t):
    d = (await state.get_data()).get("fn", {})
    if cb.data.split(":", 2)[2] != d.get("token"):
        return await cb.answer(t("stale"), show_alert=True)
    await state.clear()  # takroriy bosish: holat yo'q; bazada esa (user_id, client_ref) unique
    try:
        await repo.add_entry(user["id"], {"kind": d["kind"], "category": d["category"], "amount": d["amount"], "currency": d["currency"],
                                          "planned": False, "entry_date": d["date"], "note": d.get("note")}, f"tg:{d['token']}")
    except Exception as e:
        if "23514" in str(e) or "check constraint" in str(e).lower():
            return await send(cb, t("fin_category_unsupported"), main_menu(t))
        raise
    await send(cb, t("fin_saved"), main_menu(t))


@router.callback_query(F.data.startswith("fn:rep:"))
async def cb_report(cb: CallbackQuery, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    today = today_uz()
    which = cb.data.split(":")[2]
    if which == "y":
        start, end, label = today.replace(month=1, day=1), today.replace(year=today.year + 1, month=1, day=1), str(today.year)
    else:
        first, _ = month_bounds(today)
        if which == "pm":
            first = (first.replace(day=1) - __import__("datetime").timedelta(days=1)).replace(day=1)
        start, end = month_bounds(first)
        label = first.strftime("%Y-%m")
    totals = await period_totals(repo, user["id"], start, end)  # faqat o'z yozuvlari
    if not totals:
        return await send(cb, t("rep_empty", period=label))
    parts = [t("rep_title", period=label)]
    for cur, v in totals.items():
        top = sorted(v.by_category.items(), key=lambda x: x[1], reverse=True)[:5]
        parts.append(f"<b>{cur}</b>\n{t('fin_income')}: {fmt_money(v.income)}\n{t('fin_expense')}: {fmt_money(v.expense)}\n{t('fin_net')}: <b>{fmt_money(v.net)}</b>"
                     + ("\n" + "\n".join(f"· {t('fc_' + c)}: {fmt_money(a)} ({a / v.expense * 100:.0f}%)" for c, a in top) if top and v.expense > 0 else ""))
    await send(cb, "\n\n".join(parts))
