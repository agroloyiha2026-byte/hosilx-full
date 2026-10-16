"use client";
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useApp } from "@/components/Providers";

type Warehouse = {
  id: string; name: string; region: string; storage_type: string; capacity_tons: number;
  free_tons: number; price_per_ton_month: number | null; currency: string; image_url: string | null;
};

export default function Warehouses() {
  const { t } = useApp();
  const [items, setItems] = useState<Warehouse[]>([]);
  const [state, setState] = useState<"loading" | "error" | "ok">("loading");

  const load = useCallback(async () => {
    setState("loading");
    const { data, error } = await supabase.from("warehouses")
      .select("id,name,region,storage_type,capacity_tons,free_tons,price_per_ton_month,currency,image_url")
      .eq("status", "active").order("created_at", { ascending: false }).limit(60);
    if (error) return setState("error");
    setItems(data as Warehouse[]);
    setState("ok");
  }, []);
  useEffect(() => { load(); }, [load]);
  async function requestStorage(id: string) {
    const { data: u } = await supabase.auth.getUser();
    if (!u.user) { window.location.href = "/login"; return; }
    const pt = window.prompt(t("req_prompt_t")); if (!pt) return;
    const q = Number(window.prompt(t("req_prompt_q"))); if (!(q > 0)) return;
    const { error } = await supabase.from("storage_requests").insert({
      warehouse_id: id, farmer_id: u.user.id, product_type: pt.trim().toLowerCase(), quantity_tons: q });
    window.alert(error ? t("err_generic") : t("sent"));
  }

  return (
    <main className="container" style={{ padding: "24px 20px 64px" }}>
      <h1>{t("wh_title")}</h1>
      {state === "loading" && <p className="soft">{t("loading")}</p>}
      {state === "error" && <div className="empty"><p>{t("error")}</p>
        <button className="btn" onClick={load}>{t("retry")}</button></div>}
      {state === "ok" && items.length === 0 && <div className="empty">{t("empty_wh")}</div>}
      {state === "ok" && items.length > 0 && (
        <div className="grid">
          {items.map((w) => {
            const pct = Math.max(0, Math.min(100, (Number(w.free_tons) / Number(w.capacity_tons)) * 100));
            return (
              <article key={w.id} className="card">
                <div className="img" style={w.image_url ? { backgroundImage: `url(${w.image_url})` } : undefined}>
                  {!w.image_url && "🏭"}
                </div>
                <div className="body">
                  <h3>{w.name}</h3>
                  <span className="soft">📍 {w.region} · {t("st_" + w.storage_type)}</span>
                  <span className="soft">{t("capacity")}: {Number(w.capacity_tons)} {t("ton")}</span>
                  <div style={{ background: "var(--muted-bg)", borderRadius: 8, height: 8 }}>
                    <div style={{ width: `${pct}%`, height: 8, borderRadius: 8, background: "var(--accent)" }} />
                  </div>
                  <span className="soft">{t("free_space")}: {Number(w.free_tons)} {t("ton")}</span>
                  <span className="price">
                    {w.price_per_ton_month ? `${Number(w.price_per_ton_month).toLocaleString()} ${w.currency} ${t("per_month")}` : t("price_na")}
                  </span>
                  <button className="btn small" style={{ marginTop: 8 }} onClick={() => requestStorage(w.id)}>{t("request_storage")}</button>
                </div>
              </article>
            );
          })}
        </div>
      )}
    </main>
  );
}
