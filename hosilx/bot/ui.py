"""Umumiy UI yordamchilari: HTML-escape, xabarni yangilash yoki yangi yuborish, klaviaturalar."""
from __future__ import annotations

import logging
from html import escape
from typing import Callable

from aiogram.exceptions import TelegramBadRequest
from aiogram.types import CallbackQuery, InlineKeyboardButton, InlineKeyboardMarkup, KeyboardButton, Message, ReplyKeyboardMarkup

from .i18n import variants
from .utils.regions import REGIONS, region_label

log = logging.getLogger(__name__)
T = Callable[..., str]

MENU = ("m_home", "m_market", "m_wh", "m_logistics", "m_machinery", "m_agro", "m_diary", "m_goals", "m_finance", "m_ai", "m_passport", "m_notif", "m_profile", "m_settings", "m_help")


def esc(x) -> str:
    """Foydalanuvchi va baza matni HTML sifatida talqin qilinmasligi uchun (parse_mode=HTML)."""
    return escape(str(x if x is not None else ""), quote=False)


def b(text: str, data: str) -> InlineKeyboardButton:
    return InlineKeyboardButton(text=text, callback_data=data)


def kb(rows: list[list[InlineKeyboardButton]]) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(inline_keyboard=rows)


def cancel_row(t: T) -> list[InlineKeyboardButton]:
    return [b(t("cancel"), "x:cancel")]


def main_menu(t: T) -> ReplyKeyboardMarkup:
    rows = [[KeyboardButton(text=t(k)) for k in MENU[i:i + 2]] for i in range(0, len(MENU), 2)]
    return ReplyKeyboardMarkup(keyboard=rows, resize_keyboard=True)


def menu_texts(key: str) -> set[str]:
    return variants(key)


def lang_kb(prefix: str) -> InlineKeyboardMarkup:
    return kb([[b("🇺🇿 O‘zbekcha", f"{prefix}:uz"), b("🇷🇺 Русский", f"{prefix}:ru"), b("🇬🇧 English", f"{prefix}:en")]])


def regions_kb(prefix: str, lang: str, extra: list[InlineKeyboardButton] | None = None) -> InlineKeyboardMarkup:
    rows = [[b(region_label(r, lang), f"{prefix}:{i}") for i, r in list(enumerate(REGIONS))[j:j + 2]] for j in range(0, len(REGIONS), 2)]
    if extra:
        rows.append(extra)
    return kb(rows)


def pager(prefix: str, page: int, has_next: bool) -> list[InlineKeyboardButton]:
    row = []
    if page > 0:
        row.append(b("◀️", f"{prefix}:{page - 1}"))
    if has_next:
        row.append(b("▶️", f"{prefix}:{page + 1}"))
    return row


async def show(event: Message | CallbackQuery, text: str, markup=None) -> None:
    """Callback bo'lsa xabarni yangilaydi (bo'lmasa yangisini yuboradi), oddiy xabar bo'lsa yangi xabar."""
    if isinstance(event, CallbackQuery):
        try:
            if event.message is not None:
                await event.message.edit_text(text, reply_markup=markup)
        except TelegramBadRequest as e:
            if "not modified" not in str(e).lower() and event.message is not None:
                await event.message.answer(text, reply_markup=markup)  # masalan: rasmli xabarni matn sifatida tahrirlab bo'lmaydi
        await event.answer()
    else:
        await event.answer(text, reply_markup=markup)


async def send(event: Message | CallbackQuery, text: str, markup=None) -> None:
    """Doim yangi xabar."""
    msg = event.message if isinstance(event, CallbackQuery) else event
    if msg is not None:
        await msg.answer(text, reply_markup=markup)
    if isinstance(event, CallbackQuery):
        await event.answer()


async def require_user(event, user, t: T, db_ok: bool) -> bool:
    """Hisobga ulangan foydalanuvchi kerak bo'lgan amallar uchun darvoza. Ulanmagan bo'lsa tushuntiradi."""
    if user:
        return True
    await send(event, t("backend_down") if not db_ok else t("need_link"), main_menu(t))
    return False
