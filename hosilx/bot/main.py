"""Hosil X Telegram boti. Ishga tushirish: python -m bot.main  (BOT_MODE=polling yoki webhook)."""
from __future__ import annotations

import asyncio
import logging
import os
import sys

from aiogram import Bot, Dispatcher
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ParseMode
from aiogram.exceptions import TelegramConflictError
from aiogram.fsm.storage.memory import MemoryStorage
from aiogram.types import BotCommand
from aiohttp import web

from .config import ConfigError, Settings, load_settings
from .db import Db
from .handlers import ai, fallback, finance, market, menu, planner, profile, reports, start, warehouses
from .middlewares import Throttle, UserContext, on_error
from .repositories import Repo
from .services.ai import build_provider
from .services.notifier import notifier_loop

log = logging.getLogger("bot")

COMMANDS = {
    "uz": [("start", "Boshlash"), ("menu", "Asosiy menyu"), ("link", "Hisobni ulash"), ("cancel", "Bekor qilish"), ("help", "Yordam")],
    "ru": [("start", "Начать"), ("menu", "Главное меню"), ("link", "Привязать аккаунт"), ("cancel", "Отмена"), ("help", "Помощь")],
    "en": [("start", "Start"), ("menu", "Main menu"), ("link", "Link account"), ("cancel", "Cancel"), ("help", "Help")],
}


def make_storage(s: Settings):
    """Redis bo'lsa FSM holati qayta ishga tushganda ham saqlanadi; bo'lmasa xotirada (qayta ishga tushsa yo'qoladi)."""
    if s.redis_url:
        try:
            from aiogram.fsm.storage.redis import RedisStorage

            return RedisStorage.from_url(s.redis_url)
        except Exception:
            log.warning("Redis ishlatib bo'lmadi; FSM xotirada saqlanadi")
    return MemoryStorage()


def build_dispatcher(s: Settings, repo: Repo) -> tuple[Dispatcher, UserContext]:
    dp = Dispatcher(storage=make_storage(s))
    ctx = UserContext(repo)
    dp["repo"], dp["settings"], dp["ai"], dp["ctx"] = repo, s, build_provider(s), ctx
    for obs in (dp.message, dp.callback_query):
        obs.outer_middleware(Throttle())
        obs.outer_middleware(ctx)
    # Tartib muhim: menyu tugmalari FSM holatlaridan oldin tutiladi; fallback eng oxirida
    dp.include_routers(menu.router, start.router, market.router, warehouses.router, planner.router, finance.router, ai.router, profile.router, reports.router, fallback.router)
    dp.errors.register(on_error)
    return dp, ctx


async def health(request: web.Request) -> web.Response:
    return web.json_response({"ok": True, "mode": request.app["mode"]})


async def main() -> int:
    try:
        s = load_settings(os.environ)
    except ConfigError as e:
        print(f"Sozlama xatosi: {e}", file=sys.stderr)  # qiymatlar chop etilmaydi
        return 2
    logging.basicConfig(level=getattr(logging, s.log_level, logging.INFO), format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    for noisy in ("httpx", "httpcore", "hpack"):
        logging.getLogger(noisy).setLevel(logging.WARNING)  # URL (token) ni logga tushirmaslik uchun

    repo = Repo(Db(s.supabase_url, s.supabase_service_key))
    bot = Bot(s.bot_token, default=DefaultBotProperties(parse_mode=ParseMode.HTML))
    dp, _ = build_dispatcher(s, repo)
    for lang, cmds in COMMANDS.items():
        await bot.set_my_commands([BotCommand(command=c, description=d) for c, d in cmds], language_code=None if lang == "uz" else lang)

    app = web.Application()
    app["mode"] = s.mode
    app.router.add_get("/health", health)
    app.router.add_get("/", health)
    if s.mode == "webhook":
        from aiogram.webhook.aiohttp_server import SimpleRequestHandler, setup_application

        SimpleRequestHandler(dispatcher=dp, bot=bot, secret_token=s.webhook_secret).register(app, path=s.webhook_path)
        setup_application(app, dp, bot=bot)
        await bot.set_webhook(url=s.webhook_url + s.webhook_path, secret_token=s.webhook_secret, allowed_updates=dp.resolve_used_update_types())
    runner = web.AppRunner(app)
    await runner.setup()
    await web.TCPSite(runner, "0.0.0.0", s.port).start()

    stop = asyncio.Event()
    notifier = asyncio.create_task(notifier_loop(bot, repo, stop))
    code = 0
    try:
        if s.mode == "polling":
            await bot.delete_webhook(drop_pending_updates=False)
            try:
                await dp.start_polling(bot, allowed_updates=dp.resolve_used_update_types())
            except TelegramConflictError:
                log.error("409 Conflict: shu token bilan boshqa bot nusxasi ishlayapti. Faqat bittasi qolsin.")
                code = 1
        else:
            await asyncio.Event().wait()
    finally:
        stop.set()
        await notifier
        await bot.session.close()
        await runner.cleanup()
    return code


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
