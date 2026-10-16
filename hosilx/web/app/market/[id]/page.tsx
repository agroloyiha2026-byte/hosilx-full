"use client";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { useApp } from "@/components/Providers";

type P = { id: string; title: string; product_type: string; price: number; currency: string; unit: string;
  quantity: number; region: string; description: string | null; image_url: string | null; seller_id: string };

export default function ProductPage() {
  const { t } = useApp();
  const { id } = useParams<{ id: string }>();
  const [p, setP] = useState<P | null>(null);
  const [state, setState] = useState<"loading" | "ok" | "missing">("loading");
  const [uid, setUid] = useState<string | null>(null);
  const [offer, setOffer] = useState("");
  const [qty, setQty] = useState("");
  const [msg, setMsg] = useState("");
  const [info, setInfo] = useState("");

  useEffect(() => {
    (async () => {
      const { data: u } = await supabase.auth.getUser();
      setUid(u.user?.id ?? null);
      const { data } = await supabase.from("products").select("*").eq("id", id).maybeSingle();
      if (!data) return setState("missing");
      setP(data as P); setState("ok");
    })();
  }, [id]);

  async function save() {
    if (!uid) return;
    const { error } = await supabase.from("saved_products").upsert({ user_id: uid, product_id: id });
    setInfo(error ? t("err_generic") : t("saved"));
  }
  async function report() {
    const reason = window.prompt(t("report")); if (!reason || !uid) return;
    await supabase.from("reports").insert({ reporter_id: uid, product_id: id, reason: reason.slice(0, 500) });
    setInfo(t("sent"));
  }
  async function send(e: React.FormEvent) {
    e.preventDefault(); setInfo("");
    const { error } = await supabase.from("inquiries").insert({
      product_id: id, buyer_id: uid, offered_price: offer ? Number(offer) : null,
      quantity: qty ? Number(qty) : null, message: msg || null,
    });
    setInfo(error ? t("err_generic") : t("sent"));
    if (!error) { setOffer(""); setQty(""); setMsg(""); }
  }

  if (state === "loading") return <p className="container soft">{t("loading")}</p>;
  if (state === "missing" || !p) return <div className="container empty">{t("not_found")}</div>;
  return (
    <main className="container" style={{ padding: "24px 20px 64px", display: "grid", gap: 24, gridTemplateColumns: "repeat(auto-fit,minmax(300px,1fr))" }}>
      <div className="card">
        <div className="img" style={p.image_url ? { backgroundImage: `url(${p.image_url})` } : undefined}>{!p.image_url && "🌿"}</div>
        <div className="body">
          <h1 style={{ margin: 0 }}>{p.title}</h1>
          {uid && <div style={{ display: "flex", gap: 8 }}><button className="btn ghost small" onClick={save}>❤️ {t("d_saved")}</button><button className="btn ghost small" onClick={report}>⚑ {t("report")}</button></div>}
          <span className="price">{Number(p.price).toLocaleString()} {p.currency}/{p.unit}</span>
          <span className="soft">{t("available")}: {Number(p.quantity)} {p.unit} · 📍 {p.region}</span>
          {p.description && <p>{p.description}</p>}
        </div>
      </div>
      <form className="card feature" style={{ display: "grid", gap: 10, alignSelf: "start" }} onSubmit={send}>
        <h3 style={{ margin: 0 }}>{t("inquiry_title")}</h3>
        {!uid ? <><p className="soft">{t("login_first")}</p><Link className="btn" href="/login">{t("signin")}</Link></> : uid === p.seller_id ? null : (
          <>
            <input type="number" min="1" step="any" placeholder={t("f_offer")} value={offer} onChange={(e) => setOffer(e.target.value)} />
            <input type="number" min="0" step="any" placeholder={t("f_qty")} value={qty} onChange={(e) => setQty(e.target.value)} />
            <input placeholder={t("f_msg")} value={msg} onChange={(e) => setMsg(e.target.value)} />
            <button className="btn">{t("send")}</button>
            {info && <span className="soft">{info}</span>}
          </>)}
      </form>
    </main>
  );
}
