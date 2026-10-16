"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useUser } from "@/lib/useUser";
import { totalsByCurrency } from "@/lib/finance";
import { useApp } from "@/components/Providers";

type Task = { id: string; title: string; due_at: string };
type Fin = { kind: string; amount: number; currency: string };

export default function Dashboard() {
  const { t } = useApp();
  const { profile } = useUser();
  const [tasks, setTasks] = useState<Task[]>([]);
  const [listings, setListings] = useState(0);
  const [requests, setRequests] = useState(0);
  const [fin, setFin] = useState<Fin[]>([]);

  useEffect(() => {
    if (!profile) return;
    const end = new Date(); end.setHours(23, 59, 59, 999);
    const monthStart = new Date(); monthStart.setDate(1);
    (async () => {
      const [tk, pr, rq, fe] = await Promise.all([
        supabase.from("tasks").select("id,title,due_at").eq("user_id", profile.id).eq("done", false).lte("due_at", end.toISOString()).order("due_at").limit(6),
        supabase.from("products").select("id", { count: "exact", head: true }).eq("seller_id", profile.id).eq("status", "active"),
        supabase.from("inquiries").select("id, products!inner(seller_id)", { count: "exact", head: true }).eq("products.seller_id", profile.id).eq("status", "new"),
        supabase.from("finance_entries").select("kind,amount,currency").eq("user_id", profile.id).eq("planned", false).gte("entry_date", monthStart.toISOString().slice(0, 10)),
      ]);
      setTasks((tk.data ?? []) as Task[]); setListings(pr.count ?? 0); setRequests(rq.count ?? 0); setFin((fe.data ?? []) as Fin[]);
    })();
  }, [profile]);

  if (!profile) return <p className="soft">{t("loading")}</p>;
  const totals = totalsByCurrency(fin.map((f) => ({ ...f, planned: false })));
  const farmer = profile.role === "farmer" || profile.role === "admin";

  return (
    <main>
      <h1>{t("hello")}, {profile.full_name || "👋"}</h1>
      <div className="quick">
        {farmer && <Link href="/dashboard/products" className="btn">＋ {t("add_product")}</Link>}
        {farmer && <Link href="/dashboard/tasks" className="btn ghost">✅ {t("add_task")}</Link>}
        {farmer && <Link href="/dashboard/finance" className="btn ghost">💰 {t("d_fin")}</Link>}
        <Link href="/ai" className="btn ghost">🤖 {t("ask_ai_btn")}</Link>
      </div>
      <div className="kpis">
        {farmer && <div className="kpi"><div className="ico">✅</div><div><b>{tasks.length}</b><span className="soft">{t("today_tasks")}</span></div></div>}
        {farmer && <div className="kpi"><div className="ico">🌿</div><div><b>{listings}</b><span className="soft">{t("active_listings")}</span></div></div>}
        <div className="kpi"><div className="ico">✉️</div><div><b>{requests}</b><span className="soft">{t("new_requests")}</span></div></div>
      </div>
      {farmer && (
        <div className="panels">
          <section className="panel">
            <h3>✅ {t("today_tasks")}</h3>
            {tasks.length === 0 ? <p className="soft" style={{ margin: 0 }}>{t("no_tasks_today")}</p> :
              tasks.map((x) => <div key={x.id} className="row"><span>{x.title}</span><span className="time">{new Date(x.due_at).toTimeString().slice(0, 5)}</span></div>)}
            <Link href="/dashboard/tasks" className="btn ghost small" style={{ alignSelf: "flex-start", marginTop: 6 }}>{t("add_task")}</Link>
          </section>
          <section className="panel">
            <h3>💰 {t("d_fin")} · {t("this_month")}</h3>
            {Object.keys(totals).length === 0 ? <p className="soft" style={{ margin: 0 }}>{t("no_fin")}</p> :
              Object.entries(totals).map(([cur, v]) => (
                <div key={cur}>
                  <div className="row"><span>{t("income")}</span><b>{v.inc.toLocaleString()} {cur}</b></div>
                  <div className="row"><span>{t("expense")}</span><b>{v.exp.toLocaleString()} {cur}</b></div>
                  <div className="row"><span>{t("profit")}</span><b style={{ color: v.inc - v.exp >= 0 ? "var(--accent)" : "#B3261E" }}>{(v.inc - v.exp).toLocaleString()} {cur}</b></div>
                </div>))}
            <Link href="/dashboard/finance" className="btn ghost small" style={{ alignSelf: "flex-start", marginTop: 6 }}>{t("d_fin")}</Link>
          </section>
        </div>)}
    </main>
  );
}
