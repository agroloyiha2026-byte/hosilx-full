"""Repositoriya testlari: soxta Supabase mijozi so'rovlarni yozib oladi. Maqsad: egalik/ko'rinish filtrlari doim bor ekanini tekshirish
(service_role RLS'ni chetlab o'tgani uchun bu xavfsizlik uchun muhim). Haqiqiy Supabase bilan sinov EMAS."""
import asyncio
import unittest
from datetime import datetime, timezone
from types import SimpleNamespace

from bot.repositories import Repo


class Seq(list):
    """Ketma-ket javoblar: har execute() keyingisini qaytaradi."""


class Q:
    def __init__(self, client, name):
        self.client, self.name, self.calls = client, name, []

    def __getattr__(self, method):
        def f(*a, **k):
            self.calls.append((method, a, k))
            return self
        return f

    def execute(self):
        self.client.log.append((self.name, self.calls))
        resp = self.client.responses.get(self.name, [])
        data = resp.pop(0) if isinstance(resp, Seq) else resp
        if isinstance(data, Exception):
            raise data
        return SimpleNamespace(data=data)


class FakeClient:
    def __init__(self, responses=None):
        self.responses, self.log = responses or {}, []

    def table(self, name):
        return Q(self, name)

    def rpc(self, name, params):
        q = Q(self, "rpc:" + name)
        q.calls.append(("params", (params,), {}))
        return q


class FakeDb:
    def __init__(self, client):
        self.client = client

    async def run(self, fn):
        return fn(self.client)


def run(coro):
    return asyncio.run(coro)


def mk(responses=None):
    c = FakeClient(responses)
    return Repo(FakeDb(c)), c


def has(calls, method, *args):
    return any(m == method and a[: len(args)] == args for m, a, _ in calls)


NOW = datetime(2026, 1, 1, 12, tzinfo=timezone.utc)


class LinkCode(unittest.TestCase):
    def test_invalid_expired_taken_ok(self):
        r, _ = mk({"link_codes": []})
        self.assertEqual(run(r.consume_link_code("ABCDEF12", 1, NOW)), ("invalid", None))
        r, _ = mk({"link_codes": [{"user_id": "u", "expires_at": "2026-01-01T11:00:00Z"}]})
        self.assertEqual(run(r.consume_link_code("ABCDEF12", 1, NOW)), ("expired", None))
        r, _ = mk({"link_codes": [{"user_id": "u", "expires_at": "2026-01-01T13:00:00Z"}], "profiles": []})
        self.assertEqual(run(r.consume_link_code("ABCDEF12", 1, NOW)), ("taken", None))
        r, c = mk({"link_codes": [{"user_id": "u", "expires_at": "2026-01-01T13:00:00Z"}], "profiles": [{"id": "u"}]})
        self.assertEqual(run(r.consume_link_code("ABCDEF12", 1, NOW)), ("ok", "u"))
        # kod avval o'chiriladi (bir martalik), profil faqat telegram_id BO'SH bo'lsa yangilanadi
        self.assertEqual(c.log[0][0], "link_codes")
        self.assertTrue(has(c.log[0][1], "delete"))
        self.assertTrue(has(c.log[1][1], "is_", "telegram_id", "null"))
        self.assertTrue(has(c.log[1][1], "eq", "id", "u"))

    def test_unique_violation_means_taken(self):
        r, _ = mk({"link_codes": [{"user_id": "u", "expires_at": "2026-01-01T13:00:00Z"}], "profiles": Exception("23505 duplicate key")})
        self.assertEqual(run(r.consume_link_code("ABCDEF12", 1, NOW)), ("taken", None))


class Ownership(unittest.TestCase):
    def test_task_done_and_delete_are_scoped_to_user(self):
        r, c = mk()
        run(r.set_task_done("me", "t1"))
        run(r.delete_task("me", "t1"))
        for _, calls in c.log:
            self.assertTrue(has(calls, "eq", "user_id", "me"))
            self.assertTrue(has(calls, "eq", "id", "t1"))

    def test_toggle_foreign_product_is_noop(self):
        r, c = mk({"products": []})
        self.assertIsNone(run(r.toggle_product("me", "p1")))
        self.assertEqual(len(c.log), 1)  # update umuman chaqirilmagan
        self.assertTrue(has(c.log[0][1], "eq", "seller_id", "me"))

    def test_toggle_own_product_flips_status_with_owner_filter(self):
        r, c = mk({"products": Seq([[{"status": "active"}], []])})
        self.assertEqual(run(r.toggle_product("me", "p1")), "hidden")
        self.assertTrue(has(c.log[1][1], "eq", "seller_id", "me"))

    def test_storage_request_status_requires_warehouse_owner(self):
        r, c = mk({"storage_requests": [{"warehouse_id": "w"}], "warehouses": []})
        self.assertFalse(run(r.set_request_status("me", "r1", "accepted")))
        self.assertFalse(any(h for n, h in c.log if n == "storage_requests" and has(h, "update")))
        r, _ = mk()
        self.assertFalse(run(r.set_request_status("me", "r1", "hack")))

    def test_free_tons_requires_owner_and_capacity(self):
        r, _ = mk({"warehouses": Seq([[{"capacity_tons": 100}]])})
        self.assertFalse(run(r.set_free_tons("me", "w", 150)))
        r, _ = mk({"warehouses": Seq([[]])})
        self.assertFalse(run(r.set_free_tons("me", "w", 10)))
        r, c = mk({"warehouses": Seq([[{"capacity_tons": 100}], []])})
        self.assertTrue(run(r.set_free_tons("me", "w", 40)))
        self.assertTrue(has(c.log[1][1], "eq", "owner_id", "me"))


