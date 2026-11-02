from __future__ import annotations

from datetime import datetime, timezone

from aiogram import F, Router
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery, Message

from ..states import TaskS
from ..ui import b, cancel_row, esc, kb, main_menu, menu_texts, require_user, send, show
from ..utils.validators import clean_text, parse_due, to_utc_iso
from .common import fmt_dt, is_uuid

router = Router(name="planner")


async def render(event, repo, user, t, done: bool = False):
    rows = await repo.tasks(user["id"], done)
    body = "\n".join(f"{i + 1}. <b>{esc(r['title'])}</b>\n   ⏰ {fmt_dt(r['due_at'])}" for i, r in enumerate(rows)) or t("no_tasks")
    markup = [] if done else [[b(f"✅ {i + 1}", f"tk:d:{r['id']}"), b(f"🗑 {i + 1}", f"tk:x:{r['id']}")] for i, r in enumerate(rows)]
    markup.append([b(t("add_task"), "tk:add"), b(t("tasks_open") if done else t("tasks_done"), "tk:list:open" if done else "tk:list:done")])
    await show(event, t("goals_title") + "\n\n" + body, kb(markup))


@router.message(F.text.in_(menu_texts("m_goals")))
async def h_goals(message: Message, state: FSMContext, repo, user, t, db_ok):
    await state.clear()
    if await require_user(message, user, t, db_ok):
        await render(message, repo, user, t)


@router.callback_query(F.data.startswith("tk:list:"))
async def cb_list(cb: CallbackQuery, repo, user, t, db_ok):
    if await require_user(cb, user, t, db_ok):
        await render(cb, repo, user, t, cb.data.endswith(":done"))


@router.callback_query(F.data.startswith(("tk:d:", "tk:x:")))
async def cb_act(cb: CallbackQuery, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    _, act, tid = cb.data.split(":", 2)
    if is_uuid(tid):  # repo faqat shu foydalanuvchining vazifasini o'zgartiradi
        await (repo.set_task_done(user["id"], tid) if act == "d" else repo.delete_task(user["id"], tid))
    await render(cb, repo, user, t)


@router.callback_query(F.data == "tk:add")
async def cb_add(cb: CallbackQuery, state: FSMContext, user, t, db_ok):
    if await require_user(cb, user, t, db_ok):
        await state.set_state(TaskS.title)
        await send(cb, t("ask_task_title"), kb([cancel_row(t)]))


@router.message(TaskS.title)
async def msg_title(message: Message, state, t):
    v = clean_text(message.text, 200)
    if len(v) < 2:
        return await message.answer(t("err_text_short"))
    await state.update_data(title=v)
    await state.set_state(TaskS.due)
    await message.answer(t("ask_due"), reply_markup=kb([cancel_row(t)]))


@router.message(TaskS.due)
async def msg_due(message: Message, state, repo, user, t, lang):
    now = datetime.now(timezone.utc)
    due = parse_due(message.text, now)
    if due is None:
        return await message.answer(t("err_due"))
    if due <= now:
        return await message.answer(t("err_due_past"))
    title = (await state.get_data()).get("title", "")
    await state.clear()
    await repo.add_task(user["id"], title, to_utc_iso(due))
    await message.answer(t("task_added", due=due.strftime("%d.%m.%Y %H:%M")), reply_markup=main_menu(t))
