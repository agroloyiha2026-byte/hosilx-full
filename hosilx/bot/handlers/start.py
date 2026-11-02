"""Telegram ichida ro'yxatdan o'tish (qoralama) va mavjud hisobga ULASH.
Hisob (auth.users/profiles) saytda yoki ilovada yaratiladi; bot uni faqat bir martalik kod bilan bog'laydi."""
from __future__ import annotations

from datetime import datetime, timezone
from functools import partial

from aiogram import F, Router
from aiogram.filters import Command, CommandStart
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery, KeyboardButton, Message, ReplyKeyboardMarkup, ReplyKeyboardRemove

from ..i18n import tr, variants
from ..states import Reg
from ..ui import b, cancel_row, esc, kb, lang_kb, main_menu, regions_kb, send
from ..utils import registration as R
from ..utils.links import parse_link_command
from ..utils.regions import region_by_index, region_label
from ..utils.validators import clean_text, normalize_phone, valid_name, valid_role

router = Router(name="start")


def link_howto(t, web_url: str) -> str:
    return t("link_howto", web=esc(web_url) if web_url else "")


async def _save(repo, ctx, tid: int, state: FSMContext, patch: dict) -> dict:
    d = {**(await state.get_data()).get("d", {}), **patch}
    await state.update_data(d=d)
    await repo.reg_save(tid, {**patch, "status": "draft"})
    ctx.invalidate(tid)
    return d


async def prompt(step: str, event, state: FSMContext, t, lang: str, d: dict) -> None:
    msg = event.message if isinstance(event, CallbackQuery) else event
    nav = [b(t("back"), "reg:back"), b(t("cancel"), "x:cancel")]
    if step == "name":
        await state.set_state(Reg.name)
        await msg.answer(t("reg_name"), reply_markup=kb([cancel_row(t)]))
    elif step == "role":
        await state.set_state(Reg.role)
        await msg.answer(t("reg_role"), reply_markup=kb([[b(t(f"role_{r}"), f"reg:role:{r}")] for r in ("farmer", "buyer", "warehouse_owner")] + [nav]))
    elif step == "phone":
        await state.set_state(Reg.phone)
        await msg.answer(t("reg_phone"), reply_markup=ReplyKeyboardMarkup(
            keyboard=[[KeyboardButton(text=t("share_phone"), request_contact=True)], [KeyboardButton(text=t("back"))]], resize_keyboard=True, one_time_keyboard=True))
    elif step == "region":
        await state.set_state(Reg.region)
        await msg.answer(t("reg_region"), reply_markup=regions_kb("reg:reg", lang, nav))
    elif step == "district":
        await state.set_state(Reg.district)
        await msg.answer(t("reg_district"), reply_markup=kb([nav]))
    elif step == "business":
        await state.set_state(Reg.business)
        await msg.answer(t("reg_business"), reply_markup=kb([[b(t("skip"), "reg:skip")], nav]))
    elif step == "consent":
        await state.set_state(Reg.consent)
        await msg.answer(t("reg_consent"), reply_markup=kb([[b(t("agree"), "reg:consent:yes"), b(t("disagree"), "reg:consent:no")], nav]))
    else:
        await state.set_state(Reg.confirm)
        phone_note = f" ({t('via_telegram')})" if d.get("phone_from_telegram") else f" ({t('not_verified')})"
        text = t("reg_summary", name=esc(d.get("full_name")), role=t(f"role_{d.get('role')}"), phone=esc(d.get("phone")) + phone_note,
                 region=esc(region_label(d.get("region", ""), lang)), district=esc(d.get("district")), business=esc(d.get("business_name") or "—"))
        await msg.answer(text, reply_markup=kb([[b(t("confirm"), "reg:confirm")], [b(t("restart"), "reg:restart")], cancel_row(t)]))


async def advance(event, state, repo, ctx, tid, patch, t, lang) -> None:
    d = await _save(repo, ctx, tid, state, patch)
    await prompt(R.next_step(d), event, state, t, lang, d)


