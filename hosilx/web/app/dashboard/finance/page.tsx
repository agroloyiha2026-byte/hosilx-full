"use client";
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useUser } from "@/lib/useUser";
import { totalsByCurrency } from "@/lib/finance";
import { useApp } from "@/components/Providers";

type E = { id: string; kind: string; category: string; amount: number; currency: string; planned: boolean; entry_date: string; note: string | null };
const CATS = ["sales", "seeds", "fertilizer", "labor", "transport", "storage", "other"];

export default function Finance() {
  const { t } = useApp();
  const { profile } = useUser();
  const [list, setList] = useState<E[]>([]);
  const [f, setF] = useState({ kind: "expense", category: "seeds", amount: "", currency: "UZS",
    planned: false, entry_date: new Date().toISOString().slice(0, 10), note: "" });

  const load = useCallback(async () => {
    if (!profile) return;
    const { data } = await supabase.from("finance_entries").select("*").eq("user_id", profile.id)
      .order("entry_date", { ascending: false }).limit(200);
    setList((data ?? []) as E[]);
  }, [profile]);
  useEffect(() => { load(); }, [load]);

  async function add(e: React.FormEvent) {
    e.preventDefault();
    await supabase.from("finance_entries").insert({ user_id: profile!.id, ...f, amount: Number(f.amount), note: f.note || null });
    setF({ ...f, amount: "", note: "" }); load();
  }
  async function remove(id: string) { await supabase.from("finance_entries").delete().eq("id", id); load(); }

  const totals = totalsByCurrency(list);

  return (
    <main>
      <h1>{t("d_fin")}</h1>
      {Object.keys(totals).length > 0 && (
        <div className="grid" style={{ marginBottom: 20 }}>
          {Object.entries(totals).map(([cur, v]) => (
            <div key={cur} className="card feature">
              <span className="soft">{cur}</span>
              <div>{t("income")}: {v.inc.toLocaleString()}</div>
              <div>{t("expense")}: {v.exp.toLocaleString()}</div>
              <b className="price">{t("profit")}: {(v.inc - v.exp).toLocaleString()}</b>
            </div>))}
        </div>)}
      <p className="soft">{t("mixed_note")}</p>
      <form className="card feature" style={{ display: "grid", gap: 10, margin: "12px 0 24px" }} onSubmit={add}>
        <div style={{ display: "flex", gap: 8 }}>
          <select value={f.kind} onChange={(e) => setF({ ...f, kind: e.target.value })}>
            <option value="income">{t("income")}</option><option value="expense">{t("expense")}</option></select>
          <select value={f.category} onChange={(e) => setF({ ...f, category: e.target.value })}>
            {CATS.map((c) => <option key={c} value={c}>{t("fc_" + c)}</option>)}</select>
          <select value={f.currency} onChange={(e) => setF({ ...f, currency: e.target.value })}><option>UZS</option><option>USD</option></select>
        </div>
        <input required type="number" min="1" step="any" placeholder={t("f_amount")} value={f.amount} onChange={(e) => setF({ ...f, amount: e.target.value })} />
        <input type="date" value={f.entry_date} onChange={(e) => setF({ ...f, entry_date: e.target.value })} />
        <input placeholder={t("f_note")} value={f.note} onChange={(e) => setF({ ...f, note: e.target.value })} />
        <label><input type="checkbox" checked={f.planned} onChange={(e) => setF({ ...f, planned: e.target.checked })} /> {t("planned")}</label>
        <button className="btn">{t("save")}</button>
      </form>
      {list.length === 0 ? <div className="empty">{t("no_fin")}</div> : list.map((x) => (
        <div key={x.id} className="card feature" style={{ display: "flex", gap: 12, alignItems: "center", marginBottom: 8 }}>
          <div style={{ flex: 1 }}>
            <b>{x.kind === "income" ? "＋" : "－"}{Number(x.amount).toLocaleString()} {x.currency}</b>
            <div className="soft">{x.entry_date} · {t("fc_" + x.category)}{x.planned ? ` · ${t("planned")}` : ""}{x.note ? ` · ${x.note}` : ""}</div>
          </div>
          <button className="btn ghost small" onClick={() => remove(x.id)}>{t("del")}</button>
        </div>))}
    </main>
  );
}
