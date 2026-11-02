from __future__ import annotations

from datetime import date, datetime

from ..utils.finance import Totals, fmt_money, month_bounds, summarize
from ..utils.validators import UZ_TZ


def today_uz() -> date:
    return datetime.now(UZ_TZ).date()


async def period_totals(repo, uid: str, start: date, end: date) -> dict[str, Totals]:
    """[start, end) davridagi FAQAT shu foydalanuvchining yozuvlari; valyutalar alohida."""
    return summarize(await repo.entries_between(uid, start.isoformat(), end.isoformat()))


async def month_summary_text(repo, uid: str, today: date) -> str:
    start, end = month_bounds(today)
    totals = await period_totals(repo, uid, start, end)
    return "\n".join(f"{c}: income {fmt_money(v.income)}, expense {fmt_money(v.expense)}, net {fmt_money(v.net)}" for c, v in totals.items()) or "no entries"
