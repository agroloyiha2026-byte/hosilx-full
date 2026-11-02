"""AI rejimlari. Kalit/model faqat environment'da; provayder yo'q bo'lsa "sozlanmagan" deyiladi, javob o'ylab topilmaydi.
Kunlik limit sayt bilan UMUMIY (ai_messages jadvali), shuning uchun bir akkaunt uchun bitta hisob."""
from __future__ import annotations

import base64
from datetime import datetime

from aiogram import Bot, F, Router
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery, Message

from ..services.ai import AiError
from ..services.summary import month_summary_text, today_uz
from ..states import AiS
from ..ui import b, cancel_row, esc, kb, main_menu, menu_texts, require_user, send
from ..utils import ai_prompts
from ..utils.finance import fmt_money
from ..utils.regions import REGIONS
from ..utils.validators import UZ_TZ, clean_text, to_utc_iso

router = Router(name="ai")


def _since_today() -> str:
    n = datetime.now(UZ_TZ)
    return to_utc_iso(n.replace(hour=0, minute=0, second=0, microsecond=0))


@router.message(F.text.in_(menu_texts("m_ai")))
async def h_ai(message: Message, state: FSMContext, user, t, db_ok):
    await state.clear()
    if await require_user(message, user, t, db_ok):
        await message.answer(t("ai_pick"), reply_markup=kb([[b(t(f"ai_{m}"), f"ai:m:{m}")] for m in ai_prompts.MODES] + [cancel_row(t)]))


@router.callback_query(F.data.startswith("ai:m:"))
async def cb_mode(cb: CallbackQuery, state: FSMContext, user, t, db_ok):
    mode = cb.data.split(":")[2]
    if not await require_user(cb, user, t, db_ok) or mode not in ai_prompts.MODES:
        return
    await state.set_state(AiS.chat)
    await state.update_data(mode=mode, hist=[], fin=False)
    if mode == "finance":  # moliyaviy ma'lumot faqat aniq ruxsat bilan yuboriladi
        return await send(cb, t("ai_fin_consent"), kb([[b(t("agree"), "ai:fin:yes"), b(t("disagree"), "ai:fin:no")]]))
    await send(cb, t(f"ai_prompt_{mode}"), kb([[b(t("ai_exit"), "x:cancel")]]))


@router.callback_query(AiS.chat, F.data.startswith("ai:fin:"))
async def cb_fin(cb: CallbackQuery, state: FSMContext, t):
    if cb.data.endswith(":no"):
        await state.clear()
        return await send(cb, t("cancelled"), main_menu(t))
    await state.update_data(fin=True)
    await send(cb, t("ai_prompt_finance"), kb([[b(t("ai_exit"), "x:cancel")]]))


async def _price(message: Message, repo, t, text: str):
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    ptype = clean_text(lines[0], 40).lower() if lines else ""
    region = next((r for r in REGIONS if len(lines) > 1 and r.lower() in lines[1].lower()), None)
    if len(ptype) < 2:
        return await message.answer(t("ai_prompt_price"))
    rows = await repo.price_stats(ptype, region)
    if not rows:
        return await message.answer(t("price_none"))
    out = [t("price_title", product=esc(ptype))]
    for r in rows:
        warn = f"\n⚠️ {t('price_few')}" if int(r["observations"]) < 5 else ""
        out.append(f"<b>{esc(r['currency'])}/{esc(r['unit'])}</b>\n{t('p_min')}: {fmt_money(__import__('decimal').Decimal(str(r['min_price'])))} · {t('p_med')}: {fmt_money(__import__('decimal').Decimal(str(r['median_price'])))} · {t('p_max')}: {fmt_money(__import__('decimal').Decimal(str(r['max_price'])))}\n{t('p_obs')}: {r['observations']} · {t('p_date')}: {r['last_date']}{warn}")
    out.append(t("price_source"))
    await message.answer("\n\n".join(out))


async def _ask(message: Message, state: FSMContext, bot: Bot, repo, user, ai, settings, t, lang, text: str, image: bytes | None = None):
    d = await state.get_data()
    mode = d.get("mode", "general")
    if ai_prompts.limit_exceeded(await repo.ai_count_today(user["id"], _since_today()), settings.ai_daily_limit):
        return await message.answer(t("ai_limit"))
    if ai is None:
        return await message.answer(t("ai_unconfigured"))
    prompt = text
    if mode == "finance" and d.get("fin"):
        prompt = f"Finance summary (this month, user's own data):\n{await month_summary_text(repo, user['id'], today_uz())}\n\nQuestion: {text}"
    content = ai_prompts.build_user_content(prompt, base64.b64encode(image).decode() if image else None, "image/jpeg" if image else None)
    msgs = (d.get("hist") or [])[-6:] + [{"role": "user", "content": content}]
    await bot.send_chat_action(message.chat.id, "typing")
    try:
        answer = await ai.complete(ai_prompts.system_prompt(mode, lang), msgs)
    except AiError as e:
        return await message.answer(t({"rate": "ai_busy", "timeout": "ai_timeout"}.get(e.kind, "ai_error")))
    await repo.ai_log(user["id"], "user", text)
    await repo.ai_log(user["id"], "assistant", answer)
    hist = ((d.get("hist") or []) + [{"role": "user", "content": text[:1500]}, {"role": "assistant", "content": answer[:1500]}])[-8:]
    await state.update_data(hist=hist)
    await message.answer(esc(answer[:3500]) + (f"\n\n<i>{t('ai_doctor_note')}</i>" if mode == "doctor" else ""), reply_markup=kb([[b(t("ai_exit"), "x:cancel")]]))


@router.message(AiS.chat, F.text)
async def msg_chat(message: Message, state: FSMContext, bot: Bot, repo, user, ai, settings, t, lang):
    text = clean_text(message.text, 1500)
    if len(text) < 2:
        return await message.answer(t("err_text_short"))
    if (await state.get_data()).get("mode") == "price":
        return await _price(message, repo, t, message.text or "")
    await _ask(message, state, bot, repo, user, ai, settings, t, lang, text)


@router.message(AiS.chat, F.photo)
async def msg_photo(message: Message, state: FSMContext, bot: Bot, repo, user, ai, settings, t, lang):
    if (await state.get_data()).get("mode") != "doctor":
        return await message.answer(t("ai_photo_only_doctor"))
    photo = message.photo[-1]
    if (photo.file_size or 0) > 3 * 1024 * 1024:
        return await message.answer(t("err_photo"))
    data = (await bot.download(photo)).getvalue()
    await _ask(message, state, bot, repo, user, ai, settings, t, lang, clean_text(message.caption, 800) or t("ai_photo_default"), data)
