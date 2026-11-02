"""Ro'yxatdan o'tish qadamlari mantig'i (tarmoqsiz). Qoralama bazada saqlanadi, shuning uchun bot qayta ishga tushsa ham davom etadi."""
from __future__ import annotations

STEPS = ("name", "role", "phone", "region", "district", "business", "consent", "confirm")
_FIELDS = {
    "name": ("full_name",), "role": ("role",), "phone": ("phone", "phone_from_telegram"), "region": ("region",),
    "district": ("district",), "business": ("business_name",), "consent": ("consent_at",),
}


def next_step(d: dict) -> str:
    """Birinchi to'ldirilmagan qadam. business_name == '' bo'lsa 'o'tkazib yuborilgan' hisoblanadi."""
    if not d.get("full_name"):
        return "name"
    if not d.get("role"):
        return "role"
    if not d.get("phone"):
        return "phone"
    if not d.get("region"):
        return "region"
    if not d.get("district"):
        return "district"
    if d.get("business_name") is None:
        return "business"
    if not d.get("consent_at"):
        return "consent"
    return "confirm"


def prev_step(step: str) -> str:
    i = STEPS.index(step)
    return STEPS[max(0, i - 1)]


def reset_patch(step: str) -> dict:
    """Shu qadamga qaytilganda uning maydonlari tozalanadi (qayta kiritiladi)."""
    return {f: None for f in _FIELDS.get(step, ())}
