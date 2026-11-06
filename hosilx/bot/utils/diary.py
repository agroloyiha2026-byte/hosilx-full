"""Dala daftari: qayd turlari va xulosa hisoblari (tarmoqsiz)."""
from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal

ENTRY_KINDS = ("sowing", "irrigation", "fertilizing", "treatment", "labor", "harvest", "expense", "observation")
UNITS = ("kg", "t", "l", "m3", "ha")


@dataclass
class DiarySummary:
    count: int = 0
    by_kind: dict[str, int] = field(default_factory=dict)
    cost: dict[str, Decimal] = field(default_factory=dict)      # valyuta bo'yicha (aralashtirilmaydi)
    harvest: dict[str, Decimal] = field(default_factory=dict)   # birlik bo'yicha


def _add(s: DiarySummary, e: dict) -> None:
    s.count += 1
    s.by_kind[e["kind"]] = s.by_kind.get(e["kind"], 0) + 1
    if e.get("cost") is not None:
        cur = e.get("currency") or "UZS"
        s.cost[cur] = s.cost.get(cur, Decimal(0)) + Decimal(str(e["cost"]))
    if e["kind"] == "harvest" and e.get("amount") is not None and e.get("unit"):
        s.harvest[e["unit"]] = s.harvest.get(e["unit"], Decimal(0)) + Decimal(str(e["amount"]))


def summarize(entries: list[dict]) -> DiarySummary:
    s = DiarySummary()
    for e in entries:
        _add(s, e)
    return s


def summarize_by_field(entries: list[dict]) -> dict[str, DiarySummary]:
    out: dict[str, DiarySummary] = {}
    for e in entries:
        _add(out.setdefault(e["field_id"], DiarySummary()), e)
    return out
