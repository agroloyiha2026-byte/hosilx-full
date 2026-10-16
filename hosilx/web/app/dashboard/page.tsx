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
        supabase.from("tasks").select("id,title,due_at").eq("user_id", profile.id)
          .eq("done", false).lte("due_at", end.toISOString()).order("due_at").limit(5),
        supabase.from("products").select("id", { count: "exact", head: true })
          .eq("seller_id", profile.id).eq("status", "active"),
        supabase.from("inquiries").select("id, products!inner(seller_id)", { count: "exact", head: true })
          .eq("products.seller_id", profile.id).eq("status", "new"),
        supabase.from("finance_entries").select("kind,amount,currency").eq("user_id", profile.id)
          .eq("planned", false).gte("entry_date", monthStart.toISOString().slice(0, 10)),
      ]);
      setTasks((tk.data ?? []) as Task[]);
      setListings(pr.count ?? 0);
      setRequests(rq.count ?? 0);
      setFin((fe.data ?? []) as Fin[]);
    })();
  }, [profile]);

  const totals = totalsByCurrency(fin);

  if (!profile) return <p className="soft">{t("loading")}</p>;
  return (
    <main>
      <h1>{t("hello")}, {profile.full_name || "👋"}</h1>
      <div className="grid" style={{ marginBottom: 24 }}>
        <div className="card feature"><span className="soft">{t("today_tasks")}</span><b className="price">{tasks.length}</b></div>
        <div className="card feature"><span className="soft">{t("active_listings")}</span><b className="price">{listings}</b></div>
        <div className="card feature"><span className="soft">{t("new_requests")}</span><b className="price">{requests}</b></div>
      </div>
      <div className="grid">
        <section className="card feature">
          <h3>{t("today_tasks")}</h3>
          {tasks.length === 0 ? <p className="soft">{t("no_tasks_today")}</p> :
            tasks.map((x) => <p key={x.id} style={{ margin: "4px 0" }}>▫️ {new Date(x.due_at).toTimeString().slice(0, 5)} — {x.title}</p>)}
          <Link href="/dashboard/tasks" className="btn ghost small">{t("add_task")}</Link>
        </section>
        <section className="card feature">
          <h3>{t("d_fin")} · {t("this_month")}</h3>
          {Object.keys(totals).length === 0 ? <p className="soft">{t("no_fin")}</p> :
            Object.entries(totals).map(([cur, v]) => (
              <p key={cur} style={{ margin: "4px 0" }}>
                {t("income")}: {v.inc.toLocaleString()} {cur}<br />
                {t("expense")}: {v.exp.toLocaleString()} {cur}<br />
                <b>{t("profit")}: {(v.inc - v.exp).toLocaleString()} {cur}</b>
              </p>))}
          <Link href="/dashboard/finance" className="btn ghost small">{t("d_fin")}</Link>
        </section>
        <section className="card feature">
          <h3>🤖 AI</h3>
          <Link href="/ai" className="btn small">{t("ask_ai_btn")}</Link>
        </section>
      </div>
    </main>
  );
}
