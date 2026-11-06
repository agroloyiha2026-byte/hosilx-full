"""Render'ning bepul web xizmati 15 daqiqa TASHQARIDAN so'rov kelmasa uxlaydi. Polling botning Telegramga yuboradigan
so'rovlari buni to'xtatmaydi, shuning uchun bot o'zining ommaviy manzilidagi /health ni muntazam chaqirib turadi.
Eslatma: bu ishonchli ISHLASH KAFOLATI emas (Render siyosati o'zgarishi mumkin); kafolat uchun pullik tarif kerak."""
from __future__ import annotations

import asyncio
import logging
from typing import Awaitable, Callable

log = logging.getLogger(__name__)


async def _http_get(url: str) -> int:
    import aiohttp

    async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=20)) as s:
        async with s.get(url, headers={"user-agent": "hosilx-keepalive"}) as r:
            return r.status


async def keepalive_loop(url: str, interval: float, stop: asyncio.Event, fetch: Callable[[str], Awaitable[int]] = _http_get,
                         initial_delay: float = 30.0) -> int:
    """Muvaffaqiyatli chaqiruvlar sonini qaytaradi (test uchun). Xatolar siklni to'xtatmaydi."""
    target = url.rstrip("/") + "/health"
    ok = fails = 0
    try:  # birinchi chaqiruvdan oldin xizmat ommaviy manzilda tayyor bo'lishi uchun kutiladi
        await asyncio.wait_for(stop.wait(), timeout=initial_delay)
    except asyncio.TimeoutError:
        pass
    while not stop.is_set():
        try:
            status = await fetch(target)
            if status < 400:
                if ok == 0:
                    log.info("keepalive: birinchi chaqiruv muvaffaqiyatli (%s)", target)
                ok += 1
                fails = 0
            else:
                fails += 1
                log.warning("keepalive: javob statusi %s", status)
        except Exception as e:
            fails += 1
            log.warning("keepalive xatosi: %s", type(e).__name__)
        if fails == 3:  # bir marta, spam bo'lmasin
            log.warning("keepalive 3 marta ketma-ket ishlamadi: RENDER_EXTERNAL_URL / KEEPALIVE_URL ni tekshiring (%s)", target)
        try:
            await asyncio.wait_for(stop.wait(), timeout=interval)
        except asyncio.TimeoutError:
            pass
    return ok
