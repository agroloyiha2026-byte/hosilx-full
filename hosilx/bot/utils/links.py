from __future__ import annotations
import re
from datetime import datetime, timezone

CODE_RE = re.compile(r"^[A-Z0-9]{6,12}$")


def parse_link_command(text: str | None) -> str | None:
    """'/link ABCD2345' -> 'ABCD2345'. Format noto'g'ri bo'lsa None."""
    parts = (text or "").split()
    if len(parts) != 2:
        return None
    code = parts[1].strip().upper()
    return code if CODE_RE.fullmatch(code) else None


def parse_ts(s: str) -> datetime:
    dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def is_expired(expires_at: str, now: datetime) -> bool:
    return parse_ts(expires_at) <= now
