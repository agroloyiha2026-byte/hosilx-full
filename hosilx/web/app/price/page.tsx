"use client";
import { useState } from "react";
import { supabase } from "@/lib/supabase";
import { useApp } from "@/components/Providers";

type S = { unit: string; currency: string; observations: number; min_price: number; max_price: number; median_price: number; last_date: string };

export default function Price() {
  const { t } = useApp();
  const [type, setType] = useState("");
  const [region, setRegion] = useState("");
  const [rows, setRows] = useState<S[] | null>(null);
  const [err, setErr] = useState(false);
  const [trend, setTrend] = useState<{ period: string; unit: string; currency: string; observations: number; median_price: number }[]>([]);

  async function run(e: React.FormEvent) {
    e.preventDefault(); setErr(false);
    const { data, error } = await supabase.rpc("price_stats", {
      p_type: type.trim().toLowerCase(), p_region: region.trim() || null });
    if (error) { setErr(true); return; }
    setRows((data ?? []) as S[]);
    const tr = await supabase.rpc("price_trend", { p_type: type.trim().toLowerCase(), p_region: region.trim() || null });
    setTrend(tr.error ? [] : (tr.data ?? []));
  }
  const fmt = (n: number) => Number(n).toLocaleString(undefined, { maximumFractionDigits: 0 });

  return (
    <main className="container" style={{ padding: "24px 20px 64px" }}>
      <h1>{t("ps_title")}</h1>
      <form className="toolbar" onSubmit={run}>
        <input required placeholder={t("f_type")} value={type} onChange={(e) => setType(e.target.value)} style={{ flex: 1 }} />
        <input placeholder={t("f_region")} value={region} onChange={(e) => setRegion(e.target.value)} />
        <button className="btn">{t("search")}</button>
      </form>
      <p className="soft">{t("ps_note")}</p>
      {err && <div className="empty">{t("error")}</div>}
      {rows && rows.length === 0 && <div className="empty">{t("ps_none")}</div>}
      <div className="grid">
        {rows?.map((r) => {
          const maxV = Number(r.max_price) || 1;
          return (
            <div key={r.unit + r.currency} className="card feature">
              <h3>{r.currency} / {r.unit}</h3>
              {[["ps_min", r.min_price], ["ps_med", r.median_price], ["ps_max", r.max_price]].map(([k, v]) => (
                <div key={k as string}>
                  <div style={{ display: "flex", justifyContent: "space-between" }}><span className="soft">{t(k as string)}</span><b>{fmt(v as number)}</b></div>
                  <div style={{ background: "var(--muted-bg)", height: 8, borderRadius: 8 }}>
                    <div style={{ width: `${((v as number) / maxV) * 100}%`, height: 8, borderRadius: 8, background: "var(--accent)" }} /></div>
                </div>))}
              <span className="soft">{t("ps_obs")}: {r.observations} · {t("ps_last")}: {r.last_date}</span>
              {r.observations < 5 && <span style={{ color: "var(--soil)" }}>{t("ps_low")}</span>}
            </div>);
        })}
      </div>
      {trend.length > 0 && (
        <>
          <h2>{t("ps_trend")}</h2>
          {Array.from(new Set(trend.map((x) => `${x.currency}/${x.unit}`))).map((key) => {
            const pts = trend.filter((x) => `${x.currency}/${x.unit}` === key);
            const mx = Math.max(...pts.map((x) => Number(x.median_price))) || 1;
            return (
              <div key={key} className="card feature" style={{ marginBottom: 12 }}>
                <b>{key}</b>
                <div style={{ display: "flex", alignItems: "flex-end", gap: 8, height: 120, overflowX: "auto" }}>
                  {pts.map((x) => (
                    <div key={x.period} title={`${x.period}: ${fmt(x.median_price)} (${x.observations})`} style={{ textAlign: "center", minWidth: 48 }}>
                      <div style={{ height: `${(Number(x.median_price) / mx) * 90}px`, background: x.observations < 3 ? "var(--soil)" : "var(--accent)", borderRadius: 6 }} />
                      <span className="soft" style={{ fontSize: 11 }}>{x.period.slice(0, 7)}</span>
                    </div>))}
                </div>
                {pts.some((x) => x.observations < 3) && <span className="soft">{t("ps_low")}</span>}
              </div>);
          })}
        </>)}
    </main>
  );
}
