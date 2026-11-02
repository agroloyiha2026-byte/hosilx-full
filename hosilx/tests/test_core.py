import unittest
from datetime import date, datetime, timezone
from decimal import Decimal

from bot.config import ConfigError, load_settings
from bot.utils import ai_prompts, finance, links, notify, pagination, validators as v

UTC = timezone.utc
TOKEN = "123456789:" + "A" * 35  # soxta, test uchun
ENV = {"TELEGRAM_BOT_TOKEN": TOKEN, "SUPABASE_URL": "https://x.supabase.co", "SUPABASE_SERVICE_KEY": "k"}


class Validators(unittest.TestCase):
    def test_phone(self):
        self.assertEqual(v.normalize_phone("+998 90 123 45 67"), "+998901234567")
        self.assertEqual(v.normalize_phone("901234567"), "+998901234567")
        self.assertEqual(v.normalize_phone("998901234567"), "+998901234567")
        for bad in ["", None, "12345", "+99890123456", "+7999123456789", "abc"]:
            self.assertIsNone(v.normalize_phone(bad), bad)

    def test_name_and_text(self):
        self.assertEqual(v.valid_name("  Ali   Valiyev "), "Ali Valiyev")
        for bad in ["", "A", "1234", "x" * 81, None]:
            self.assertIsNone(v.valid_name(bad), bad)
        self.assertEqual(v.clean_text("a\x00b\x07c  d"), "abc d")

    def test_roles_never_admin(self):
        self.assertTrue(v.valid_role("farmer"))
        self.assertFalse(v.valid_role("admin"))
        self.assertFalse(v.valid_role(None))

    def test_search_sanitize(self):
        self.assertEqual(v.sanitize_search("a,b(c)%d"), "a b c  d")

    def test_amount(self):
        self.assertEqual(v.parse_amount("12 500,5"), Decimal("12500.5"))
        for bad in ["0", "-5", "abc", "1.234", "", None, "1e5", "9999999999999"]:
            self.assertIsNone(v.parse_amount(bad), bad)

    def test_dates(self):
        today = date(2026, 10, 20)
        self.assertEqual(v.parse_date("bugun", today), today)
        self.assertEqual(v.parse_date("Ertaga", today), date(2026, 10, 21))
        self.assertEqual(v.parse_date("25.12.2026", today), date(2026, 12, 25))
        self.assertIsNone(v.parse_date("32.13.2026", today))
        self.assertIsNone(v.parse_date("1999-01-01", today))
        now = datetime(2026, 10, 20, 12, tzinfo=UTC)
        d = v.parse_due("ertaga 18:30", now)
        self.assertEqual((d.day, d.hour, d.minute), (21, 18, 30))
        self.assertEqual(v.parse_due("25.12.2026", now).hour, 9)
        self.assertIsNone(v.parse_due("25.12.2026 25:00", now))
        self.assertEqual(v.to_utc_iso(v.parse_due("25.12.2026 10:00", now)), "2026-12-25T05:00:00+00:00")  # UTC+5


class Pagination(unittest.TestCase):
    def test_paginate(self):
        items = list(range(23))
        self.assertEqual(pagination.paginate(items, 0, 10)[2], 3)
        self.assertEqual(pagination.paginate(items, 99, 10)[0], [20, 21, 22])
        self.assertEqual(pagination.paginate([], 0, 10), ([], 0, 1))

    def test_db_window(self):
        self.assertEqual(pagination.db_window(2, 5), (10, 15))
        rows, more = pagination.split_extra(list(range(6)), 5)
        self.assertEqual((len(rows), more), (5, True))
        self.assertFalse(pagination.split_extra([1, 2], 5)[1])


class Links(unittest.TestCase):
    def test_parse(self):
        self.assertEqual(links.parse_link_command("/link abcd2345"), "ABCD2345")
        for bad in ["/link", "/link ab", "/link a b c", "/link ABC-DEF12", None, "/link " + "A" * 13]:
            self.assertIsNone(links.parse_link_command(bad), bad)

    def test_expiry(self):
        now = datetime(2026, 1, 1, 12, tzinfo=UTC)
        self.assertTrue(links.is_expired("2026-01-01T11:59:59Z", now))
        self.assertFalse(links.is_expired("2026-01-01T12:00:01+00:00", now))


class Finance(unittest.TestCase):
    def test_categories_depend_on_kind_and_flag(self):
        self.assertNotIn("seeds", finance.categories("income", True))
        self.assertIn("subsidy", finance.categories("income", True))
        self.assertNotIn("subsidy", finance.categories("income", False))
        self.assertNotIn("sales", finance.categories("expense", False))

    def test_summarize_separates_currencies_and_skips_planned(self):
        r = finance.summarize([
            {"kind": "income", "category": "sales", "amount": 1000, "currency": "UZS", "planned": False},
            {"kind": "expense", "category": "seeds", "amount": "400.5", "currency": "UZS", "planned": False},
            {"kind": "income", "category": "sales", "amount": 50, "currency": "USD", "planned": False},
            {"kind": "expense", "category": "labor", "amount": 999, "currency": "UZS", "planned": True},
        ])
        self.assertEqual(r["UZS"].net, Decimal("599.5"))
        self.assertEqual(r["USD"].income, Decimal(50))
        self.assertEqual(r["UZS"].by_category, {"seeds": Decimal("400.5")})

    def test_month_bounds_and_money(self):
        self.assertEqual(finance.month_bounds(date(2026, 12, 15)), (date(2026, 12, 1), date(2027, 1, 1)))
        self.assertEqual(finance.fmt_money(Decimal("1234567.50")), "1 234 567.5")


