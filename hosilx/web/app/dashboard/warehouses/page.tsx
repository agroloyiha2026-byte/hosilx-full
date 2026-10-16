"use client";
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useUser } from "@/lib/useUser";
import { useApp } from "@/components/Providers";

type W = { id: string; name: string; capacity_tons: number; free_tons: number };
type R = { id: string; product_type: string; quantity_tons: number; message: string | null; status: string; warehouses: { name: string } };
const blank = { name: "", region: "", storage_type: "dry", capacity_tons: "", free_tons: "", price: "",
  currency: "UZS", accepted: "", phone: "", conditions: "" };

export default function OwnWarehouses() {
  const { t } = useApp();
  const { profile } = useUser();
  const [ws, setWs] = useState<W[]>([]);
  const [rs, setRs] = useState<R[]>([]);
  const [f, setF] = useState(blank);
  const [err, setErr] = useState("");

  const load = useCallback(async () => {
    if (!profile) return;
    const [a, b] = await Promise.all([
      supabase.from("warehouses").select("id,name,capacity_tons,free_tons").eq("owner_id", profile.id),
      supabase.from("storage_requests").select("id,product_type,quantity_tons,message,status,warehouses(name)")
        .order("created_at", { ascending: false }).limit(50),
    ]);
    setWs((a.data ?? []) as W[]); setRs((b.data ?? []) as unknown as R[]);
  }, [profile]);
  useEffect(() => { load(); }, [load]);

  const set = (k: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => setF({ ...f, [k]: e.target.value });

  async function add(e: React.FormEvent) {
    e.preventDefault(); setErr("");
    if (Number(f.free_tons) > Number(f.capacity_tons)) return setErr(t("err_generic"));
    const { error } = await supabase.from("warehouses").insert({
      owner_id: profile!.id, name: f.name.trim(), region: f.region.trim(), storage_type: f.storage_type,
      capacity_tons: Number(f.capacity_tons), free_tons: Number(f.free_tons),
      price_per_ton_month: f.price ? Number(f.price) : null, currency: f.currency,
      accepted_products: f.accepted.split(",").map((s) => s.trim().toLowerCase()).filter(Boolean),
      contact_phone: f.phone || null, conditions: f.conditions || null,
    });
    if (error) return setErr(t("err_generic"));
    setF(blank); load();
  }
  async function updateFree(w: W) {
    const v = window.prompt(t("wh_free"), String(w.free_tons));
    if (v === null || isNaN(Number(v)) || Number(v) < 0 || Number(v) > Number(w.capacity_tons)) return;
    await supabase.from("warehouses").update({ free_tons: Number(v) }).eq("id", w.id); load();
  }
  async function setStatus(id: string, status: string) { await supabase.from("storage_requests").update({ status }).eq("id", id); load(); }

  return (
    <main>
      <h1>{t("d_wh")}</h1>
      <form className="card feature" style={{ display: "grid", gap: 10, marginBottom: 24 }} onSubmit={add}>
        <input required placeholder={t("wh_name")} value={f.name} onChange={set("name")} />
        <input required placeholder={t("f_region")} value={f.region} onChange={set("region")} />
        <select value={f.storage_type} onChange={set("storage_type")}>
          {["cold", "dry", "vegetable", "grain", "other"].map((s) => <option key={s} value={s}>{t("st_" + s)}</option>)}</select>
        <input required type="number" min="1" step="any" placeholder={t("wh_cap")} value={f.capacity_tons} onChange={set("capacity_tons")} />
        <input required type="number" min="0" step="any" placeholder={t("wh_free")} value={f.free_tons} onChange={set("free_tons")} />
        <div style={{ display: "flex", gap: 8 }}>
          <input type="number" min="0" step="any" placeholder={t("wh_price")} value={f.price} onChange={set("price")} style={{ flex: 1 }} />
          <select value={f.currency} onChange={set("currency")}><option>UZS</option><option>USD</option></select>
        </div>
        <input placeholder={t("wh_acc")} value={f.accepted} onChange={set("accepted")} />
        <input placeholder={t("wh_phone")} value={f.phone} onChange={set("phone")} />
        <input placeholder={t("wh_cond")} value={f.conditions} onChange={set("conditions")} />
        <button className="btn">{t("wh_add")}</button>
        {err && <span style={{ color: "#B3261E" }}>{err}</span>}
      </form>
      <div className="grid" style={{ marginBottom: 24 }}>
        {ws.map((w) => (
          <div key={w.id} className="card feature"><h3>{w.name}</h3>
            <span className="soft">{t("free_space")}: {Number(w.free_tons)} / {Number(w.capacity_tons)} {t("ton")}</span>
            <button className="btn ghost small" onClick={() => updateFree(w)}>{t("update")}</button></div>))}
      </div>
      <h2>{t("storage_reqs")}</h2>
      {rs.length === 0 ? <div className="empty">{t("no_sreq")}</div> : rs.map((r) => (
        <div key={r.id} className="card feature" style={{ marginBottom: 10 }}>
          <b>{r.warehouses?.name} · {r.product_type} · {Number(r.quantity_tons)} {t("ton")}</b>
          <span className="soft">{t("st_" + r.status)}{r.message ? ` · ${r.message}` : ""}</span>
          {r.status === "new" && ws.length > 0 && (
            <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
              <button className="btn small" onClick={() => setStatus(r.id, "accepted")}>{t("accept")}</button>
              <button className="btn ghost small" onClick={() => setStatus(r.id, "rejected")}>{t("reject")}</button>
            </div>)}
        </div>))}
    </main>
  );
}
