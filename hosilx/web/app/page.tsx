"use client";
import Link from "next/link";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { useApp } from "@/components/Providers";

export default function Home() {
  const { t } = useApp();
  const router = useRouter();
  const [q, setQ] = useState("");
  const features = [
    ["🛒", "f1_t", "f1_d"], ["🏭", "f2_t", "f2_d"],
    ["🤖", "f3_t", "f3_d"], ["📒", "f4_t", "f4_d"],
  ];
  return (
    <main>
      <section className="hero">
        <div className="container">
          <h1>{t("hero_title")}</h1>
          <p>{t("hero_sub")}</p>
          <form className="search" onSubmit={(e) => { e.preventDefault();
            router.push(`/market?q=${encodeURIComponent(q.trim())}`); }}>
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t("search_ph")} />
            <button className="btn" style={{ background: "#fff", color: "#245C36", borderColor: "#fff" }}>
              {t("search")}
            </button>
          </form>
          <div className="search" style={{ marginTop: 14 }}>
            <Link href="/market" className="btn ghost">{t("go_market")}</Link>
            <Link href="/warehouses" className="btn ghost">{t("find_wh")}</Link>
            <Link href="/ai" className="btn ghost">{t("ask_ai")}</Link>
          </div>
        </div>
      </section>
      <section className="block">
        <div className="container grid">
          {features.map(([icon, title, desc]) => (
            <div key={title} className="card feature">
              <div style={{ fontSize: 32 }}>{icon}</div>
              <h3>{t(title)}</h3>
              <p className="soft">{t(desc)}</p>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