class Notify(unittest.TestCase):
    now = datetime(2026, 1, 2, 12, tzinfo=UTC)

    def n(self, uid, created):
        return {"id": uid + created, "user_id": uid, "created_at": created}

    def test_rules(self):
        profiles = {
            "ok": {"telegram_id": 1, "telegram_notify": True, "telegram_linked_at": "2026-01-02T00:00:00Z"},
            "off": {"telegram_id": 2, "telegram_notify": False},
            "none": {"telegram_id": None},
            "linked_late": {"telegram_id": 3, "telegram_notify": True, "telegram_linked_at": "2026-01-02T11:00:00Z"},
        }
        notifs = [self.n("ok", "2026-01-02T10:00:00Z"), self.n("ok", "2026-01-01T10:00:00Z"), self.n("off", "2026-01-02T10:00:00Z"),
                  self.n("none", "2026-01-02T10:00:00Z"), self.n("ghost", "2026-01-02T10:00:00Z"), self.n("linked_late", "2026-01-02T10:00:00Z")]
        got = [x[0]["user_id"] for x in notify.select_deliverable(notifs, profiles, self.now)]
        self.assertEqual(got, ["ok"])  # eski (>24 soat), o'chirilgan, ulanmagan, ulanishdan oldingi xabarlar tashlanadi


class AiPrompts(unittest.TestCase):
    def test_prompts_are_safe_and_localized(self):
        for m in ai_prompts.MODES:
            p = ai_prompts.system_prompt(m, "ru")
            self.assertIn("Russian", p)
            self.assertIn("exact pesticide", p)
        self.assertIn("ONLY the price statistics", ai_prompts.system_prompt("price", "uz"))

    def test_content_and_extract(self):
        self.assertEqual(ai_prompts.build_user_content("hi"), "hi")
        c = ai_prompts.build_user_content("hi", "QUJD", "image/jpeg")
        self.assertEqual(c[0]["type"], "image")
        self.assertEqual(ai_prompts.build_user_content("hi", "QUJD", "image/gif"), "hi")
        self.assertEqual(ai_prompts.extract_text({"content": [{"type": "text", "text": "a"}, {"type": "tool_use"}, {"type": "text", "text": "b"}]}), "ab")
        self.assertEqual(ai_prompts.extract_text({}), "")
        self.assertTrue(ai_prompts.limit_exceeded(50, 50))
        self.assertFalse(ai_prompts.limit_exceeded(49, 50))


class Config(unittest.TestCase):
    def test_valid_and_masked(self):
        s = load_settings(ENV)
        self.assertEqual(s.mode, "polling")
        self.assertNotIn(TOKEN, repr(s))

    def test_errors(self):
        for patch, why in [({"TELEGRAM_BOT_TOKEN": "bad"}, "token"), ({"SUPABASE_URL": "http://x"}, "http"), ({"BOT_MODE": "x"}, "mode"),
                           ({"BOT_MODE": "webhook"}, "webhook url"), ({"WEB_URL": "http://x"}, "web http"), ({"PORT": "abc"}, "port")]:
            with self.assertRaises(ConfigError, msg=why):
                load_settings({**ENV, **patch})
        with self.assertRaises(ConfigError):
            load_settings({k: x for k, x in ENV.items() if k != "SUPABASE_SERVICE_KEY"})

    def test_old_bot_token_name_is_accepted(self):
        env = {k: x for k, x in ENV.items() if k != "TELEGRAM_BOT_TOKEN"}
        self.assertEqual(load_settings({**env, "BOT_TOKEN": TOKEN}).bot_token, TOKEN)
        with self.assertRaises(ConfigError):
            load_settings(env)

    def test_webhook(self):
        s = load_settings({**ENV, "BOT_MODE": "webhook", "WEBHOOK_URL": "https://bot.onrender.com/", "WEBHOOK_SECRET": "a" * 20})
        self.assertEqual(s.webhook_url, "https://bot.onrender.com")


if __name__ == "__main__":
    unittest.main()


class RateLimit(unittest.TestCase):
    def test_window(self):
        from bot.utils.ratelimit import RateLimiter
        rl = RateLimiter(limit=3, per=10)
        self.assertTrue(all(rl.allow(1, t) for t in (0, 1, 2)))
        self.assertFalse(rl.allow(1, 3))
        self.assertTrue(rl.allow(2, 3))        # boshqa foydalanuvchi ta'sirlanmaydi
        self.assertTrue(rl.allow(1, 11.5))     # oyna o'tgach qayta ruxsat


