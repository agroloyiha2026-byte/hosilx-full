"""AI so'rovlari uchun toza yordamchilar (tarmoq chaqiruvi yo'q)."""
from __future__ import annotations

MODES = ("doctor", "agro", "price", "finance", "general")
LANG_NAMES = {"uz": "Uzbek", "ru": "Russian", "en": "English"}

_COMMON = (
    "You are the Hosil X assistant for farmers in Uzbekistan. Reply in {lang}. Be short, practical and honest. "
    "Never present uncertain claims as facts and say clearly when information is insufficient. "
    "Do not give exact pesticide or chemical doses; tell the user to follow the product label and local regulations."
)
_MODE = {
    "doctor": "Mode: plant problem assistant. Give POSSIBLE causes and next steps based on the crop, symptoms, region and photo if present. "
              "This is a probabilistic suggestion, not a definitive diagnosis. Ask follow-up questions if details are missing.",
    "agro": "Mode: agronomy advisor for crops, irrigation, fertilizing and care.",
    "price": "Mode: price helper. Use ONLY the price statistics supplied in the message. If none are supplied, say there is no data. Never invent prices.",
    "finance": "Mode: farm finance helper. Use ONLY the finance summary supplied in the message; do not invent numbers.",
    "general": "Mode: general farming questions.",
}


def system_prompt(mode: str, lang: str) -> str:
    return _COMMON.format(lang=LANG_NAMES.get(lang, "Uzbek")) + " " + _MODE.get(mode, _MODE["general"])


def build_user_content(text: str, image_b64: str | None = None, media_type: str | None = None):
    if image_b64 and media_type in {"image/jpeg", "image/png", "image/webp"}:
        return [{"type": "image", "source": {"type": "base64", "media_type": media_type, "data": image_b64}}, {"type": "text", "text": text}]
    return text


def extract_text(resp: dict) -> str:
    return "".join(b.get("text", "") for b in (resp.get("content") or []) if isinstance(b, dict) and b.get("type") == "text").strip()


def limit_exceeded(count: int, limit: int) -> bool:
    return count >= limit
