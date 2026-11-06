"""Agroapteka, texnika ijarasi, logistika: BITTA umumiy mexanizm (bot/services/specs.py tavsiflari bo'yicha).
Ro'yxat/qidiruv/filtr, tafsilot, so'rov, shikoyat, egasi paneli (e'lon qo'shish, yashirish, o'chirish, kelgan so'rovlar)."""
from __future__ import annotations

from decimal import Decimal

from aiogram import F, Router
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery, Message

from ..services.specs import FR, MC, PH, REPORT_REASONS, SPECS, Spec, detail_text, summary_line
from ..states import Svc
from ..ui import b, cancel_row, esc, kb, main_menu, menu_texts, pager, regions_kb, require_user, send, show
from ..utils.regions import region_by_index, region_label
from ..utils.validators import clean_text, normalize_phone, parse_amount
from .common import fmt_dt

router = Router(name="services")
SIZE = 5
P = r"(ph|pi|mc|fr)"
UID = r"[0-9a-f-]{36}"


def rx(tail: str):
    return F.data.regexp(rf"^{P}:{tail}$")


def spec_of(data: str) -> Spec:
    return SPECS[data.split(":", 1)[0]]


def part(data: str, n: int) -> str:
    p = data.split(":")
    return p[n] if len(p) > n else ""


# ------------------------------------------------------------------ ro'yxat va filtrlar
async def render_list(event, state: FSMContext, repo, user, t, lang: str, spec: Spec, page: int = 0) -> None:
    f = (await state.get_data()).get(f"flt_{spec.key}", {})
    eq = {spec.filter_col: f["cat"]} if f.get("cat") and spec.filter_col else {}
    region, in_col, in_vals = f.get("reg"), None, None
    if spec.key == "pi":  # mahsulotlar faqat ko'rinadigan aptekalarniki
        in_col, in_vals, region = "pharmacy_id", await repo.visible_pharmacy_ids(f.get("reg"), f.get("store")), None
    rows, more = await repo.svc_public(spec.table, q=f.get("q", ""), q_cols=spec.q_cols, region=region, region_col=spec.region_col, eq=eq,
                                       moderated=spec.moderated, in_col=in_col, in_vals=in_vals, page=page, size=SIZE)
    chips = [x for x in (f.get("q") and f"🔎 {esc(f['q'])}", f.get("cat") and f"🗂 {t('ch_' + f['cat'])}", f.get("reg") and f"📍 {esc(region_label(f['reg'], lang))}") if x]
    head = f"<b>{t(spec.key + '_title')}</b>" + (("\n" + " · ".join(chips)) if chips else "")
    body = "\n".join(f"{i + 1}. <b>{esc(r[spec.title_col])}</b>\n   {summary_line(spec, r, t, lang)}" for i, r in enumerate(rows)) or t("no_listings")
    k = spec.key
    markup = [[b(f"{i + 1}. {str(r[spec.title_col])[:30]}", f"{k}:v:{r['id']}")] for i, r in enumerate(rows)]
    if pager(f"{k}:l", page, more):
        markup.append(pager(f"{k}:l", page, more))
    flt = [b(t("f_search"), f"{k}:fq")]
    if spec.region_col or k == "pi":
        flt.append(b(t("f_region"), f"{k}:fr"))
    if spec.filter_col:
        flt.append(b(t("f_category"), f"{k}:fc"))
    markup.append(flt + [b(t("f_clear"), f"{k}:fx")])
    if k == "ph":
        markup.append([b(t("pi_title"), "pi:l:0")])
    if k == "pi":
        markup.append([b(t("ph_title"), "ph:l:0")])
    own = [b(t("my_listings"), f"{k}:mine:0"), b(t("add_listing"), f"{k}:add")]
    if spec.request_kind:
        own.append(b(t("incoming_requests"), f"{k}:inbox"))
    markup.append(own)
    await show(event, head + "\n\n" + body, kb(markup))


