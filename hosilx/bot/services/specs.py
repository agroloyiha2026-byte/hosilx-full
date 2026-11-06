"""E'lon modullari (agroapteka, texnika ijarasi, logistika) tavsifi. Bitta umumiy mexanizm shu tavsiflar bo'yicha ishlaydi.
Maydon nomlari va tanlov qiymatlari migration13 dagi ustunlar/CHECK cheklovlari bilan bir xil bo'lishi SHART (test tekshiradi)."""
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from html import escape

from ..utils.finance import fmt_money
from ..utils.regions import region_label

CURRENCIES = ("UZS", "USD")
REPORT_REASONS = ("spam", "fraud", "wrong", "other")


@dataclass(frozen=True)
class F:
    key: str
    kind: str                       # text | num | choice | region | bool | phone
    choices: tuple[str, ...] = ()
    required: bool = False
    max_len: int = 120


@dataclass(frozen=True)
class Spec:
    key: str                        # callback prefiksi
    table: str
    menu: str
    title_col: str
    fields: tuple[F, ...]
    summary: tuple[str, ...]
    q_cols: tuple[str, ...]
    filter_col: str | None = None
    request_kind: str | None = None
    parent_col: str | None = None
    moderated: bool = True
    region_col: str | None = "region"
    report_kind: str = ""


PH = Spec("ph", "pharmacies", "m_agro", "name", (
    F("name", "text", required=True), F("description", "text", max_len=600), F("region", "region", required=True), F("district", "text", max_len=80),
    F("address", "text", max_len=160), F("phone", "phone"), F("work_hours", "text", max_len=80)),
    summary=("district", "region"), q_cols=("name", "description", "district"), report_kind="pharmacy")
PI = Spec("pi", "pharmacy_items", "m_agro", "name", (
    F("name", "text", required=True), F("category", "choice", ("seed", "seedling", "fertilizer", "pesticide", "other"), True), F("price", "num"),
    F("currency", "choice", CURRENCIES, True), F("unit", "text", max_len=20), F("in_stock", "bool"), F("usage_note", "text", max_len=300)),
    summary=("category", "price", "in_stock"), q_cols=("name",), filter_col="category", request_kind="pharmacy_item", parent_col="pharmacy_id",
    moderated=False, region_col=None, report_kind="pharmacy_item")
MC = Spec("mc", "machinery_listings", "m_machinery", "title", (
    F("kind", "choice", ("tractor", "combine", "seeder", "sprayer", "other"), True), F("title", "text", required=True), F("description", "text", max_len=600),
    F("region", "region", required=True), F("district", "text", max_len=80), F("price", "num", required=True), F("currency", "choice", CURRENCIES, True),
    F("price_unit", "choice", ("hour", "day", "month"), True), F("with_operator", "bool"), F("delivery", "bool"), F("phone", "phone")),
    summary=("kind", "price", "region"), q_cols=("title", "description", "district"), filter_col="kind", request_kind="machinery", report_kind="machinery")
FR = Spec("fr", "freight_listings", "m_logistics", "title", (
    F("vehicle_type", "choice", ("truck", "refrigerator", "pickup", "trailer", "other"), True), F("title", "text", required=True),
    F("capacity_tons", "num", required=True), F("from_region", "region", required=True), F("to_region", "region"), F("price", "num"),
    F("currency", "choice", CURRENCIES, True), F("price_unit", "choice", ("km", "ton", "trip", "negotiable"), True),
    F("return_trip", "bool"), F("shared_load", "bool"), F("phone", "phone"), F("description", "text", max_len=600)),
    summary=("vehicle_type", "capacity_tons", "from_region"), q_cols=("title", "description"), filter_col="vehicle_type",
    request_kind="freight", region_col="from_region", report_kind="freight")

SPECS: dict[str, Spec] = {s.key: s for s in (PH, PI, MC, FR)}


def _e(x) -> str:
    return escape(str(x), quote=False)


def field_by_key(spec: Spec, key: str) -> F:
    return next(f for f in spec.fields if f.key == key)


def fmt_value(f: F, v, t, lang: str) -> str:
    """Bitta maydon qiymatini odam o'qiydigan ko'rinishga keltiradi (HTML-escape qilingan)."""
    if v is None or v == "":
        return ""
    if f.kind == "bool":
        return t("yes") if v else t("no")
    if f.kind == "region":
        return _e(region_label(str(v), lang))
    if f.kind == "choice":
        return _e(v) if f.key == "currency" else t(f"ch_{v}")
    if f.kind == "num":
        return fmt_money(Decimal(str(v)))
    return _e(v)


def fact(spec: Spec, row: dict, key: str, t, lang: str) -> str:
    """Maydon qiymati; narx valyuta va birlik bilan, hudud marshrut bilan birga."""
    f = field_by_key(spec, key)
    v = fmt_value(f, row.get(key), t, lang)
    if not v:
        return ""
    if key == "price":
        unit = row.get("price_unit") or row.get("unit")
        suffix = f"/{t('ch_' + unit) if row.get('price_unit') else _e(unit)}" if unit else ""
        return f"{v} {_e(row.get('currency') or 'UZS')}{suffix}"
    if key == "capacity_tons":
        return f"{v} {t('tons')}"
    if key == "from_region" and row.get("to_region"):
        return f"{v} → {fmt_value(field_by_key(spec, 'to_region'), row['to_region'], t, lang)}"
    return v


def summary_line(spec: Spec, row: dict, t, lang: str) -> str:
    return " · ".join(x for x in (fact(spec, row, k, t, lang) for k in spec.summary) if x)


def detail_text(spec: Spec, row: dict, t, lang: str) -> str:
    lines = [f"<b>{_e(row.get(spec.title_col))}</b>"]
    for f in spec.fields:
        if f.key == spec.title_col or f.key == "currency" or f.key == "price_unit" or f.key == "to_region":
            continue
        v = fact(spec, row, f.key, t, lang)
        if v:
            lines.append(f"{t('fl_' + f.key)}: {v}")
    return "\n".join(lines)
