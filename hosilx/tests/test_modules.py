import asyncio
import logging
import re
import unittest
from decimal import Decimal
from functools import partial

from bot.i18n import tr
from bot.middlewares import Heartbeat
from bot.repositories import Repo
from bot.services import specs as S
from bot.services.keepalive import keepalive_loop
from bot.utils import diary as D

t = partial(tr, "uz")
SQL = open("supabase/migration13_services.sql", encoding="utf-8").read()


def block(table: str) -> str:
    a = SQL.index(f"create table if not exists public.{table} (")
    return SQL[a: SQL.index("\n);", a)]


def checks(table: str) -> dict[str, set[str]]:
    return {m.group(1): set(re.findall(r"'([^']+)'", m.group(2))) for m in re.finditer(r"check \((?:\w+ is null or )?(\w+) in \(([^)]*)\)\)", block(table))}


class SqlConsistency(unittest.TestCase):
    """Bot tanlovlari va maydonlari bazadagi CHECK cheklovlari bilan bir xil bo'lishi shart (aks holda saqlashda baza xatosi chiqadi)."""

    def test_specs_match_migration13(self):
        for sp in S.SPECS.values():
            cols, ch = block(sp.table), checks(sp.table)
            for f in sp.fields:
                self.assertRegex(cols, rf"\b{f.key}\b", f"{sp.table}.{f.key}: ustun yo'q")
                if f.kind == "choice":
                    self.assertEqual(ch.get(f.key), set(f.choices), f"{sp.table}.{f.key}")
            if sp.parent_col:
                self.assertRegex(cols, rf"\b{sp.parent_col}\b")

    def test_diary_matches_migration13(self):
        c = checks("field_entries")
        self.assertEqual(c["kind"], set(D.ENTRY_KINDS))
        self.assertEqual(c["unit"], set(D.UNITS))

    def test_required_fields_are_not_null_in_sql(self):
        for sp in S.SPECS.values():
            for f in sp.fields:
                if f.required:  # majburiy maydon SQL'da alohida qatorda va not null bo'lishi kerak
                    line = next(l for l in block(sp.table).splitlines() if re.match(rf"\s*{f.key}\b", l))
                    self.assertIn("not null", line, f"{sp.table}.{f.key}")

    def test_every_table_has_rls_and_owner_policy(self):
        for tbl in [sp.table for sp in S.SPECS.values()] + ["farm_fields", "field_entries", "service_requests", "service_reports"]:
            self.assertIn(tbl, SQL)
        self.assertIn("pharmacy_items enable row level security", SQL)
        self.assertIn("alter table public.service_requests enable row level security", SQL)
        self.assertNotRegex(SQL, r"(?i)drop table|truncate|delete from")  # additive


class Formatting(unittest.TestCase):
    def test_price_and_route(self):
        row = {"title": "MTZ-80", "kind": "tractor", "region": "Samarqand", "price": 500000, "currency": "UZS", "price_unit": "day"}
        self.assertEqual(S.fact(S.MC, row, "price", t, "uz"), "500 000 UZS/kun")
        fr = {"from_region": "Buxoro", "to_region": "Toshkent shahri", "capacity_tons": 10}
        self.assertEqual(S.fact(S.FR, fr, "from_region", t, "uz"), "Buxoro → Toshkent shahri")
        self.assertEqual(S.fact(S.FR, fr, "capacity_tons", t, "uz"), "10 tonna")
        self.assertEqual(S.fact(S.FR, {"from_region": "Buxoro"}, "from_region", t, "ru"), "Бухара")

    def test_detail_escapes_html_and_hides_empty(self):
        row = {"title": "<b>x</b>&", "kind": "tractor", "region": "Samarqand", "district": None, "description": "<script>", "price": 5, "currency": "USD", "price_unit": "hour", "with_operator": True, "delivery": False}
        text = S.detail_text(S.MC, row, t, "uz")
        self.assertIn("&lt;b&gt;x&lt;/b&gt;&amp;", text)
        self.assertNotIn("<script>", text)
        self.assertNotIn("Tuman", text)
        self.assertIn("Operator bilan: Ha", text)
        self.assertIn("Yetkazib berish: Yo‘q", text)

    def test_summary_line_for_each_spec(self):
        self.assertIn("Urug‘", S.summary_line(S.PI, {"name": "x", "category": "seed", "price": 1000, "currency": "UZS", "unit": "kg", "in_stock": True}, t, "uz"))