@router.message(CommandStart())
async def cmd_start(message: Message, state: FSMContext, user, draft, t, settings):
    await state.clear()
    if user:
        await message.answer(t("welcome_back", name=esc(user.get("full_name"))), reply_markup=main_menu(t))
    elif draft and draft.get("status") == "pending_link":
        await message.answer(t("pending_link") + "\n\n" + link_howto(t, settings.web_url), reply_markup=main_menu(t))
    elif draft and draft.get("status") == "draft" and draft.get("language"):
        await message.answer(t("reg_resume"), reply_markup=kb([[b(t("reg_continue"), "reg:resume"), b(t("restart"), "reg:restart")]]))
    else:
        await message.answer(t("welcome") + "\n\n" + tr("uz", "choose_lang") + " / " + tr("ru", "choose_lang") + " / " + tr("en", "choose_lang"),
                             reply_markup=lang_kb("reg:lang"))


@router.callback_query(F.data.startswith("reg:lang:"))
async def reg_lang(cb: CallbackQuery, state: FSMContext, repo, ctx, user):
    lang = cb.data.split(":")[2]
    if user or lang not in ("uz", "ru", "en"):
        return await cb.answer()
    t = partial(tr, lang)
    await state.set_data({"d": {}})
    await cb.message.answer(t("reg_intro"), reply_markup=ReplyKeyboardRemove())
    await advance(cb, state, repo, ctx, cb.from_user.id, {"language": lang}, t, lang)
    await cb.answer()


@router.callback_query(F.data == "reg:resume")
async def reg_resume(cb: CallbackQuery, state: FSMContext, draft, t, lang):
    d = {k: v for k, v in (draft or {}).items() if k not in ("telegram_id", "created_at", "updated_at", "status", "user_id")}
    await state.set_data({"d": d})
    await prompt(R.next_step(d), cb, state, t, lang, d)
    await cb.answer()


@router.callback_query(F.data == "reg:restart")
async def reg_restart(cb: CallbackQuery, state: FSMContext, repo, ctx, t, lang):
    patch = {f: None for f in ("full_name", "role", "phone", "phone_from_telegram", "region", "district", "business_name", "consent_at")}
    await state.set_data({"d": {"language": lang}})
    await repo.reg_save(cb.from_user.id, {**patch, "language": lang, "status": "draft"})
    ctx.invalidate(cb.from_user.id)
    await prompt("name", cb, state, t, lang, {})
    await cb.answer()


@router.callback_query(F.data == "reg:back")
async def reg_back(cb: CallbackQuery, state: FSMContext, repo, ctx, t, lang):
    d = (await state.get_data()).get("d", {})
    cur = R.next_step(d)
    patch = R.reset_patch(R.prev_step(cur))  # oldingi qadam tozalanadi va qayta so'raladi
    await advance(cb, state, repo, ctx, cb.from_user.id, patch, t, lang)
    await cb.answer()


@router.message(Reg.name)
async def reg_name(message: Message, state, repo, ctx, t, lang):
    name = valid_name(message.text)
    if not name:
        return await message.answer(t("err_name"))
    await advance(message, state, repo, ctx, message.from_user.id, {"full_name": name}, t, lang)


@router.callback_query(Reg.role, F.data.startswith("reg:role:"))
async def reg_role(cb: CallbackQuery, state, repo, ctx, t, lang):
    role = cb.data.split(":")[2]
    if not valid_role(role):  # admin va noma'lum rollar rad etiladi
        return await cb.answer(t("err_role"), show_alert=True)
    await advance(cb, state, repo, ctx, cb.from_user.id, {"role": role}, t, lang)
    await cb.answer()


@router.message(Reg.phone, F.contact)
async def reg_contact(message: Message, state, repo, ctx, t, lang):
    c = message.contact
    if c.user_id != message.from_user.id:  # boshqa odamning kontakti qabul qilinmaydi
        return await message.answer(t("err_contact_other"))
    phone = normalize_phone(c.phone_number)
    if not phone:
        return await message.answer(t("err_phone"))
    await message.answer(t("ok_phone"), reply_markup=ReplyKeyboardRemove())
    await advance(message, state, repo, ctx, message.from_user.id, {"phone": phone, "phone_from_telegram": True}, t, lang)


