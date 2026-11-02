"""Supabase mijozi (server-side, service_role). Bu kalit faqat bot muhitida turadi, hech qayerga yuborilmaydi."""
from __future__ import annotations

import asyncio
from typing import Any, Callable


class Db:
    def __init__(self, url: str, key: str):
        from supabase import create_client  # kech import: testlar va syntax-tekshiruv paket talab qilmasin

        self.client = create_client(url, key)

    async def run(self, fn: Callable[[Any], Any]) -> Any:
        """Sinxron supabase-py chaqiruvini event loopni bloklamasdan bajaradi."""
        return await asyncio.to_thread(lambda: fn(self.client))