class Regions(unittest.TestCase):
    def test_labels(self):
        from bot.utils.regions import REGIONS, region_by_index, region_label
        self.assertEqual(len(REGIONS), 14)
        for r in REGIONS:
            self.assertTrue(region_label(r, "ru") and region_label(r, "en"))
        self.assertIsNone(region_by_index(99))


class Registration(unittest.TestCase):
    def test_next_step_and_reset(self):
        from bot.utils import registration as r
        d = {}
        order = []
        fill = {"name": {"full_name": "Ali"}, "role": {"role": "farmer"}, "phone": {"phone": "+998901234567"}, "region": {"region": "Samarqand"},
                "district": {"district": "Urgut"}, "business": {"business_name": ""}, "consent": {"consent_at": "2026-01-01T00:00:00Z"}}
        while (s := r.next_step(d)) != "confirm":
            order.append(s)
            d.update(fill[s])
        self.assertEqual(order, ["name", "role", "phone", "region", "district", "business", "consent"])
        self.assertEqual(r.next_step({**d, "business_name": None}), "business")  # "" = o'tkazib yuborilgan, None = hali so'ralmagan
        d.update(r.reset_patch("phone"))
        self.assertEqual(r.next_step(d), "phone")
        self.assertEqual(r.prev_step("name"), "name")
        self.assertEqual(r.prev_step("consent"), "business")


class Prices(unittest.TestCase):
    def test_grouping_median_and_bad_rows(self):
        from bot.utils.prices import price_stats
        rows = [{"price": 100, "currency": "UZS", "unit": "kg", "created_at": "2026-01-02T10:00:00Z"},
                {"price": "300", "currency": "UZS", "unit": "kg", "created_at": "2026-01-05T10:00:00Z"},
                {"price": 200, "currency": "UZS", "unit": "kg", "created_at": "2026-01-01T10:00:00Z"},
                {"price": 5, "currency": "USD", "unit": "kg", "created_at": "2026-01-01T10:00:00Z"},
                {"price": 0, "currency": "UZS", "unit": "kg"}, {"price": "x", "currency": "UZS", "unit": "kg"}]
        r = price_stats(rows)
        self.assertEqual([(x["currency"], x["observations"]) for x in r], [("UZS", 3), ("USD", 1)])  # valyutalar aralashmaydi
        self.assertEqual((r[0]["min_price"], r[0]["median_price"], r[0]["max_price"]), (100, 200, 300))
        self.assertEqual(r[0]["last_date"], "2026-01-05")
        self.assertEqual(price_stats([]), [])  # ma'lumot yo'q: bo'sh natija, narx o'ylab topilmaydi


class Keepalive(unittest.TestCase):
    def test_legacy_token_name_and_url_resolution(self):
        from bot.config import resolve_keepalive_url
        env = {k: x for k, x in ENV.items() if k != "TELEGRAM_BOT_TOKEN"}
        self.assertEqual(load_settings({**env, "BOT_TOKEN": TOKEN}).bot_token, TOKEN)   # eski bot nomi ham ishlaydi
        self.assertEqual(resolve_keepalive_url({"RENDER_EXTERNAL_URL": "https://bot.onrender.com/"}), "https://bot.onrender.com")
        self.assertEqual(resolve_keepalive_url({"KEEPALIVE_URL": "https://a.b", "RENDER_EXTERNAL_URL": "https://c.d"}), "https://a.b")
        self.assertEqual(resolve_keepalive_url({"RENDER_EXTERNAL_URL": "https://x.y", "KEEPALIVE": "off"}), "")
        self.assertEqual(resolve_keepalive_url({"RENDER_EXTERNAL_URL": "http://x.y"}), "")   # faqat https
        self.assertEqual(resolve_keepalive_url({}), "")
        s = load_settings({**ENV, "RENDER_EXTERNAL_URL": "https://bot.onrender.com"})
        self.assertEqual((s.keepalive_url, s.keepalive_interval), ("https://bot.onrender.com", 600))
        for bad in ("30", "900", "abc"):
            with self.assertRaises(ConfigError, msg=bad):
                load_settings({**ENV, "KEEPALIVE_INTERVAL": bad})

    def test_loop_pings_health_and_survives_errors(self):
        import asyncio
        from bot.services.keepalive import keepalive_loop

        async def scenario():
            calls, stop = [], asyncio.Event()

            async def fetch(url):
                calls.append(url)
                if len(calls) == 2:
                    raise RuntimeError("tarmoq xatosi")      # sikl to'xtamasligi kerak
                return 200 if len(calls) != 3 else 503

            task = asyncio.create_task(keepalive_loop("https://bot.onrender.com/", 0.01, stop, fetch, initial_delay=0))
            await asyncio.sleep(0.15)
            stop.set()
            ok = await asyncio.wait_for(task, 2)
            return calls, ok

        calls, ok = asyncio.run(scenario())
        self.assertGreaterEqual(len(calls), 5)
        self.assertTrue(all(c == "https://bot.onrender.com/health" for c in calls))
        self.assertGreaterEqual(ok, 3)                       # xato va 503 dan keyin ham muvaffaqiyatli chaqiruvlar davom etadi