@router.message(Reg.phone)
async def reg_phone_text(message: Message, state, repo, ctx, t, lang):
    txt = (message.text or "").strip()
    if txt in variants("back"):
        await message.answer("↩️", reply_markup=ReplyKeyboardRemove())
        return await advance(message, state, repo, ctx, message.from_user.id, R.reset_patch("role"), t, lang)
    phone = normalize_phone(txt)
    if not phone:
        return await message.answer(t("err_phone"))
    await message.answer(t("ok_phone_manual"), reply_markup=ReplyKeyboardRemove())
    await advance(message, state, repo, ctx, message.from_user.id, {"phone": phone, "phone_from_telegram": False}, t, lang)


@router.callback_query(Reg.region, F.data.startswith("reg:reg:"))
async def reg_region(cb: CallbackQuery, state, repo, ctx, t, lang):
    arg = cb.data.split(":")[2]
    region = region_by_index(int(arg)) if arg.isdigit() else None
    if not region:
        return await cb.answer()
    await advance(cb, state, repo, ctx, cb.from_user.id, {"region": region}, t, lang)
    await cb.answer()


@router.message(Reg.district)
async def reg_district(message: Message, state, repo, ctx, t, lang):
    v = clean_text(message.text, 80)
    if len(v) < 2:
        return await message.answer(t("err_district"))
    await advance(message, state, repo, ctx, message.from_user.id, {"district": v}, t, lang)


@router.message(Reg.business)
async def reg_business(message: Message, state, repo, ctx, t, lang):
    v = clean_text(message.text, 120)
    await advance(message, state, repo, ctx, message.from_user.id, {"business_name": v if len(v) >= 2 else ""}, t, lang)


@router.callback_query(Reg.business, F.data == "reg:skip")
async def reg_skip(cb: CallbackQuery, state, repo, ctx, t, lang):
    await advance(cb, state, repo, ctx, cb.from_user.id, {"business_name": ""}, t, lang)
    await cb.answer()


@router.callback_query(Reg.consent, F.data.startswith("reg:consent:"))
async def reg_consent(cb: CallbackQuery, state, repo, ctx, t, lang):
    if cb.data.endswith(":no"):
        await state.clear()
        await cb.message.answer(t("consent_required"))
        return await cb.answer()
    await advance(cb, state, repo, ctx, cb.from_user.id, {"consent_at": datetime.now(timezone.utc).isoformat()}, t, lang)
    await cb.answer()


@router.callback_query(Reg.confirm, F.data == "reg:confirm")
async def reg_confirm(cb: CallbackQuery, state, repo, ctx, t, settings):
    d = (await state.get_data()).get("d", {})
    if R.next_step(d) != "confirm":
        return await cb.answer()
    await repo.reg_save(cb.from_user.id, {**d, "status": "pending_link"})
    ctx.invalidate(cb.from_user.id)
    await state.clear()
    await cb.message.answer(t("reg_done") + "\n\n" + link_howto(t, settings.web_url), reply_markup=main_menu(t))
    await cb.answer()


@router.message(Command("link"))
async def cmd_link(message: Message, state: FSMContext, user, repo, ctx, t, lang):
    await state.clear()
    if user:
        return await message.answer(t("already_linked"), reply_markup=main_menu(t))
    code = parse_link_command(message.text)
    if not code:
        return await message.answer(t("link_usage"))
    tid = message.from_user.id
    status, uid = await repo.consume_link_code(code, tid, datetime.now(timezone.utc))
    if status != "ok":
        return await message.answer(t({"invalid": "link_invalid", "expired": "link_expired", "taken": "link_taken"}[status]))
    profile = await repo.profile(uid)
    res = await repo.apply_draft(uid, profile or {}, await repo.reg_get(tid))
    ctx.invalidate(tid)
    lang2 = (await repo.profile(uid) or {}).get("language") or lang
    t2 = partial(tr, lang2)
    extra = {"applied": "\n" + t2("role_applied"), "failed": "\n" + t2("role_failed"), "kept": ""}[res["role"]]
    await message.answer(t2("link_ok") + extra, reply_markup=main_menu(t2))
