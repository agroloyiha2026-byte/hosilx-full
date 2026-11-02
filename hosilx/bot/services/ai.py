"""AI adapteri. Provayderni almashtirish uchun AiProvider interfeysi; hozir Anthropic. Kalit va model FAQAT environment'dan."""
from __future__ import annotations

import asyncio
import logging
from typing import Protocol

from ..config import Settings
from ..utils.ai_prompts import extract_text

log = logging.getLogger(__name__)


class AiError(Exception):
    def __init__(self, kind: str):
        super().__init__(kind)
        self.kind = kind  # rate | timeout | network | provider | empty


class AiProvider(Protocol):
    async def complete(self, system: str, messages: list[dict], max_tokens: int = 800) -> str: ...


class AnthropicProvider:
    URL = "https://api.anthropic.com/v1/messages"

    def __init__(self, api_key: str, model: str):
        self._key, self._model = api_key, model

    async def complete(self, system: str, messages: list[dict], max_tokens: int = 800) -> str:
        import aiohttp

        headers = {"x-api-key": self._key, "anthropic-version": "2023-06-01", "content-type": "application/json"}
        payload = {"model": self._model, "max_tokens": max_tokens, "system": system, "messages": messages}
        try:
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=45)) as s:
                async with s.post(self.URL, json=payload, headers=headers) as r:
                    if r.status == 429:
                        raise AiError("rate")
                    if r.status >= 400:
                        log.warning("AI provayder status %s", r.status)  # tana va sarlavhalar logga yozilmaydi
                        raise AiError("provider")
                    data = await r.json()
        except asyncio.TimeoutError as e:
            raise AiError("timeout") from e
        except aiohttp.ClientError as e:
            raise AiError("network") from e
        text = extract_text(data)
        if not text:
            raise AiError("empty")
        return text


def build_provider(s: Settings) -> AiProvider | None:
    """Kalit yoki model bo'lmasa None: bot "AI sozlanmagan" deydi, o'ylab topilgan javob bermaydi."""
    return AnthropicProvider(s.anthropic_api_key, s.ai_model) if s.anthropic_api_key and s.ai_model else None
