from __future__ import annotations

import re
from decimal import Decimal

from ..utils.finance import fmt_money
from ..utils.links import parse_ts
from ..utils.validators import UZ_TZ

UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")


def is_uuid(s: str | None) -> bool:
    return bool(UUID_RE.match(s or ""))


def fmt_dt(iso: str) -> str:
    return parse_ts(iso).astimezone(UZ_TZ).strftime("%d.%m.%Y %H:%M")


def fmt_price(price, cur: str, unit: str) -> str:
    return f"{fmt_money(Decimal(str(price)))} {cur}/{unit}"


def is_seller(user: dict | None) -> bool:
    return bool(user) and user.get("role") in ("farmer", "admin")
