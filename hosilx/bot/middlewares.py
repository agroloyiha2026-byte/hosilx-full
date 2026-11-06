from __future__ import annotations

import logging
import time
from functools import partial
from typing import Any, Awaitable, Callable

from aiogram import BaseMiddleware
from aiogram.types import CallbackQuery, ErrorEvent, Message

from .i18n import tr
from .utils.ratelimit import RateLimiter

log = logging.getLogger(__name__)


def guess_lang(code: str | None) -> str:
    c = (code or "").lower()[:2]
    return c if c in ("ru", "en") else "uz"


class UserContext(BaseMiddleware):
    """Har bir yangilanishda Telegram ID bo'yicha profilni (bo'lmasa qoralamani) topadi va tilni belgilaydi.
    Rol va ruxsatlar HECH QACHON Telegram ma'lumotidan olinmaydi: faqat bazadagi profildan."""

    def __init__(self, repo, ttl: float = 30.0):
        self.repo, self.ttl, self.cache = repo, ttl, {}

    def invalidate(self, tid: int) -> None:
        self.cache.pop(tid, None)

    async def __call__(self, handler: Callable[[Any, dict], Awaitable[Any]], event: Any, data: dict) -> Any:
        u = getattr(event, "from_user", None)
        if u is None:
            return await handler(event, data)
        now = time.monotonic()
        hit = self.cache.get(u.id)
        if hit and now - hit[0] <= self.ttl:
            _, profile, draft = hit
            ok = True
        else:
            profile = draft = None
            ok = True
            try:
                profile = await self.repo.profile_by_tg(u.id)
                draft = None if profile else await self.repo.reg_get(u.id)
                self.cache[u.id] = (now, profile, draft)
            except Exception:
                ok = False  # baza vaqtincha ishlamayapti: keshlanmaydi
                log.exception("profil yuklanmadi")
        lang = (profile or {}).get("language") or (draft or {}).get("language") or guess_lang(u.language_code)
        data.update(user=profile, draft=draft, lang=lang, t=partial(tr, lang), db_ok=ok, tg_id=u.id)
        return await handler(event, data)


class Heartbeat(BaseMiddleware):
    """Qayta ishlangan Telegram yangilanishlari statistikasi: /health da bot HAQIQATAN yangilanish olayotganini ko'rsatadi."""

    def __init__(self, stats: dict):
        self.stats = stats

    async def __call__(self, handler, event, data):
        self.stats["updates"] = self.stats.get("updates", 0) + 1
        self.stats["last"] = time.monotonic()
        return await handler(event, data)


class Throttle(BaseMiddleware):
    def __init__(self, limit: int = 10, per: float = 10.0):
        self.rl = RateLimiter(limit, per)

    async def __call__(self, handler, event, data):
        u = getattr(event, "from_user", None)
        if u is not None and not self.rl.allow(u.id, time.monotonic()):
            if isinstance(event, CallbackQuery):
                await event.answer("⏳", show_alert=False)
            return None  # xabarlar jimgina tashlab yuboriladi
        return await handler(event, data)


async def on_error(event: ErrorEvent) -> bool:
    """Kutilmagan xato: logga yoziladi (maxfiy qiymatlarsiz), foydalanuvchiga umumiy xabar."""
    log.error("handler xatosi: %s", type(event.exception).__name__, exc_info=event.exception)
    upd = event.update
    msg = upd.message or (upd.callback_query.message if upd.callback_query else None)
    if msg is not None:
        try:
            await msg.answer(tr("uz", "err_generic"))
        except Exception:
            pass
    if upd.callback_query:
        try:
            await upd.callback_query.answer()
        except Exception:
            pass
    return True
