"""Muhit sozlamalari. Maxfiy qiymatlar faqat environment'dan olinadi va hech qachon logga yozilmaydi."""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Mapping


class ConfigError(Exception):
    pass


@dataclass(frozen=True)
class Settings:
    bot_token: str
    supabase_url: str
    supabase_service_key: str
    web_url: str = ""
    mode: str = "polling"                 # polling | webhook
    webhook_url: str = ""
    webhook_secret: str = ""
    webhook_path: str = "/telegram/webhook"
    port: int = 10000
    redis_url: str = ""
    anthropic_api_key: str = ""
    ai_model: str = ""
    ai_daily_limit: int = 50
    finance_extended: bool = False        # migration10 (kengaytirilgan moliya turkumlari) qo'llangan bo'lsa true
    log_level: str = "INFO"

    def __repr__(self) -> str:  # kalitlar tasodifan chop etilmasin
        return f"Settings(mode={self.mode!r}, supabase_url={self.supabase_url!r}, web_url={self.web_url!r}, secrets=***)"


def _bool(v: str) -> bool:
    return v.strip().lower() in {"1", "true", "yes", "on"}


def load_settings(env: Mapping[str, str]) -> Settings:
    def need(name: str) -> str:
        v = (env.get(name) or "").strip()
        if not v:
            raise ConfigError(f"{name} kiritilmagan")
        return v

    token = need("TELEGRAM_BOT_TOKEN")
    if not re.fullmatch(r"\d{5,}:[A-Za-z0-9_-]{20,}", token):
        raise ConfigError("TELEGRAM_BOT_TOKEN formati noto'g'ri")
    url = need("SUPABASE_URL").rstrip("/")
    if not url.startswith("https://"):
        raise ConfigError("SUPABASE_URL https:// bilan boshlanishi kerak")
    mode = (env.get("BOT_MODE") or "polling").strip().lower()
    if mode not in {"polling", "webhook"}:
        raise ConfigError("BOT_MODE polling yoki webhook bo'lishi kerak")
    webhook_url = (env.get("WEBHOOK_URL") or "").strip().rstrip("/")
    secret = (env.get("WEBHOOK_SECRET") or "").strip()
    if mode == "webhook":
        if not webhook_url.startswith("https://"):
            raise ConfigError("webhook rejimi uchun WEBHOOK_URL (https) kerak")
        if not re.fullmatch(r"[A-Za-z0-9_-]{16,256}", secret):
            raise ConfigError("WEBHOOK_SECRET 16-256 belgi (harf, raqam, _ -) bo'lishi kerak")
    web_url = (env.get("WEB_URL") or "").strip().rstrip("/")
    if web_url and not web_url.startswith("https://"):
        raise ConfigError("WEB_URL https:// bilan boshlanishi kerak")
    try:
        port = int(env.get("PORT") or 10000)
        limit = int(env.get("AI_DAILY_LIMIT") or 50)
    except ValueError as e:
        raise ConfigError("PORT va AI_DAILY_LIMIT butun son bo'lishi kerak") from e
    return Settings(
        bot_token=token, supabase_url=url, supabase_service_key=need("SUPABASE_SERVICE_KEY"), web_url=web_url, mode=mode,
        webhook_url=webhook_url, webhook_secret=secret, port=port, redis_url=(env.get("REDIS_URL") or "").strip(),
        anthropic_api_key=(env.get("ANTHROPIC_API_KEY") or "").strip(), ai_model=(env.get("AI_MODEL") or "").strip(),
        ai_daily_limit=limit, finance_extended=_bool(env.get("FINANCE_EXTENDED_CATEGORIES") or ""),
        log_level=(env.get("LOG_LEVEL") or "INFO").strip().upper(),
    )
