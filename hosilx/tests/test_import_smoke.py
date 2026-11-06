"""Tutun testi: barcha handler/servis modullari import qilinadi (decorator'lar, importlar, nomlar tekshiriladi).
aiogram o'rnatilmagan muhitda soddalashtirilgan o'rinbosarlar ishlatiladi; ular aiogram xatti-harakatini TEKSHIRMAYDI,
faqat bizning kod bog'lanishlarini. Haqiqiy aiogram bilan to'liq tekshiruv uchun: pip install -r requirements.txt."""
import importlib
import sys
import types
import unittest


class _Any:
    def __init__(self, *a, **k): ...
    def __getattr__(self, n): return _Any()
    def __call__(self, *a, **k): return _Any()


def _install_stubs():
    def mod(name, **attrs):
        m = types.ModuleType(name)
        m.__dict__.update(attrs)
        sys.modules[name] = m
        return m

    class Router:
        def __init__(self, *a, **k): ...
        def message(self, *a, **k): return lambda f: f
        callback_query = message
        def include_routers(self, *a): ...

    class State: ...
    class StatesGroup: ...
    class BaseMiddleware: ...
    names = ["Message", "CallbackQuery", "InlineKeyboardButton", "InlineKeyboardMarkup", "KeyboardButton", "ReplyKeyboardMarkup", "ReplyKeyboardRemove", "ErrorEvent", "BotCommand"]
    exc = {n: type(n, (Exception,), {}) for n in ("TelegramBadRequest", "TelegramForbiddenError", "TelegramRetryAfter", "TelegramAPIError", "TelegramConflictError")}
    mod("aiogram", Router=Router, F=_Any(), Bot=_Any, Dispatcher=_Any, BaseMiddleware=BaseMiddleware)
    mod("aiogram.filters", Command=_Any(), CommandStart=_Any(), StateFilter=_Any())
    mod("aiogram.fsm"); mod("aiogram.fsm.context", FSMContext=_Any)
    mod("aiogram.fsm.state", State=State, StatesGroup=StatesGroup)
    mod("aiogram.types", **{n: _Any for n in names})
    mod("aiogram.client"); mod("aiogram.client.default", DefaultBotProperties=_Any)
    mod("aiogram.enums", ParseMode=_Any())
    mod("aiogram.fsm.storage"); mod("aiogram.fsm.storage.memory", MemoryStorage=_Any)
    mod("aiogram.exceptions", **exc)


try:
    import aiogram  # noqa: F401
except ImportError:
    _install_stubs()
try:
    import aiohttp  # noqa: F401
except ImportError:
    _m = types.ModuleType("aiohttp")
    _m.web = _Any()
    sys.modules["aiohttp"] = _m

MODULES = ["bot.ui", "bot.states", "bot.middlewares", "bot.services.notifier", "bot.services.ai", "bot.services.summary",
           "bot.handlers.common", "bot.handlers.menu", "bot.handlers.start", "bot.handlers.market", "bot.handlers.warehouses",
           "bot.handlers.planner", "bot.handlers.finance", "bot.handlers.ai", "bot.handlers.profile", "bot.handlers.reports", "bot.handlers.services", "bot.handlers.diary", "bot.handlers.fallback", "bot.main"]


class Smoke(unittest.TestCase):
    def test_all_modules_import(self):
        for m in MODULES:
            with self.subTest(module=m):
                importlib.import_module(m)

    def test_handlers_define_router(self):
        for m in MODULES:
            if m.startswith("bot.handlers.") and not m.endswith("common"):
                self.assertTrue(hasattr(importlib.import_module(m), "router"), m)

    def test_ui_helpers_escape_html(self):
        ui = importlib.import_module("bot.ui")
        self.assertEqual(ui.esc("<b>&x</b>"), "&lt;b&gt;&amp;x&lt;/b&gt;")
        self.assertEqual(ui.esc(None), "")


if __name__ == "__main__":
    unittest.main()
