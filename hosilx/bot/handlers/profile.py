from __future__ import annotations

from aiogram import F, Router
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery, Message

from ..i18n import tr
from ..ui import b, esc, kb, main_menu, menu_texts, send, show
from ..utils.regions import region_label

router = Router(name="profile")
LANGS = {"uz": "O‘zbekcha", "ru": "Русский", "en": "English"}


@router.message(F.text.in_(menu_texts("m_profile")))
async def h_profile(message: Message, state: FSMContext, user, draft, t, lang):
    await state.clear()
    if user:
        text = (f"<b>{esc(user.get('full_name') or '—')}</b>\n{t('role_' + user['role'])}\n"
                + (f"{t('phone')}: {esc(user['phone'])}\n" if user.get("phone") else "")
                + (f"{t('region')}: {esc(region_label(user['region'], lang))}{(', ' + esc(user['district'])) if user.get('district') else ''}\n" if user.get("region") else "")
                + (f"{t('business')}: {esc(user['farm_name'])}\n" if user.get("farm_name") else "")
                + f"\n✅ {t('tg_linked')}\n🌐 {LANGS.get(lang, lang)}\n🔔 {t('on') if user.get('telegram_notify') is not False else t('off')}")
    elif draft:
        text = t("draft_profile", name=esc(draft.get("full_name") or "—"), status=t("pending_link") if draft.get("status") == "pending_link" else t("reg_unfinished"))
    else:
        text = t("home_guest")
    await message.answer(text, reply_markup=main_menu(t))


def _settings_kb(user, t):
    rows = [[b(name, f"set:lang:{code}") for code, name in LANGS.items()]]
    if user:
        rows.append([b(t("notif_toggle"), "set:ntf")])
        rows.append([b(t("unlink"), "set:unlink")])
    return kb(rows)


@router.message(F.text.in_(menu_texts("m_settings")))
async def h_settings(message: Message, state: FSMContext, user, t):
    await state.clear()
    await message.answer(t("settings_title"), reply_markup=_settings_kb(user, t))


@router.callback_query(F.data.startswith("set:lang:"))
async def cb_lang(cb: CallbackQuery, user, draft, repo, ctx):
    lang = cb.data.split(":")[2]
    if lang not in LANGS:
        return await cb.answer()
    if user:
        await repo.set_language(user["id"], lang)  # profil tili: ilova, sayt va bot uchun umumiy
    elif draft:
        await repo.reg_save(cb.from_user.id, {"language": lang, "status": draft.get("status", "draft")})
    ctx.invalidate(cb.from_user.id)
    from functools import partial
    t2 = partial(tr, lang)
    await send(cb, t2("lang_changed"), main_menu(t2))


@router.callback_query(F.data == "set:ntf")
async def cb_ntf(cb: CallbackQuery, user, repo, ctx, t):
    if not user:
        return await cb.answer(t("need_link"), show_alert=True)
    on = user.get("telegram_notify") is False
    await repo.set_notify(user["id"], on)
    ctx.invalidate(cb.from_user.id)
    await cb.answer(t("on") if on else t("off"), show_alert=True)


@router.callback_query(F.data == "set:unlink")
async def cb_unlink(cb: CallbackQuery, user, t):
    if not user:
        return await cb.answer()
    await show(cb, t("unlink_confirm"), kb([[b(t("confirm"), "set:unlink:yes"), b(t("cancel"), "x:cancel")]]))


@router.callback_query(F.data == "set:unlink:yes")
async def cb_unlink_yes(cb: CallbackQuery, user, repo, ctx, t):
    if user:
        await repo.unlink(user["id"])
        ctx.invalidate(cb.from_user.id)
    await send(cb, t("unlinked"), main_menu(t))
