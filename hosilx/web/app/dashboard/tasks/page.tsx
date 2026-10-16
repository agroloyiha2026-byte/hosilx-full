"use client";
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useUser } from "@/lib/useUser";
import { useApp } from "@/components/Providers";

type T = { id: string; title: string; description: string | null; due_at: string; done: boolean };

export default function Tasks() {
  const { t } = useApp();
  const { profile } = useUser();
  const [list, setList] = useState<T[]>([]);
  const [title, setTitle] = useState("");
  const [desc, setDesc] = useState("");
  const [due, setDue] = useState("");

  const load = useCallback(async () => {
    if (!profile) return;
    const { data } = await supabase.from("tasks").select("id,title,description,due_at,done")
      .eq("user_id", profile.id).order("done").order("due_at");
    setList((data ?? []) as T[]);
  }, [profile]);
  useEffect(() => { load(); }, [load]);

  async function add(e: React.FormEvent) {
    e.preventDefault();
    await supabase.from("tasks").insert({
      user_id: profile!.id, title: title.trim(), description: desc || null, due_at: new Date(due).toISOString(),
    });
    setTitle(""); setDesc(""); setDue(""); load();
  }
  async function toggle(x: T) { await supabase.from("tasks").update({ done: !x.done }).eq("id", x.id); load(); }
  async function remove(id: string) { await supabase.from("tasks").delete().eq("id", id); load(); }

  return (
    <main>
      <h1>{t("d_tasks")}</h1>
      <form className="card feature" style={{ display: "grid", gap: 10, marginBottom: 24 }} onSubmit={add}>
        <input required placeholder={t("f_title")} value={title} onChange={(e) => setTitle(e.target.value)} />
        <input placeholder={t("f_desc")} value={desc} onChange={(e) => setDesc(e.target.value)} />
        <input required type="datetime-local" aria-label={t("f_due")} value={due} onChange={(e) => setDue(e.target.value)} />
        <button className="btn">{t("add_task")}</button>
      </form>
      {list.length === 0 ? <div className="empty">{t("no_tasks")}</div> : list.map((x) => (
        <div key={x.id} className="card feature" style={{ display: "flex", gap: 12, alignItems: "center", marginBottom: 10, opacity: x.done ? 0.6 : 1 }}>
          <input type="checkbox" checked={x.done} onChange={() => toggle(x)} />
          <div style={{ flex: 1 }}>
            <b style={{ textDecoration: x.done ? "line-through" : "none" }}>{x.title}</b>
            <div className="soft">{new Date(x.due_at).toLocaleString()}{x.description ? ` · ${x.description}` : ""}</div>
          </div>
          <button className="btn ghost small" onClick={() => remove(x.id)}>{t("del")}</button>
        </div>))}
    </main>
  );
}
