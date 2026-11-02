"""Ilovada/saytda paydo bo'lgan bildirishnomalar va vazifa eslatmalarini Telegramga yetkazadi.
Idempotent: notifications.tg_sent_at (qayta ishlangan belgi) va tasks.reminded. Foydalanuvchi o'chirib qo'ygan, ulanmagan yoki
ulanishdan oldingi xabarlar yuborilmaydi (faqat belgilanadi, navbat tiqilib qolmasligi uchun)."""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta, timezone

from aiogram import Bot
from aiogram.exceptions import TelegramAPIError, TelegramForbiddenError, TelegramRetryAfter

from ..i18n import has_key, tr
from ..repositories import Repo
from ..utils.links import parse_ts
from ..utils.notify import select_deliverable
from .. import ui

log = logging.getLogger(__name__)


def format_notification(n: dict, lang: str) -> str:
    key = f"notif_{n['title']}"
    head = tr(lang, key) if has_key(key) else ui.esc(n["title"])
    body = f"\n{ui.esc(n['body'])}" if n.get("body") else ""
    return f"🔔 <b>{head}</b>{body}"


async def _send(bot: Bot, repo: Repo, profile: dict, text: str) -> str:
    """-> sent | skip (qayta urinmaymiz) | retry"""
    for attempt in range(2):
        try:
            await bot.send_message(profile["telegram_id"], text)
            return "sent"
        except TelegramRetryAfter as e:
            await asyncio.sleep(min(e.retry_after, 30))
        except TelegramForbiddenError:  # foydalanuvchi botni bloklagan
            await repo.set_notify(profile["id"], False)
            return "skip"
        except TelegramAPIError as e:
            log.warning("Telegram xatosi: %s", type(e).__name__)
            return "retry"
    return "retry"


async def deliver_notifications(bot: Bot, repo: Repo, now: datetime | None = None) -> int:
    now = now or datetime.now(timezone.utc)
    notifs = await repo.unsent_notifications()
    if not notifs:
        return 0
    profiles = await repo.profiles_by_ids(sorted({n["user_id"] for n in notifs}))
    deliver = {n["id"]: p for n, p in select_deliverable(notifs, profiles, now)}
    done, sent = [], 0
    for n in notifs:
        p = deliver.get(n["id"])
        if p is None:
            done.append(n["id"])  # yuborilmaydi: belgilanadi
            continue
        res = await _send(bot, repo, p, format_notification(n, p.get("language") or "uz"))
        if res in ("sent", "skip"):
            done.append(n["id"])
            sent += res == "sent"
    await repo.mark_sent(done, now.isoformat())
    return sent


async def deliver_task_reminders(bot: Bot, repo: Repo, now: datetime | None = None) -> int:
    now = now or datetime.now(timezone.utc)
    tasks = await repo.due_tasks(now.isoformat())
    if not tasks:
        return 0
    profiles = await repo.profiles_by_ids(sorted({t["user_id"] for t in tasks}))
    sent = 0
    for t in tasks:
        p = profiles.get(t["user_id"])
        fresh = now - parse_ts(t["due_at"]) <= timedelta(hours=24)
        if p and p.get("telegram_id") and p.get("telegram_notify") is not False and fresh:
            res = await _send(bot, repo, p, f"⏰ <b>{tr(p.get('language') or 'uz', 'reminder')}</b>\n{ui.esc(t['title'])}")
            if res == "retry":
                continue
            sent += res == "sent"
        await repo.mark_reminded(t["id"])
    return sent


async def notifier_loop(bot: Bot, repo: Repo, stop: asyncio.Event, interval: float = 30.0) -> None:
    while not stop.is_set():
        try:
            await deliver_notifications(bot, repo)
            await deliver_task_reminders(bot, repo)
        except Exception:
            log.exception("bildirishnoma ishchisi xatosi")
        try:
            await asyncio.wait_for(stop.wait(), timeout=interval)
        except asyncio.TimeoutError:
            pass