@router.message(F.text.in_(menu_texts("m_agro")))
async def h_agro(message: Message, state: FSMContext, repo, user, t, lang):
    await state.clear()
    await render_list(message, state, repo, user, t, lang, PH, 0)


@router.message(F.text.in_(menu_texts("m_machinery")))
async def h_machinery(message: Message, state: FSMContext, repo, user, t, lang):
    await state.clear()
    await render_list(message, state, repo, user, t, lang, MC, 0)


@router.message(F.text.in_(menu_texts("m_logistics")))
async def h_logistics(message: Message, state: FSMContext, repo, user, t, lang):
    await state.clear()
    await render_list(message, state, repo, user, t, lang, FR, 0)


@router.callback_query(rx(r"l:\d+"))
async def cb_list(cb: CallbackQuery, state: FSMContext, repo, user, t, lang):
    await render_list(cb, state, repo, user, t, lang, spec_of(cb.data), int(part(cb.data, 2)))


async def _set_flt(state: FSMContext, spec: Spec, **kw) -> None:
    key = f"flt_{spec.key}"
    await state.update_data(**{key: {**(await state.get_data()).get(key, {}), **kw}})


@router.callback_query(rx("fq"))
async def cb_fq(cb: CallbackQuery, state: FSMContext, t):
    await state.set_state(Svc.query)
    await state.update_data(sk=spec_of(cb.data).key)
    await show(cb, t("ask_search"), kb([cancel_row(t)]))


@router.message(Svc.query)
async def msg_query(message: Message, state: FSMContext, repo, user, t, lang):
    spec = SPECS.get((await state.get_data()).get("sk", ""))
    if spec is None:
        return await state.clear()
    q = clean_text(message.text, 60)
    await state.set_state(None)
    await _set_flt(state, spec, q=q)
    await render_list(message, state, repo, user, t, lang, spec, 0)


@router.callback_query(rx("fr"))
async def cb_fr(cb: CallbackQuery, t, lang):
    k = spec_of(cb.data).key
    await show(cb, t("pick_region"), regions_kb(f"{k}:rg", lang, [b(t("back"), f"{k}:l:0")]))


@router.callback_query(rx(r"rg:\d+"))
async def cb_rg(cb: CallbackQuery, state, repo, user, t, lang):
    spec, region = spec_of(cb.data), region_by_index(int(part(cb.data, 2)))
    if region:
        await _set_flt(state, spec, reg=region)
    await render_list(cb, state, repo, user, t, lang, spec, 0)


@router.callback_query(rx("fc"))
async def cb_fc(cb: CallbackQuery, t):
    spec = spec_of(cb.data)
    f = next(x for x in spec.fields if x.key == spec.filter_col)
    rows = [[b(t(f"ch_{c}"), f"{spec.key}:cc:{c}") for c in f.choices[i:i + 2]] for i in range(0, len(f.choices), 2)]
    await show(cb, t("pick_category"), kb(rows + [[b(t("back"), f"{spec.key}:l:0")]]))


@router.callback_query(rx(r"cc:[a-z_]+"))
async def cb_cc(cb: CallbackQuery, state, repo, user, t, lang):
    spec, val = spec_of(cb.data), part(cb.data, 2)
    f = next((x for x in spec.fields if x.key == spec.filter_col), None)
    if f is None or val not in f.choices:  # callback_data ga ishonilmaydi: spetsifikatsiyadagi ro'yxat bilan solishtiriladi
        return await cb.answer()
    await _set_flt(state, spec, cat=val)
    await render_list(cb, state, repo, user, t, lang, spec, 0)


@router.callback_query(rx("fx"))
async def cb_fx(cb: CallbackQuery, state, repo, user, t, lang):
    spec = spec_of(cb.data)
    await state.update_data(**{f"flt_{spec.key}": {}})
    await render_list(cb, state, repo, user, t, lang, spec, 0)