class Visibility(unittest.TestCase):
    def test_public_products_only_active_and_approved(self):
        r, c = mk({"products": []})
        run(r.products("pomi,dor(%)", "fruit", "Samarqand", 0, 5))
        calls = c.log[0][1]
        self.assertTrue(has(calls, "eq", "status", "active"))
        self.assertTrue(has(calls, "eq", "moderation_status", "approved"))
        self.assertTrue(has(calls, "eq", "category", "fruit"))
        or_arg = next(a[0] for m, a, _ in calls if m == "or_")
        self.assertNotIn("(", or_arg.split("ilike.%", 1)[1].split(",")[0])  # filtr sintaksisini buzadigan belgilar tozalangan

    def test_falls_back_when_moderation_column_missing(self):
        r, c = mk({"products": Seq([Exception('column "moderation_status" does not exist'), []])})
        rows, more = run(r.products())
        self.assertEqual((rows, more), ([], False))
        self.assertFalse(has(c.log[1][1], "eq", "moderation_status", "approved"))

    def test_pagination_extra_row_means_next_page(self):
        r, _ = mk({"products": [{"id": str(i)} for i in range(6)]})
        rows, more = run(r.products(size=5))
        self.assertEqual((len(rows), more), (5, True))


class Finance(unittest.TestCase):
    def test_add_entry_is_idempotent_by_client_ref(self):
        r, c = mk()
        run(r.add_entry("me", {"kind": "income", "amount": 5}, "tg:abc"))
        calls = c.log[0][1]
        self.assertTrue(has(calls, "upsert"))
        (_, args, kw) = next(x for x in calls if x[0] == "upsert")
        self.assertEqual(args[0]["client_ref"], "tg:abc")
        self.assertEqual(args[0]["user_id"], "me")
        self.assertEqual(kw["on_conflict"], "user_id,client_ref")
        self.assertTrue(kw["ignore_duplicates"])

    def test_entries_scoped_to_user(self):
        r, c = mk({"finance_entries": []})
        run(r.entries_between("me", "2026-01-01", "2026-02-01"))
        self.assertTrue(has(c.log[0][1], "eq", "user_id", "me"))


class Draft(unittest.TestCase):
    def test_existing_values_not_overwritten_and_admin_role_never_touched(self):
        r, c = mk()
        profile = {"id": "u", "full_name": "Eski Ism", "phone": None, "region": None, "district": None, "farm_name": None, "role": "admin", "onboarded": False}
        res = run(r.apply_draft("u", profile, {"telegram_id": 1, "full_name": "Yangi", "phone": "+998901234567", "region": "Samarqand", "role": "farmer", "language": "ru"}))
        upd = next(a[0] for n, calls in c.log for m, a, _ in calls if n == "profiles" and m == "update")
        self.assertNotIn("full_name", upd)            # mavjud ism saqlanadi
        self.assertEqual(upd["phone"], "+998901234567")
        self.assertEqual(res["role"], "kept")         # admin roli o'zgarmaydi
        self.assertFalse(any(n == "rpc:bot_set_role" for n, _ in c.log))

    def test_role_applied_only_via_rpc_when_not_onboarded(self):
        r, c = mk()
        run(r.apply_draft("u", {"id": "u", "role": "farmer", "onboarded": False}, {"telegram_id": 1, "role": "buyer"}))
        self.assertTrue(any(n == "rpc:bot_set_role" for n, _ in c.log))
        r, c = mk()
        run(r.apply_draft("u", {"id": "u", "role": "farmer", "onboarded": True}, {"telegram_id": 1, "role": "buyer"}))
        self.assertFalse(any(n == "rpc:bot_set_role" for n, _ in c.log))