class Wiring(unittest.TestCase):
    def test_router_prefixes_match_specs(self):
        src = open("bot/handlers/services.py", encoding="utf-8").read()
        group = re.search(r'^P = r"\(([a-z|]+)\)"', src, re.M).group(1)
        self.assertEqual(set(group.split("|")), set(S.SPECS))

    def test_repository_accepts_every_field_the_ui_collects(self):
        from tests.test_repo import mk, run  # soxta Supabase
        for sp in S.SPECS.values():
            data = {f.key: "x" for f in sp.fields}
            if sp.parent_col:
                data[sp.parent_col] = "p"
            repo, _ = mk({sp.table: [{"id": "n1"}]})
            self.assertEqual(run(repo.svc_insert(sp.table, "me", data)), "n1", sp.table)

    def test_menu_no_longer_marks_working_modules_as_planned(self):
        src = open("bot/handlers/menu.py", encoding="utf-8").read()
        self.assertIn('for _k in ("m_passport",):', src)


class Diary(unittest.TestCase):
    def test_summaries(self):
        e = [{"field_id": "a", "kind": "harvest", "amount": 1000, "unit": "kg", "cost": None, "currency": "UZS"},
             {"field_id": "a", "kind": "harvest", "amount": "2.5", "unit": "t", "cost": None, "currency": "UZS"},
             {"field_id": "a", "kind": "fertilizing", "amount": 50, "unit": "kg", "cost": 300000, "currency": "UZS"},
             {"field_id": "b", "kind": "expense", "amount": None, "unit": None, "cost": 20, "currency": "USD"},
             {"field_id": "b", "kind": "irrigation", "amount": 5, "unit": "m3", "cost": 0, "currency": "UZS"}]
        s = D.summarize(e)
        self.assertEqual(s.count, 5)
        self.assertEqual(s.harvest, {"kg": Decimal(1000), "t": Decimal("2.5")})   # birliklar aralashtirilmaydi
        self.assertEqual(s.cost, {"UZS": Decimal(300000), "USD": Decimal(20)})    # valyutalar aralashtirilmaydi
        self.assertEqual(s.by_kind["harvest"], 2)
        bf = D.summarize_by_field(e)
        self.assertEqual((bf["a"].count, bf["b"].count), (3, 2))
        self.assertEqual(D.summarize([]).count, 0)


class Runtime(unittest.TestCase):
    def test_heartbeat_counts_updates(self):
        stats = {}
        async def go():
            async def h(event, data):
                return "ok"
            hb = Heartbeat(stats)
            await hb(h, object(), {})
            await hb(h, object(), {})
        asyncio.run(go())
        self.assertEqual(stats["updates"], 2)
        self.assertIsNotNone(stats["last"])

    def test_keepalive_logs_first_success_and_repeated_failures(self):
        async def scenario(fetch):
            stop = asyncio.Event()
            task = asyncio.create_task(keepalive_loop("https://x.onrender.com", 0.01, stop, fetch, initial_delay=0))
            await asyncio.sleep(0.12)
            stop.set()
            await asyncio.wait_for(task, 2)

        async def ok(url):
            return 200

        async def bad(url):
            raise RuntimeError("x")

        with self.assertLogs("bot.services.keepalive", level="INFO") as cm:
            asyncio.run(scenario(ok))
        self.assertEqual(sum("birinchi chaqiruv muvaffaqiyatli" in m for m in cm.output), 1)   # takror yozilmaydi
        with self.assertLogs("bot.services.keepalive", level="WARNING") as cm:
            asyncio.run(scenario(bad))
        self.assertEqual(sum("3 marta ketma-ket" in m for m in cm.output), 1)


if __name__ == "__main__":
    unittest.main()