@router.callback_query(F.data.regexp(rf"^pi:fs:{UID}$"))
async def cb_store_items(cb: CallbackQuery, state, repo, user, t, lang):
    spec = SPECS["pi"]
    await state.update_data(flt_pi={"store": part(cb.data, 2)})
    await render_list(cb, state, repo, user, t, lang, spec, 0)


# ------------------------------------------------------------------ tafsilot, so'rov, shikoyat
@router.callback_query(rx(rf"v:{UID}"))
async def cb_detail(cb: CallbackQuery, repo, t, lang):
    spec, rid = spec_of(cb.data), part(cb.data, 2)
    row = await repo.svc_get(spec.table, rid, spec.moderated)
    if not row:
        return await cb.answer(t("listing_gone"), show_alert=True)
    text = detail_text(spec, row, t, lang)
    if spec.key == "pi":
        store = await repo.svc_get("pharmacies", row["pharmacy_id"], True)
        if store:
            text += "\n" + t("pi_store", name=esc(store["name"]), where=esc(region_label(store["region"], lang)))
        if row["category"] == "pesticide":
            text += "\n\n⚠️ " + t("pesticide_note")
    rows = []
    if spec.request_kind:
        rows.append([b(t("send_request"), f"{spec.key}:rq:{rid}")])
    if spec.key == "ph":
        rows.append([b(t("pi_title"), f"pi:fs:{rid}")])
    rows.append([b(t("report"), f"{spec.key}:rp:{rid}")])
    rows.append([b(t("back"), f"{spec.key}:l:0")])
    await send(cb, text, kb(rows))


