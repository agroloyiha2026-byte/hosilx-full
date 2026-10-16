"use client";
import { Suspense, useCallback, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { useApp } from "@/components/Providers";

type Product = {
  id: string; title: string; category: string; price: number; currency: string;
  unit: string; quantity: number; region: string; image_url: string | null;
};
const CATS = ["fruit", "vegetable", "grain", "dairy", "other"];

function Market() {
  const { t } = useApp();
  const params = useSearchParams();
  const [q, setQ] = useState(params.get("q") ?? "");
  const [cat, setCat] = useState("");
  const [items, setItems] = useState<Product[]>([]);
  const [state, setState] = useState<"loading" | "error" | "ok">("loading");

  const load = useCallback(async () => {
    setState("loading");
    let query = supabase.from("products")
      .select("id,title,category,price,currency,unit,quantity,region,image_url")
      .eq("status", "active").order("created_at", { ascending: false }).limit(60);
    if (cat) query = query.eq("category", cat);
    const term = q.trim().replace(/[%,()]/g, "");
    if (term) query = query.or(`title.ilike.%${term}%,product_type.ilike.%${term}%`);
    const { data, error } = await query;
    if (error) return setState("error");
    setItems(data as Product[]);
    setState("ok");
  }, [q, cat]);

  useEffect(() => { load(); }, [cat]); // qidiruv tugmasi bilan yangilanadi

  return (
    <main className="container" style={{ padding: "24px 20px 64px" }}>
      <form className="toolbar" onSubmit={(e) => { e.preventDefault(); load(); }}>
        <input style={{ flex: 1, minWidth: 200 }} value={q} onChange={(e) => setQ(e.target.value)}
          placeholder={t("search_ph")} />
        <select value={cat} onChange={(e) => setCat(e.target.value)}>
          <option value="">{t("all")}</option>
          {CATS.map((c) => <option key={c} value={c}>{t("cat_" + c)}</option>)}
        </select>
        <button className="btn">{t("search")}</button>
      </form>

      {state === "loading" && <p className="soft">{t("loading")}</p>}
      {state === "error" && (
        <div className="empty"><p>{t("error")}</p>
          <button className="btn" onClick={load}>{t("retry")}</button></div>
      )}
      {state === "ok" && items.length === 0 && (
        <div className="empty"><p>{t("empty_market")}</p>
          <a className="btn" href="/login">{t("add_product")}</a></div>
      )}
      {state === "ok" && items.length > 0 && (
        <div className="grid">
          {items.map((p) => (
            <article key={p.id} className="card">
              <div className="img" style={p.image_url ? { backgroundImage: `url(${p.image_url})` } : undefined}>
                {!p.image_url && "🌿"}
              </div>
              <div className="body">
                <h3>{p.title}</h3>
                <span className="price">{Number(p.price).toLocaleString()} {p.currency}/{p.unit}</span>
                <span className="soft">{t("available")}: {Number(p.quantity)} {p.unit}</span>
                <span className="soft">📍 {p.region}</span>
                <a className="btn ghost small" style={{ marginTop: 8, textAlign: "center" }}
                  href={`/market/${p.id}`}>{t("details")}</a>
              </div>
            </article>
          ))}
        </div>
      )}
    </main>
  );
}

export default function MarketPage() {
  return <Suspense fallback={null}><Market /></Suspense>;
}
