"""Kiritmalarni tekshirish (tarmoqsiz, toza funksiyalar)."""
from __future__ import annotations

import re
import unicodedata
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

UZ_TZ = timezone(timedelta(hours=5))   # O'zbekiston: UTC+5, yozgi vaqt yo'q
SELF_REGISTER_ROLES = ("farmer", "buyer", "warehouse_owner")  # admin hech qachon Telegramdan tanlanmaydi


def clean_text(s: str | None, max_len: int = 200) -> str:
    s = "".join(ch for ch in (s or "") if unicodedata.category(ch)[0] != "C" or ch in "\n\t")
    return re.sub(r"\s+", " ", s).strip()[:max_len]


def valid_name(s: str | None) -> str | None:
    if not s or len(s.strip()) > 80:
        return None
    t = clean_text(s, 80)
    return t if len(t) >= 2 and any(c.isalpha() for c in t) else None


def normalize_phone(raw: str | None) -> str | None:
    """+998XXXXXXXXX ko'rinishiga keltiradi; noto'g'ri bo'lsa None."""
    d = re.sub(r"\D", "", raw or "")
    if len(d) == 9:
        d = "998" + d
    return "+" + d if re.fullmatch(r"998\d{9}", d) else None


def valid_role(role: str | None) -> bool:
    return role in SELF_REGISTER_ROLES


def sanitize_search(q: str | None) -> str:
    """Supabase filtr sintaksisini buzadigan belgilarni olib tashlaydi."""
    return re.sub(r"[%,()*\\]", " ", q or "").strip()[:60]


def parse_amount(text: str | None, max_value: Decimal = Decimal("1000000000000")) -> Decimal | None:
    t = (text or "").strip().replace(" ", "").replace("\u00a0", "").replace(",", ".")
    if not re.fullmatch(r"\d+(\.\d{1,2})?", t):
        return None
    v = Decimal(t)
    return v if 0 < v <= max_value else None


_TODAY = {"bugun", "today", "сегодня"}
_TOMORROW = {"ertaga", "tomorrow", "завтра"}


def parse_date(text: str | None, today: date) -> date | None:
    t = (text or "").strip().lower()
    if t in _TODAY:
        return today
    if t in _TOMORROW:
        return today + timedelta(days=1)
    for fmt in ("%Y-%m-%d", "%d.%m.%Y", "%d/%m/%Y"):
        try:
            d = datetime.strptime(t, fmt).date()
        except ValueError:
            continue
        return d if 2000 <= d.year <= 2100 else None
    return None


def parse_due(text: str | None, now: datetime) -> datetime | None:
    """'25.12.2026 18:30', 'ertaga 09:00', '2026-12-25' (soat berilmasa 09:00). O'zbekiston vaqti."""
    t = (text or "").strip()
    m = re.search(r"(?:^|\s)(\d{1,2}):(\d{2})$", t)
    hh, mm = (9, 0)
    if m:
        hh, mm = int(m.group(1)), int(m.group(2))
        t = t[: m.start()].strip()
    if not (0 <= hh < 24 and 0 <= mm < 60):
        return None
    d = parse_date(t, now.astimezone(UZ_TZ).date())
    return datetime(d.year, d.month, d.day, hh, mm, tzinfo=UZ_TZ) if d else None


def to_utc_iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat()
