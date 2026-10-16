"use client";
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useUser } from "@/lib/useUser";
import { uploadImage } from "@/lib/upload";
import { useApp } from "@/components/Providers";

type P = { id: string; title: string; price: number; currency: string; unit: string; quantity: number; status: string };
const CATS = ["fruit", "vegetable", "grain", "dairy", "other"];
const blank = { title: "", category: "vegetable", product_type: "", price: "", currency: "UZS",
  unit: "kg", quantity: "", region: "", description: "" };

export default function MyProducts() {
  const { t } = useApp();
  const { profile } = useUser();
  const [list, setList] = useState<P[]>([]);
  const [f, setF] = useState(blank);
  const [msg, setMsg] = useState("");
  const [file, setFile] = useState<File | null>(null);

  const load = useCallback(async () => {
    if (!profile) return;
    const { data } = await supabase.from("products").select("id,title,price,currency,unit,quantity,status")
      .eq("seller_id", profile.id).order("created_at", { ascending: false });
    setList((data ?? []) as P[]);
  }, [profile]);
  useEffect(() => { load(); }, [load]);

  const set = (k: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) =>
    setF({ ...f, [k]: e.target.value });

  async function add(e: React.FormEvent) {
    e.preventDefault();
    setMsg("");
    let image_url: string | null = null;
    try { if (file) image_url = await uploadImage(file, profile!.id); } catch { return setMsg(t("err_generic")); }
    const { error } = await supabase.from("products").insert({
      image_url, seller_id: profile!.id, title: f.title.trim(), category: f.category,
      product_type: f.product_type.trim().toLowerCase(), price: Number(f.price), currency: f.currency,
      unit: f.unit, quantity: Number(f.quantity), region: f.region.trim(), description: f.description || null,
    });
    if (error) return setMsg(t("err_generic"));
    setF(blank); setFile(null); setMsg(t("saved")); load();
  }
  async function hide(id: string) { await supabase.from("products").update({ status: "hidden" }).eq("id", id); load(); }
  async function remove(id: string) { await supabase.from("products").delete().eq("id", id); load(); }

  return (
    <main>
      <h1>{t("d_products")}</h1>
      <form className="card feature" style={{ gap: 10, display: "grid", marginBottom: 24 }} onSubmit={add}>
        <input required placeholder={t("f_title")} value={f.title} onChange={set("title")} />
        <select value={f.category} onChange={set("category")}>{CATS.map((c) => <option key={c} value={c}>{t("cat_" + c)}</option>)}</select>
        <input required placeholder={t("f_type")} value={f.product_type} onChange={set("product_type")} />
        <div style={{ display: "flex", gap: 8 }}>
          <input required type="number" min="1" step="any" placeholder={t("f_price")} value={f.price} onChange={set("price")} style={{ flex: 1 }} />
          <select value={f.currency} onChange={set("currency")}><option>UZS</option><option>USD</option></select>
          <select value={f.unit} onChange={set("unit")}>{["kg", "tonna", "dona", "litr"].map((u) => <option key={u}>{u}</option>)}</select>
        </div>
        <input required type="number" min="0" step="any" placeholder={t("f_qty")} value={f.quantity} onChange={set("quantity")} />
        <input required placeholder={t("f_region")} value={f.region} onChange={set("region")} />
        <textarea placeholder={t("f_desc")} value={f.description} onChange={set("description")}
          style={{ padding: 10, borderRadius: 12, border: "1px solid var(--border)", background: "var(--card)", color: "var(--fg)" }} />
        <label className="soft">{t("f_image")}<input type="file" accept="image/*" onChange={(e) => setFile(e.target.files?.[0] ?? null)} /></label>
        <button className="btn">{t("add_product")}</button>
        {msg && <span className="soft">{msg}</span>}
      </form>
      {list.length === 0 ? <div className="empty">{t("no_listings")}</div> : (
        <div className="grid">{list.map((p) => (
          <div key={p.id} className="card feature">
            <h3>{p.title}</h3>
            <span className="price">{Number(p.price).toLocaleString()} {p.currency}/{p.unit}</span>
            <span className="soft">{Number(p.quantity)} {p.unit} · {p.status}</span>
            <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
              {p.status === "active" && <button className="btn ghost small" onClick={() => hide(p.id)}>{t("hide")}</button>}
              <button className="btn ghost small" onClick={() => remove(p.id)}>{t("del")}</button>
            </div>
          </div>))}</div>
      )}
    </main>
  );
}
