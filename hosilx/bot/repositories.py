"""Hamma Supabase so'rovlari shu yerda. DIQQAT: service_role RLS'ni chetlab o'tadi, shuning uchun
har bir foydalanuvchiga tegishli so'rov egalikni (user_id / owner_id / seller_id) O'ZI tekshiradi."""
from __future__ import annotations

from datetime import datetime
from typing import Any

from .db import Db
from .utils.links import is_expired
from .utils.pagination import db_window, split_extra
from .utils.validators import SELF_REGISTER_ROLES, sanitize_search

PRODUCT_COLS = "id,title,category,product_type,price,currency,unit,quantity,region,image_url,seller_id,created_at"
WH_COLS = "id,name,region,address,storage_type,capacity_tons,free_tons,price_per_ton_month,currency,accepted_products,conditions,contact_phone,owner_id"


class Repo:
    def __init__(self, db: Db):
        self.db = db

    async def _q(self, fn) -> list[dict]:
        r = await self.db.run(fn)
        return r.data or []

    # ---------- profil, ro'yxatdan o'tish, ulash ----------
    async def profile_by_tg(self, tid: int) -> dict | None:
        d = await self._q(lambda c: c.table("profiles").select("*").eq("telegram_id", tid).limit(1).execute())
        return d[0] if d else None

    async def profile(self, uid: str) -> dict | None:
        d = await self._q(lambda c: c.table("profiles").select("*").eq("id", uid).limit(1).execute())
        return d[0] if d else None

    async def reg_get(self, tid: int) -> dict | None:
        d = await self._q(lambda c: c.table("telegram_registrations").select("*").eq("telegram_id", tid).limit(1).execute())
        return d[0] if d else None

    async def reg_save(self, tid: int, data: dict) -> None:
        await self._q(lambda c: c.table("telegram_registrations").upsert({**data, "telegram_id": tid}, on_conflict="telegram_id").execute())

    async def consume_link_code(self, code: str, tid: int, now: datetime) -> tuple[str, str | None]:
        """Bir martalik kod: avval O'CHIRILADI (atomik), keyin tekshiriladi. -> (holat, user_id)"""
        rows = await self._q(lambda c: c.table("link_codes").delete().eq("code", code).execute())
        if not rows:
            return "invalid", None
        if is_expired(rows[0]["expires_at"], now):
            return "expired", None
        uid = rows[0]["user_id"]
        try:
            upd = await self._q(lambda c: c.table("profiles").update({"telegram_id": tid, "telegram_linked_at": now.isoformat()})
                                .eq("id", uid).is_("telegram_id", "null").execute())
        except Exception as e:  # unique(telegram_id) buzilsa: bu Telegram boshqa profilga ulangan
            if "23505" in str(e) or "duplicate" in str(e).lower():
                return "taken", None
            raise
        return ("ok", uid) if upd else ("taken", None)

    async def apply_draft(self, uid: str, profile: dict, draft: dict | None) -> dict:
        """Telegramdagi qoralamani profilga qo'shadi: mavjud qiymatlar USTIDAN YOZILMAYDI. Rolni faqat bot_set_role() (whitelist) o'zgartiradi."""
        res: dict[str, Any] = {"applied": [], "role": "kept"}
        if not draft:
            return res
        patch = {dst: draft[src] for src, dst in (("full_name", "full_name"), ("phone", "phone"), ("region", "region"),
                                                  ("district", "district"), ("business_name", "farm_name")) if draft.get(src) and not profile.get(dst)}
        if draft.get("language") in ("uz", "ru", "en"):
            patch["language"] = draft["language"]
        if patch:
            await self._q(lambda c: c.table("profiles").update(patch).eq("id", uid).execute())
            res["applied"] = sorted(patch)
        role = draft.get("role")
        if role in SELF_REGISTER_ROLES and role != profile.get("role") and not profile.get("onboarded") and profile.get("role") != "admin":
            try:
                await self._q(lambda c: c.rpc("bot_set_role", {"p_user": uid, "p_role": role}).execute())
                res["role"] = "applied"
            except Exception:
                res["role"] = "failed"
        if draft.get("telegram_id"):
            await self._q(lambda c: c.table("telegram_registrations").update({"status": "linked", "user_id": uid}).eq("telegram_id", draft["telegram_id"]).execute())
        return res

    async def set_language(self, uid: str, lang: str) -> None:
        await self._q(lambda c: c.table("profiles").update({"language": lang}).eq("id", uid).execute())

    async def set_notify(self, uid: str, on: bool) -> None:
        await self._q(lambda c: c.table("profiles").update({"telegram_notify": on}).eq("id", uid).execute())

    async def unlink(self, uid: str) -> None:
        await self._q(lambda c: c.table("profiles").update({"telegram_id": None, "telegram_linked_at": None}).eq("id", uid).execute())

    # ---------- bozor ----------
    async def categories(self) -> list[dict]:
        return await self._q(lambda c: c.table("product_categories").select("slug,name_uz,name_ru,name_en").eq("active", True).order("sort_order").execute())

    async def products(self, q: str = "", category: str | None = None, region: str | None = None, page: int = 0, size: int = 5) -> tuple[list[dict], bool]:
        start, end = db_window(page, size)

        def run(c, moderated=True):
            qq = c.table("products").select(PRODUCT_COLS).eq("status", "active")
            if moderated:
                qq = qq.eq("moderation_status", "approved")
            if category:
                qq = qq.eq("category", category)
            t = sanitize_search(q)
            if t:
                qq = qq.or_(f"title.ilike.%{t}%,product_type.ilike.%{t}%")
            r = sanitize_search(region)
            if r:
                qq = qq.ilike("region", f"%{r}%")
            return qq.order("created_at", desc=True).range(start, end).execute()

        try:
            rows = await self._q(run)
        except Exception as e:  # migration6 qo'llanmagan baza: moderatsiya ustuni yo'q
            if "moderation_status" not in str(e):
                raise
            rows = await self._q(lambda c: run(c, moderated=False))
        return split_extra(rows, size)

    async def product(self, pid: str) -> dict | None:
        d = await self._q(lambda c: c.table("products").select(PRODUCT_COLS + ",description,product_images(url,sort_order)")
                          .eq("id", pid).eq("status", "active").limit(1).execute())
        return d[0] if d else None

    async def seller(self, sid: str) -> dict | None:
        d = await self._q(lambda c: c.rpc("seller_public", {"p_seller": sid}).execute())
        return d[0] if d else None

    async def create_inquiry(self, pid: str, buyer: str, message: str | None, offer: float | None) -> None:
        await self._q(lambda c: c.table("inquiries").insert({"product_id": pid, "buyer_id": buyer, "message": message, "offered_price": offer}).execute())

    async def my_products(self, uid: str, page: int = 0, size: int = 5) -> tuple[list[dict], bool]:
        start, end = db_window(page, size)
        rows = await self._q(lambda c: c.table("products").select(PRODUCT_COLS + ",status").eq("seller_id", uid).order("created_at", desc=True).range(start, end).execute())
        return split_extra(rows, size)

    async def toggle_product(self, uid: str, pid: str) -> str | None:
        d = await self._q(lambda c: c.table("products").select("status").eq("id", pid).eq("seller_id", uid).limit(1).execute())
        if not d:
            return None  # boshqaning mahsuloti: o'zgartirilmaydi
        new = "hidden" if d[0]["status"] == "active" else "active"
        await self._q(lambda c: c.table("products").update({"status": new}).eq("id", pid).eq("seller_id", uid).execute())
        return new

    async def add_product(self, uid: str, data: dict) -> str:
        d = await self._q(lambda c: c.table("products").insert({**data, "seller_id": uid}).execute())
        return d[0]["id"]

    async def upload_photo(self, uid: str, data: bytes, name: str) -> str:
        path = f"{uid}/{name}.jpg"
        await self.db.run(lambda c: c.storage.from_("images").upload(path, data, {"content-type": "image/jpeg"}))
        return await self.db.run(lambda c: c.storage.from_("images").get_public_url(path))

    # ---------- omborlar ----------
    async def warehouses(self, q: str = "", region: str | None = None, page: int = 0, size: int = 5) -> tuple[list[dict], bool]:
        start, end = db_window(page, size)

        def run(c):
            qq = c.table("warehouses").select(WH_COLS).eq("status", "active")
            t = sanitize_search(q)
            if t:
                qq = qq.or_(f"name.ilike.%{t}%,region.ilike.%{t}%")
            r = sanitize_search(region)
            if r:
                qq = qq.ilike("region", f"%{r}%")
            return qq.order("created_at", desc=True).range(start, end).execute()

        return split_extra(await self._q(run), size)

    async def warehouse(self, wid: str) -> dict | None:
        d = await self._q(lambda c: c.table("warehouses").select(WH_COLS).eq("id", wid).eq("status", "active").limit(1).execute())
        return d[0] if d else None

    async def request_storage(self, wid: str, farmer: str, ptype: str, tons: float, message: str | None) -> None:
        await self._q(lambda c: c.table("storage_requests").insert({"warehouse_id": wid, "farmer_id": farmer, "product_type": ptype.lower(),
                                                                    "quantity_tons": tons, "message": message}).execute())

    async def my_warehouses(self, uid: str) -> list[dict]:
        return await self._q(lambda c: c.table("warehouses").select(WH_COLS).eq("owner_id", uid).order("created_at", desc=True).limit(20).execute())

    async def wh_requests(self, uid: str, limit: int = 10) -> list[dict]:
        ids = [w["id"] for w in await self.my_warehouses(uid)]
        if not ids:
            return []
        return await self._q(lambda c: c.table("storage_requests").select("id,warehouse_id,product_type,quantity_tons,message,status,created_at")
                             .in_("warehouse_id", ids).eq("status", "new").order("created_at", desc=True).limit(limit).execute())

    async def set_request_status(self, uid: str, rid: str, status: str) -> bool:
        if status not in ("accepted", "rejected"):
            return False
        r = await self._q(lambda c: c.table("storage_requests").select("warehouse_id").eq("id", rid).limit(1).execute())
        if not r:
            return False
        own = await self._q(lambda c: c.table("warehouses").select("id").eq("id", r[0]["warehouse_id"]).eq("owner_id", uid).limit(1).execute())
        if not own:
            return False  # ombor egasi emas
        await self._q(lambda c: c.table("storage_requests").update({"status": status}).eq("id", rid).execute())
        return True

    async def set_free_tons(self, uid: str, wid: str, tons: float) -> bool:
        d = await self._q(lambda c: c.table("warehouses").select("capacity_tons").eq("id", wid).eq("owner_id", uid).limit(1).execute())
        if not d or tons < 0 or tons > float(d[0]["capacity_tons"]):
            return False
        await self._q(lambda c: c.table("warehouses").update({"free_tons": tons}).eq("id", wid).eq("owner_id", uid).execute())
        return True

    # ---------- maqsadlar va vazifalar ----------
    async def tasks(self, uid: str, done: bool = False, limit: int = 15) -> list[dict]:
        return await self._q(lambda c: c.table("tasks").select("id,title,description,due_at,done").eq("user_id", uid).eq("done", done)
                             .order("due_at").limit(limit).execute())

    async def add_task(self, uid: str, title: str, due_utc_iso: str) -> None:
        await self._q(lambda c: c.table("tasks").insert({"user_id": uid, "title": title, "due_at": due_utc_iso}).execute())

    async def set_task_done(self, uid: str, tid: str) -> None:
        await self._q(lambda c: c.table("tasks").update({"done": True}).eq("id", tid).eq("user_id", uid).execute())

    async def delete_task(self, uid: str, tid: str) -> None:
        await self._q(lambda c: c.table("tasks").delete().eq("id", tid).eq("user_id", uid).execute())

    async def due_tasks(self, now_iso: str, limit: int = 50) -> list[dict]:
        return await self._q(lambda c: c.table("tasks").select("id,user_id,title,due_at").eq("done", False).eq("reminded", False)
                             .lte("due_at", now_iso).limit(limit).execute())

    async def mark_reminded(self, tid: str) -> None:
        await self._q(lambda c: c.table("tasks").update({"reminded": True}).eq("id", tid).execute())

    # ---------- moliya ----------
    async def add_entry(self, uid: str, data: dict, client_ref: str) -> None:
        """client_ref bilan idempotent: takroriy bosish/qayta yuborish ikkinchi yozuv yaratmaydi (migration12 unique indeks)."""
        await self._q(lambda c: c.table("finance_entries").upsert({**data, "user_id": uid, "client_ref": client_ref},
                                                                  on_conflict="user_id,client_ref", ignore_duplicates=True).execute())

    async def entries_between(self, uid: str, start: str, end: str) -> list[dict]:
        return await self._q(lambda c: c.table("finance_entries").select("kind,category,amount,currency,planned,entry_date")
                             .eq("user_id", uid).gte("entry_date", start).lt("entry_date", end).limit(2000).execute())

    # ---------- shikoyat, AI, bildirishnoma ----------
    async def create_report(self, uid: str, product_id: str | None, warehouse_id: str | None, reason: str) -> None:
        await self._q(lambda c: c.table("reports").insert({"reporter_id": uid, "product_id": product_id, "warehouse_id": warehouse_id, "reason": reason[:500]}).execute())

    async def ai_count_today(self, uid: str, since_iso: str) -> int:
        return len(await self._q(lambda c: c.table("ai_messages").select("id").eq("user_id", uid).eq("role", "user").gte("created_at", since_iso).limit(500).execute()))

    async def ai_log(self, uid: str, role: str, content: str) -> None:
        await self._q(lambda c: c.table("ai_messages").insert({"user_id": uid, "role": role, "content": content[:4000]}).execute())

    async def price_stats(self, ptype: str, region: str | None) -> list[dict]:
        """Faol e'lonlar narxlaridan hisoblanadi (bazada tayyor RPC yo'q; sayt ham shunday qiladi)."""
        from .utils.prices import price_stats as calc

        t = sanitize_search(ptype)
        r = sanitize_search(region)

        def run(c):
            q = c.table("products").select("price,currency,unit,created_at").eq("status", "active").or_(f"product_type.ilike.%{t}%,title.ilike.%{t}%")
            if r:
                q = q.ilike("region", f"%{r}%")
            return q.order("created_at", desc=True).limit(500).execute()

        return calc(await self._q(run))

    async def user_notifications(self, uid: str, limit: int = 10) -> list[dict]:
        return await self._q(lambda c: c.table("notifications").select("id,title,body,read,created_at").eq("user_id", uid).order("created_at", desc=True).limit(limit).execute())

    async def mark_read(self, uid: str) -> None:
        await self._q(lambda c: c.table("notifications").update({"read": True}).eq("user_id", uid).eq("read", False).execute())

    async def unsent_notifications(self, limit: int = 50) -> list[dict]:
        return await self._q(lambda c: c.table("notifications").select("id,user_id,title,body,created_at").is_("tg_sent_at", "null").order("created_at").limit(limit).execute())

    async def mark_sent(self, ids: list[str], now_iso: str) -> None:
        if ids:
            await self._q(lambda c: c.table("notifications").update({"tg_sent_at": now_iso}).in_("id", ids).execute())

    async def profiles_by_ids(self, ids: list[str]) -> dict[str, dict]:
        if not ids:
            return {}
        rows = await self._q(lambda c: c.table("profiles").select("id,telegram_id,telegram_notify,telegram_linked_at,language").in_("id", ids).execute())
        return {r["id"]: r for r in rows}
