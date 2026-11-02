from aiogram import Router
from aiogram.filters import StateFilter
from aiogram.types import CallbackQuery, Message

from ..ui import main_menu

router = Router(name="fallback")


@router.message(StateFilter(None))
async def unknown(message: Message, t):
    await message.answer(t("unknown"), reply_markup=main_menu(t))


@router.callback_query()
async def stale(cb: CallbackQuery, t):
    await cb.answer(t("stale"), show_alert=True)  # eskirgan tugma (masalan, bot qayta ishga tushgan)
