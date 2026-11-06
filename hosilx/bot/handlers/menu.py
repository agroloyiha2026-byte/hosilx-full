from __future__ import annotations

from aiogram import F, Router
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery, Message

from ..ui import esc, main_menu, menu_texts, require_user, send
from .common import fmt_dt

router = Router(name="menu")


async def _home(event, state: FSMContext, user, t):
    await state.clear()
    await send(event, t("welcome_back", name=esc(user.get("full_name"))) if user else t("home_guest"), main_menu(t))


@router.message(Command("menu"))
@router.message(F.text.in_(menu_texts("m_home")))
async def h_home(message: Message, state: FSMContext, user, t):
    await _home(message, state, user, t)


@router.message(Command("cancel"))
@router.callback_query(F.data == "x:cancel")
async def h_cancel(event: Message | CallbackQuery, state: FSMContext, t):
    await state.clear()
    await send(event, t("cancelled"), main_menu(t))


@router.message(Command("help"))
@router.message(F.text.in_(menu_texts("m_help")))
async def h_help(message: Message, state: FSMContext, t):
    await state.clear()
    await message.answer(t("help"), reply_markup=main_menu(t))


def _planned(key: str):
    async def handler(message: Message, state: FSMContext, t):
        await state.clear()
        await message.answer(t("planned_module", name=t(key)), reply_markup=main_menu(t))
    return handler


# Hosil Pasporti: ochiq tekshiruv sahifasi (sayt) va QR xizmati yo'q, shuning uchun bot uni uydirmaydi.
for _k in ("m_passport",):
    router.message(F.text.in_(menu_texts(_k)))(_planned(_k))


@router.message(F.text.in_(menu_texts("m_notif")))
async def h_notifications(message: Message, state: FSMContext, user, repo, t, lang, db_ok):
    await state.clear()
    if not await require_user(message, user, t, db_ok):
        return
    rows = await repo.user_notifications(user["id"], 10)
    if not rows:
        return await message.answer(t("no_notifications"), reply_markup=main_menu(t))
    from ..i18n import has_key, tr
    lines = []
    for n in rows:
        key = f"notif_{n['title']}"
        head = tr(lang, key) if has_key(key) else esc(n["title"])
        lines.append(f"{'🔹' if not n['read'] else '▫️'} <b>{head}</b> · {fmt_dt(n['created_at'])}" + (f"\n{esc(n['body'])}" if n.get("body") else ""))
    await repo.mark_read(user["id"])
    await message.answer("\n\n".join(lines), reply_markup=main_menu(t))
