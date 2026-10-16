"use client";
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useUser } from "@/lib/useUser";
import { useApp } from "@/components/Providers";

type Rep = { id: string; reason: string; resolved: boolean; product_id: string | null; products: { title: string } | null };
type Usr = { id: string; full_name: string; role: string };
type Prd = { id: string; title: string; status: string };

export default function Admin() {
  const { t } = useApp();
  const { profile } = useUser();
  const [reps, setReps] = useState<Rep[]>([]);
  const [users, setUsers] = useState<Usr[]>([]);
  const [prods, setProds] = useState<Prd[]>([]);
  const ok = profile?.role === "admin";

  const load = useCallback(async () => {
    const [a, b, c] = await Promise.all([
      supabase.from("reports").select("id,reason,resolved,product_id,products(title)").order("created_at", { ascending: false }).limit(100),
      supabase.from("profiles").select("id,full_name,role").order("created_at", { ascending: false }).limit(100),
      supabase.from("products").select("id,title,status").order("created_at", { ascending: false }).limit(100),
    ]);
    setReps((a.data ?? []) as unknown as Rep[]); setUsers((b.data ?? []) as Usr[]); setProds((c.data ?? []) as Prd[]);
  }, []);
  useEffect(() => { if (ok) load(); }, [ok, load]);

  if (!profile) return <p className="container soft">{t("loading")}</p>;
  if (!ok) return <div className="container empty">403</div>;
  const resolve = async (id: string) => { await supabase.from("reports").update({ resolved: true }).eq("id", id); load(); };
  const hide = async (id: string) => { await supabase.from("products").update({ status: "hidden" }).eq("id", id); load(); };
  const setRole = async (id: string, role: string) => { await supabase.from("profiles").update({ role }).eq("id", id); load(); };

  return (
    <main className="container" style={{ padding: "24px 20px 64px" }}>
      <h1>{t("admin")}</h1>
      <h2>{t("adm_reports")}</h2>
      {reps.length === 0 ? <div className="empty">{t("no_items")}</div> : reps.map((r) => (
        <div key={r.id} className="card feature" style={{ marginBottom: 8, opacity: r.resolved ? 0.5 : 1 }}>
          <b>{r.products?.title ?? "—"}</b><span className="soft">{r.reason}</span>
          {!r.resolved && <div style={{ display: "flex", gap: 8, marginTop: 6 }}>
            {r.product_id && <button className="btn ghost small" onClick={() => hide(r.product_id!)}>{t("hide_it")}</button>}
            <button className="btn small" onClick={() => resolve(r.id)}>{t("resolve")}</button></div>}
        </div>))}
      <h2>{t("adm_products")}</h2>
      {prods.map((p) => (<div key={p.id} className="card feature" style={{ marginBottom: 6, flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
        <span>{p.title} <span className="soft">· {p.status}</span></span>
        {p.status === "active" && <button className="btn ghost small" onClick={() => hide(p.id)}>{t("hide_it")}</button>}</div>))}
      <h2>{t("adm_users")}</h2>
      {users.map((u) => (<div key={u.id} className="card feature" style={{ marginBottom: 6, flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
        <span>{u.full_name || u.id.slice(0, 8)}</span>
        <select value={u.role} onChange={(e) => setRole(u.id, e.target.value)}>
          {["farmer", "buyer", "warehouse_owner", "admin"].map((r) => <option key={r}>{r}</option>)}</select></div>))}
    </main>
  );
}