if __name__ == "__main__":
    unittest.main()


class Services(unittest.TestCase):
    def test_unknown_table_rejected(self):
        r, c = mk()
        for coro in (r.svc_public("profiles"), r.svc_toggle("profiles", "u", "x"), r.svc_delete("products", "u", "x"), r.svc_get("tasks", "x")):
            with self.assertRaises(ValueError):
                run(coro)
        self.assertEqual(c.log, [])  # baza chaqirilmagan

    def test_public_filters(self):
        r, c = mk({"machinery_listings": []})
        run(r.svc_public("machinery_listings", q="trak,(tor)", q_cols=("title", "description"), region="Samarqand", region_col="region", eq={"kind": "tractor"}))
        calls = c.log[0][1]
        self.assertTrue(has(calls, "eq", "status", "active"))
        self.assertTrue(has(calls, "eq", "moderation_status", "approved"))
        self.assertTrue(has(calls, "eq", "kind", "tractor"))
        self.assertTrue(has(calls, "ilike", "region"))
        or_arg = next(a[0] for m, a, _ in calls if m == "or_")
        self.assertNotIn("(", or_arg)
        r, c = mk({"pharmacy_items": []})
        run(r.svc_public("pharmacy_items", moderated=False, in_col="pharmacy_id", in_vals=["p1"]))
        self.assertFalse(has(c.log[0][1], "eq", "moderation_status", "approved"))
        self.assertTrue(has(c.log[0][1], "in_", "pharmacy_id"))

    def test_items_without_visible_pharmacies_return_nothing_without_query(self):
        r, c = mk()
        self.assertEqual(run(r.svc_public("pharmacy_items", moderated=False, in_col="pharmacy_id", in_vals=[])), ([], False))
        self.assertEqual(c.log, [])

    def test_insert_sets_owner_and_rejects_unknown_columns(self):
        r, c = mk({"freight_listings": [{"id": "n1"}]})
        self.assertEqual(run(r.svc_insert("freight_listings", "me", {"title": "KamAZ", "capacity_tons": 10})), "n1")
        (_, args, _kw) = next(x for x in c.log[0][1] if x[0] == "insert")
        self.assertEqual(args[0]["owner_id"], "me")
        for bad in ({"moderation_status": "approved"}, {"owner_id": "other"}, {"status": "active"}):
            with self.assertRaises(ValueError):          # egasi o'zini tasdiqlay/boshqa egaga yoza olmaydi
                run(r.svc_insert("freight_listings", "me", bad))

    def test_toggle_and_delete_are_owner_scoped(self):
        r, c = mk({"pharmacies": []})
        self.assertIsNone(run(r.svc_toggle("pharmacies", "me", "p1")))
        self.assertEqual(len(c.log), 1)
        r, c = mk({"pharmacies": Seq([[{"status": "hidden"}], []])})
        self.assertEqual(run(r.svc_toggle("pharmacies", "me", "p1")), "active")
        self.assertTrue(has(c.log[1][1], "eq", "owner_id", "me"))
        r, c = mk({"pharmacies": []})
        self.assertFalse(run(r.svc_delete("pharmacies", "me", "p1")))
        self.assertTrue(has(c.log[0][1], "eq", "owner_id", "me"))

    def test_request_status_owner_scoped_and_whitelisted(self):
        r, c = mk({"service_requests": [{"id": "r1"}]})
        self.assertTrue(run(r.req_set_status("me", "r1", "accepted")))
        self.assertTrue(has(c.log[0][1], "eq", "owner_id", "me"))
        r, c = mk()
        self.assertFalse(run(r.req_set_status("me", "r1", "new")))
        self.assertEqual(c.log, [])
        r, c = mk({"service_requests": []})
        self.assertFalse(run(r.req_set_status("not-owner", "r1", "rejected")))   # egasi bo'lmasa hech narsa o'zgarmaydi

    def test_diary_is_user_scoped_and_idempotent(self):
        r, c = mk({"farm_fields": [], "field_entries": []})
        self.assertFalse(run(r.delete_field("me", "f1")))
        self.assertTrue(has(c.log[0][1], "eq", "user_id", "me"))
        run(r.field_entries("me", "f1"))
        self.assertTrue(has(c.log[1][1], "eq", "user_id", "me"))
        run(r.add_field_entry("me", {"kind": "harvest"}, "tg:abc"))
        (_, args, kw) = next(x for x in c.log[2][1] if x[0] == "upsert")
        self.assertEqual((args[0]["user_id"], args[0]["client_ref"], kw["on_conflict"]), ("me", "tg:abc", "user_id,client_ref"))
