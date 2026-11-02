from __future__ import annotations
from datetime import datetime, timedelta
from typing import Any

from .links import parse_ts


def select_deliverable(notifs: list[dict], profiles: dict[str, dict], now: datetime,
                       max_age: timedelta = timedelta(hours=24)) -> list[tuple[dict, dict]]:
    """Telegramga yuboriladigan bildirishnomalar. Yuborilmaydi: ulanmagan/o'chirib qo'ygan foydalanuvchi,
    24 soatdan eski, Telegram ulanishidan OLDINGI (eski xabarlar to'planib yuborilmasin)."""
    out: list[tuple[dict, dict]] = []
    for n in notifs:
        p: Any = profiles.get(n["user_id"])
        if not p or not p.get("telegram_id") or p.get("telegram_notify") is False:
            continue
        created = parse_ts(n["created_at"])
        if now - created > max_age:
            continue
        linked = p.get("telegram_linked_at")
        if linked and created < parse_ts(linked):
            continue
        out.append((n, p))
    return out
