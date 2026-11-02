from __future__ import annotations
from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal
from typing import Iterable

BASIC_INCOME = ("sales", "other")
BASIC_EXPENSE = ("seeds", "fertilizer", "labor", "transport", "storage", "other")
EXT_INCOME = ("sales", "subsidy", "other_income")
EXT_EXPENSE = ("seeds", "fertilizer", "pesticide", "labor", "transport", "storage", "equipment", "fuel", "rent", "taxes", "other")
CURRENCIES = ("UZS", "USD")


def categories(kind: str, extended: bool) -> tuple[str, ...]:
    if kind == "income":
        return EXT_INCOME if extended else BASIC_INCOME
    return EXT_EXPENSE if extended else BASIC_EXPENSE


@dataclass
class Totals:
    income: Decimal = Decimal(0)
    expense: Decimal = Decimal(0)
    by_category: dict[str, Decimal] = field(default_factory=dict)  # faqat xarajatlar

    @property
    def net(self) -> Decimal:
        return self.income - self.expense


def summarize(entries: Iterable[dict]) -> dict[str, Totals]:
    """Valyutalar ALOHIDA hisoblanadi (aralashtirilmaydi); rejalashtirilgan yozuvlar kirmaydi."""
    out: dict[str, Totals] = {}
    for e in entries:
        if e.get("planned"):
            continue
        t = out.setdefault(e["currency"], Totals())
        a = Decimal(str(e["amount"]))
        if e["kind"] == "income":
            t.income += a
        else:
            t.expense += a
            t.by_category[e["category"]] = t.by_category.get(e["category"], Decimal(0)) + a
    return out


def month_bounds(today: date) -> tuple[date, date]:
    """[oy boshi, keyingi oy boshi)."""
    first = today.replace(day=1)
    nxt = date(first.year + (first.month == 12), 1 if first.month == 12 else first.month + 1, 1)
    return first, nxt


def fmt_money(v: Decimal) -> str:
    s = f"{v:,.2f}".rstrip("0").rstrip(".")
    return s.replace(",", " ")
