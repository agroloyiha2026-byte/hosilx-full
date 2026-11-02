from __future__ import annotations

from aiogram import F, Router
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery, Message

from ..states import Rep
from ..ui import b, cancel_row, kb, main_menu, require_user, send
from ..utils.validators import clean_text
from .common import is_uuid

router = Router(name="reports")
REASONS = ("spam", "fraud", "wrong", "other")


@router.callback_query(F.data.regexp(r"^rp:[pw]:[0-9a-f-]{36}$"))
async def rp_start(cb: CallbackQuery, state: FSMContext, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    _, kind, oid = cb.data.split(":")
    if not is_uuid(oid):
        return await cb.answer()
    await state.set_state(Rep.reason)
    await state.update_data(kind=kind, oid=oid)
    await send(cb, t("rp_pick"), kb([[b(t(f"rp_{r}"), f"rp:r:{r}")] for r in REASONS] + [cancel_row(t)]))


@router.callback_query(Rep.reason, F.data.startswith("rp:r:"))
async def rp_reason(cb: CallbackQuery, state: FSMContext, t):
    r = cb.data.split(":")[2]
    if r not in REASONS:
        return await cb.answer()
    await state.update_data(reason=r)
    await state.set_state(Rep.text)
    rows = [[b(t("skip"), "rp:skip")]] if r != "other" else []
    await send(cb, t("rp_details"), kb(rows + [cancel_row(t)]))


async def _finish(event, state, repo, user, t, details: str):
    d = await state.get_data()
    await state.clear()
    reason = d["reason"] + (f": {details}" if details else "")
    await repo.create_report(user["id"], d["oid"] if d["kind"] == "p" else None, d["oid"] if d["kind"] == "w" else None, reason)
    await send(event, t("rp_sent"), main_menu(t))


@router.callback_query(Rep.text, F.data == "rp:skip")
async def rp_skip(cb: CallbackQuery, state, repo, user, t):
    if (await state.get_data()).get("reason") == "other":
        return await cb.answer(t("rp_need_text"), show_alert=True)
    await _finish(cb, state, repo, user, t, "")


@router.message(Rep.text)
async def rp_text(message: Message, state, repo, user, t):
    text = clean_text(message.text, 400)
    if (await state.get_data()).get("reason") == "other" and len(text) < 5:
        return await message.answer(t("rp_need_text"))
    await _finish(message, state, repo, user, t, text)
