"""Narx statistikasi: faqat platformadagi haqiqiy faol e'lonlardan. Ma'lumot bo'lmasa bo'sh natija: narx o'ylab topilmaydi."""
from __future__ import annotations

from decimal import Decimal
from statistics import median


def price_stats(rows: list[dict]) -> list[dict]:
    """rows: {price, currency, unit, created_at}. Valyuta va birlik bo'yicha alohida guruhlanadi."""
    groups: dict[tuple[str, str], list[Decimal]] = {}
    last: dict[tuple[str, str], str] = {}
    for r in rows:
        try:
            p = Decimal(str(r["price"]))
        except Exception:
            continue
        if p <= 0:
            continue
        k = (r["currency"], r["unit"])
        groups.setdefault(k, []).append(p)
        last[k] = max(last.get(k, ""), str(r.get("created_at") or "")[:10])
    out = []
    for (cur, unit), ps in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        out.append({"currency": cur, "unit": unit, "observations": len(ps), "min_price": min(ps), "max_price": max(ps),
                    "median_price": Decimal(str(median(ps))), "last_date": last[(cur, unit)]})
    return out
