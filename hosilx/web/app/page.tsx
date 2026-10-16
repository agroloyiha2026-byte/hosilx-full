"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { useApp } from "@/components/Providers";
import AdBanner from "@/components/AdBanner";

type P = { id: string; title: string; price: number; currency: string; unit: string; region: string; image_url: string | null };
type N = { id: string; title: string; body: string; image_url: string | null; created_at: string };

export default function Home() {
  const { t } = useApp();
  const router = useRouter();
  const [q, setQ] = useState("");
  const [hero, setHero] = useState("");
  const [ann, setAnn] = useState("");
  const [prods, setProds] = useState<P[]>([]);
  const [news, setNews] = useState<N[]>([]);
  const [counts, setCounts] = useState({ p: 0, w: 0 });

  useEffect(() => {
    (async () => {
      const [s, p, pc, wc, n] = await Promise.all([
        supabase.from("site_settings").select("key,value"),
        supabase.from("products").select("id,title,price,currency,unit,region,image_url").eq("status", "active").order("created_at", { ascending: false }).limit(6),
        supabase.from("products").select("id", { count: "exact", head: true }).eq("status", "active"),
        supabase.from("warehouses").select("id", { count: "exact", head: true }).eq("status", "active"),
        supabase.from("news").select("id,title,body,image_url,created_at").eq("published", true).order("created_at", { ascending: false }).limit(3),
      ]);
      const m = Object.fromEntries((s.data ?? []).map((r: { key: string; value: string }) => [r.key, r.value]));
      setHero(m.hero_image ?? ""); setAnn(m.announcement ?? "");
      setProds((p.data ?? []) as P[]); setNews((n.data ?? []) as N[]);
      setCounts({ p: pc.count ?? 0, w: wc.count ?? 0 });
    })();
  }, []);

  const steps = [["🚜", "s1_t", "s1_d"], ["🛒", "s2_t", "s2_d"], ["🏭", "s3_t", "s3_d"]];
  const heroStyle = hero ? { backgroundImage: `linear-gradient(rgba(16,45,26,.68), rgba(16,45,26,.82)), url(${hero})` } : undefined;

  return (
    <main>
      {ann && <div className="announce">{ann}</div>}
      <section className="hero" style={heroStyle}>
        <div className="container">
          <h1>{t("hero_title")}</h1>
          <p>{t("hero_sub")}</p>
          <form className="search" onSubmit={(e) => { e.preventDefault(); router.push(`/market?q=${encodeURIComponent(q.trim())}`); }}>
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t("search_ph")} />
            <button className="btn" style={{ background: "#fff", color: "#245C36", borderColor: "#fff" }}>{t("search")}</button>
          </form>
          <div className="chips">
            <Link href="/market" className="btn ghost small">🛒 {t("go_market")}</Link>
            <Link href="/warehouses" className="btn ghost small">🏭 {t("find_wh")}</Link>
            <Link href="/price" className="btn ghost small">📈 {t("nav_price")}</Link>
            <Link href="/ai" className="btn ghost small">🤖 {t("ask_ai")}</Link>
          </div>
        </div>
      </section>

      <div className="container">
        <div className="stats">
          <div className="stat"><b>{counts.p}</b><span className="soft">{t("stat_products")}</span></div>
          <div className="stat"><b>{counts.w}</b><span className="soft">{t("stat_wh")}</span></div>
          <div className="stat"><b>3</b><span className="soft">UZ · RU · EN</span></div>
        </div>
        <AdBanner placement="home_top" />
      </div>

      <section className="block">
        <div className="container">
          <div className="section-head"><h2>{t("latest_products")}</h2><Link href="/market" className="btn ghost small">{t("all_products")} →</Link></div>
          {prods.length === 0 ? <div className="empty">{t("empty_market")}</div> : (
            <div className="grid">
              {prods.map((p) => (
                <Link key={p.id} href={`/market/${p.id}`} className="card">
                  <div className="img" style={p.image_url ? { backgroundImage: `url(${p.image_url})` } : undefined}>{!p.image_url && "🌿"}</div>
                  <div className="body">
                    <h3>{p.title}</h3>
                    <span className="price">{Number(p.price).toLocaleString()} {p.currency}/{p.unit}</span>
                    <span className="soft">📍 {p.region}</span>
                  </div>
                </Link>))}
            </div>)}
          <AdBanner placement="home_middle" />
        </div>
      </section>

      <section className="block" style={{ background: "var(--muted-bg)" }}>
        <div className="container">
          <div className="section-head"><h2>{t("how_title")}</h2></div>
          <div className="grid">
            {steps.map(([ico, a, b]) => (
              <div key={a} className="card feature hover"><div className="ico">{ico}</div><h3>{t(a)}</h3><p className="soft" style={{ margin: 0 }}>{t(b)}</p></div>))}
          </div>
        </div>
      </section>

      <section className="block">
        <div className="container">
          <div className="section-head"><h2>{t("news")}</h2><Link href="/news" className="btn ghost small">{t("all_news")} →</Link></div>
          {news.length === 0 ? <div className="empty">{t("no_news")}</div> : (
            <div className="grid">
              {news.map((n) => (
                <Link key={n.id} href="/news" className="card">
                  {n.image_url && <div className="img" style={{ backgroundImage: `url(${n.image_url})` }} />}
                  <div className="body">
                    <span className="soft">{new Date(n.created_at).toLocaleDateString()}</span>
                    <h3>{n.title}</h3>
                    <span className="soft">{n.body.slice(0, 110)}{n.body.length > 110 ? "…" : ""}</span>
                  </div>
                </Link>))}
            </div>)}
        </div>
      </section>

      <section className="block">
        <div className="container">
          <div className="cta"><h2 style={{ marginTop: 0 }}>{t("cta_t")}</h2><Link href="/login" className="btn">{t("cta_b")}</Link></div>
        </div>
      </section>
    </main>
  );
}