@router.callback_query(rx(rf"rq:{UID}"))
async def cb_request(cb: CallbackQuery, state: FSMContext, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    spec, rid = spec_of(cb.data), part(cb.data, 2)
    row = await repo.svc_get(spec.table, rid, spec.moderated)
    if not row:
        return await cb.answer(t("listing_gone"), show_alert=True)
    if row["owner_id"] == user["id"]:
        return await cb.answer(t("own_listing"), show_alert=True)
    await state.set_state(Svc.request)
    await state.update_data(sk=spec.key, tid=rid)
    await send(cb, t("ask_request"), kb([cancel_row(t)]))


@router.message(Svc.request)
async def msg_request(message: Message, state: FSMContext, repo, user, t):
    d = await state.get_data()
    spec = SPECS.get(d.get("sk", ""))
    text = clean_text(message.text, 500)
    if spec is None or not spec.request_kind:
        return await state.clear()
    if len(text) < 3:
        return await message.answer(t("err_text_short"))
    row = await repo.svc_get(spec.table, d.get("tid", ""), spec.moderated)  # yuborish paytida qayta tekshiriladi
    await state.clear()
    if not row or row["owner_id"] == user["id"]:
        return await message.answer(t("listing_gone"), reply_markup=main_menu(t))
    await repo.req_create(spec.request_kind, row["id"], user["id"], row["owner_id"], text)
    await message.answer(t("request_sent"), reply_markup=main_menu(t))


@router.callback_query(rx(rf"rp:{UID}"))
async def cb_report(cb: CallbackQuery, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    k, rid = spec_of(cb.data).key, part(cb.data, 2)
    await send(cb, t("rp_pick"), kb([[b(t(f"rp_{r}"), f"{k}:rr:{rid}:{r}")] for r in REPORT_REASONS] + [cancel_row(t)]))


@router.callback_query(rx(rf"rr:{UID}:[a-z]+"))
async def cb_report_reason(cb: CallbackQuery, repo, user, t, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    spec, rid, reason = spec_of(cb.data), part(cb.data, 2), part(cb.data, 3)
    if reason not in REPORT_REASONS:
        return await cb.answer()
    await repo.svc_report(user["id"], spec.report_kind, rid, reason)
    await send(cb, t("rp_sent"), main_menu(t))


# ------------------------------------------------------------------ egasi paneli
async def render_mine(event, repo, user, t, lang, spec: Spec, page: int = 0) -> None:
    rows, more = await repo.svc_mine(spec.table, user["id"], page, SIZE)
    body = "\n".join(f"{i + 1}. <b>{esc(r[spec.title_col])}</b> · {t('st_' + r['status'])}" for i, r in enumerate(rows)) or t("no_listings")
    k = spec.key
    markup = [[b(f"{'🙈' if r['status'] == 'active' else '👁'} {i + 1}", f"{k}:tg:{r['id']}"), b(f"🗑 {i + 1}", f"{k}:del:{r['id']}")] for i, r in enumerate(rows)]
    if pager(f"{k}:mine", page, more):
        markup.append(pager(f"{k}:mine", page, more))
    markup.append([b(t("add_listing"), f"{k}:add"), b(t("back"), f"{k}:l:0")])
    await show(event, t("my_listings") + "\n\n" + body, kb(markup))


@router.callback_query(rx(r"mine:\d+"))
async def cb_mine(cb: CallbackQuery, repo, user, t, lang, db_ok):
    if await require_user(cb, user, t, db_ok):
        await render_mine(cb, repo, user, t, lang, spec_of(cb.data), int(part(cb.data, 2)))


@router.callback_query(rx(rf"tg:{UID}"))
async def cb_toggle(cb: CallbackQuery, repo, user, t, lang, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    spec = spec_of(cb.data)
    new = await repo.svc_toggle(spec.table, user["id"], part(cb.data, 2))  # faqat o'z e'loni
    await cb.answer(t("toggled") if new else t("listing_gone"), show_alert=not new)
    await render_mine(cb, repo, user, t, lang, spec, 0)


@router.callback_query(rx(rf"del:{UID}"))
async def cb_del(cb: CallbackQuery, user, t, db_ok):
    if await require_user(cb, user, t, db_ok):
        k, rid = spec_of(cb.data).key, part(cb.data, 2)
        await show(cb, t("confirm_delete"), kb([[b(t("confirm"), f"{k}:del2:{rid}"), b(t("cancel"), f"{k}:mine:0")]]))


@router.callback_query(rx(rf"del2:{UID}"))
async def cb_del2(cb: CallbackQuery, repo, user, t, lang, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    spec = spec_of(cb.data)
    ok = await repo.svc_delete(spec.table, user["id"], part(cb.data, 2))
    await cb.answer(t("deleted") if ok else t("listing_gone"), show_alert=not ok)
    await render_mine(cb, repo, user, t, lang, spec, 0)


@router.callback_query(rx("inbox"))
async def cb_inbox(cb: CallbackQuery, repo, user, t, lang, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    spec = spec_of(cb.data)
    rows = await repo.req_inbox(user["id"], spec.request_kind or "", 8)
    if not rows:
        return await show(cb, t("no_requests"), kb([[b(t("back"), f"{spec.key}:l:0")]]))
    titles = await repo.svc_titles(spec.table, spec.title_col, [r["target_id"] for r in rows])
    names = await repo.names([r["requester_id"] for r in rows])
    text = t("incoming_requests") + "\n\n" + "\n\n".join(
        f"{i + 1}. <b>{esc(titles.get(r['target_id'], '—'))}</b>\n👤 {esc(names.get(r['requester_id']) or '—')} · {fmt_dt(r['created_at'])}\n{esc(r['message'])}" for i, r in enumerate(rows))
    markup = [[b(f"✅ {i + 1}", f"{spec.key}:rs:{r['id']}:a"), b(f"❌ {i + 1}", f"{spec.key}:rs:{r['id']}:r")] for i, r in enumerate(rows)]
    await show(cb, text, kb(markup + [[b(t("back"), f"{spec.key}:l:0")]]))


@router.callback_query(rx(rf"rs:{UID}:[ar]"))
async def cb_req_status(cb: CallbackQuery, repo, user, t, lang, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    ok = await repo.req_set_status(user["id"], part(cb.data, 2), "accepted" if part(cb.data, 3) == "a" else "rejected")  # faqat o'z so'rovi
    await cb.answer(t("saved_ok") if ok else t("err_generic"), show_alert=not ok)
    await _reinbox(cb, repo, user, t, lang, db_ok)  # aiogram obyektlari o'zgarmas: callback_data o'zgartirilmaydi, shuning uchun alohida funksiya


async def _reinbox(cb, repo, user, t, lang, db_ok) -> None:
    spec = spec_of(cb.data)
    rows = await repo.req_inbox(user["id"], spec.request_kind or "", 8)
    if not rows:
        return await show(cb, t("no_requests"), kb([[b(t("back"), f"{spec.key}:l:0")]]))
    await show(cb, t("requests_left", n=len(rows)), kb([[b(t("incoming_requests"), f"{spec.key}:inbox")], [b(t("back"), f"{spec.key}:l:0")]]))


# ------------------------------------------------------------------ e'lon qo'shish (FSM)
async def ask(event, state: FSMContext, t, lang: str, spec: Spec, idx: int) -> None:
    f = spec.fields[idx]
    await state.set_state(Svc.field)
    await state.update_data(sk=spec.key, idx=idx)
    k, rows = spec.key, []
    if f.kind == "choice":
        labels = [(c, c if f.key == "currency" else t(f"ch_{c}")) for c in f.choices]
        rows = [[b(lbl, f"{k}:ac:{c}") for c, lbl in labels[i:i + 2]] for i in range(0, len(labels), 2)]
    elif f.kind == "bool":
        rows = [[b(t("yes"), f"{k}:ab:1"), b(t("no"), f"{k}:ab:0")]]
    tail = ([] if f.required else [b(t("skip"), f"{k}:ask")]) + [b(t("cancel"), "x:cancel")]
    text = t("ask_field", label=t(f"fl_{f.key}"), hint={"num": t("hint_num"), "phone": t("hint_phone")}.get(f.kind, ""))
    await send(event, text, regions_kb(f"{k}:ar", lang, tail) if f.kind == "region" else kb(rows + [tail]))


async def _next(event, state: FSMContext, t, lang: str, spec: Spec, idx: int, value) -> None:
    vals = dict((await state.get_data()).get("vals", {}))
    if value is not None:
        vals[spec.fields[idx].key] = value
    await state.update_data(vals=vals)
    if idx + 1 < len(spec.fields):
        return await ask(event, state, t, lang, spec, idx + 1)
    await state.set_state(Svc.confirm)
    await send(event, t("preview_title") + "\n\n" + detail_text(spec, vals, t, lang), kb([[b(t("confirm"), f"{spec.key}:ok")], cancel_row(t)]))


@router.callback_query(rx("add"))
async def cb_add(cb: CallbackQuery, state: FSMContext, repo, user, t, lang, db_ok):
    if not await require_user(cb, user, t, db_ok):
        return
    spec = spec_of(cb.data)
    await state.set_state(Svc.field)
    await state.update_data(sk=spec.key, idx=-1, vals={})
    if spec.key == "pi":  # mahsulot avval o'zining aptekasiga bog'lanadi
        stores, _ = await repo.svc_mine("pharmacies", user["id"], 0, 10)
        if not stores:
            await state.clear()
            return await send(cb, t("need_store"), kb([[b(t("add_listing"), "ph:add")]]))
        return await send(cb, t("pick_store"), kb([[b(str(s["name"])[:40], f"pi:ap:{s['id']}")] for s in stores] + [cancel_row(t)]))
    await ask(cb, state, t, lang, spec, 0)


@router.callback_query(Svc.field, F.data.regexp(rf"^pi:ap:{UID}$"))
async def cb_pick_store(cb: CallbackQuery, state: FSMContext, repo, user, t, lang):
    d = await state.get_data()
    if d.get("sk") != "pi" or d.get("idx") != -1:
        return await cb.answer()
    if not await repo.svc_get_own("pharmacies", user["id"], part(cb.data, 2)):  # faqat o'z aptekasi
        return await cb.answer(t("listing_gone"), show_alert=True)
    await state.update_data(vals={"pharmacy_id": part(cb.data, 2)})
    await ask(cb, state, t, lang, SPECS["pi"], 0)


async def _current(state: FSMContext, cb: CallbackQuery):
    d = await state.get_data()
    spec = spec_of(cb.data)
    idx = d.get("idx", -1)
    if d.get("sk") != spec.key or not 0 <= idx < len(spec.fields):
        return None, None, -1
    return spec, spec.fields[idx], idx


@router.callback_query(Svc.field, rx(r"ac:[A-Za-z_]+"))
async def cb_choice(cb: CallbackQuery, state: FSMContext, t, lang):
    spec, f, idx = await _current(state, cb)
    if f is None or f.kind != "choice" or part(cb.data, 2) not in f.choices:
        return await cb.answer()
    await _next(cb, state, t, lang, spec, idx, part(cb.data, 2))


@router.callback_query(Svc.field, rx(r"ar:\d+"))
async def cb_region(cb: CallbackQuery, state: FSMContext, t, lang):
    spec, f, idx = await _current(state, cb)
    region = region_by_index(int(part(cb.data, 2)))
    if f is None or f.kind != "region" or not region:
        return await cb.answer()
    await _next(cb, state, t, lang, spec, idx, region)


@router.callback_query(Svc.field, rx(r"ab:[01]"))
async def cb_bool(cb: CallbackQuery, state: FSMContext, t, lang):
    spec, f, idx = await _current(state, cb)
    if f is None or f.kind != "bool":
        return await cb.answer()
    await _next(cb, state, t, lang, spec, idx, part(cb.data, 2) == "1")


@router.callback_query(Svc.field, rx("ask"))
async def cb_skip(cb: CallbackQuery, state: FSMContext, t, lang):
    spec, f, idx = await _current(state, cb)
    if f is None or f.required:  # majburiy maydonni o'tkazib bo'lmaydi
        return await cb.answer(t("required_field"), show_alert=True)
    await _next(cb, state, t, lang, spec, idx, None)


@router.message(Svc.field)
async def msg_field(message: Message, state: FSMContext, t, lang):
    d = await state.get_data()
    spec, idx = SPECS.get(d.get("sk", "")), d.get("idx", -1)
    if spec is None or not 0 <= idx < len(spec.fields):
        return
    f = spec.fields[idx]
    if f.kind == "text":
        v = clean_text(message.text, f.max_len)
        if len(v) < (2 if f.required else 1):
            return await message.answer(t("err_text_short"))
    elif f.kind == "num":
        a = parse_amount(message.text, Decimal("999999") if f.key == "capacity_tons" else Decimal("1000000000000"))
        if a is None:
            return await message.answer(t("err_amount"))
        v = float(a)
    elif f.kind == "phone":
        v = normalize_phone(message.text)
        if not v:
            return await message.answer(t("err_phone"))
    else:
        return await message.answer(t("use_buttons"))
    await _next(message, state, t, lang, spec, idx, v)


@router.callback_query(Svc.confirm, rx("ok"))
async def cb_ok(cb: CallbackQuery, state: FSMContext, repo, user, t):
    d = await state.get_data()
    spec = spec_of(cb.data)
    if d.get("sk") != spec.key or not user:
        return await cb.answer()
    vals = d.get("vals", {})
    await state.clear()  # takroriy bosish ikkinchi e'lon yaratmaydi
    if spec.key == "pi" and not await repo.svc_get_own("pharmacies", user["id"], vals.get("pharmacy_id", "")):
        return await send(cb, t("listing_gone"), main_menu(t))
    await repo.svc_insert(spec.table, user["id"], vals)
    await send(cb, t("listing_saved"), main_menu(t))
