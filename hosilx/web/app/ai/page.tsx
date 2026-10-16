"use client";
import { useRef, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { useApp } from "@/components/Providers";

type M = { role: "user" | "assistant"; content: string };

export default function AI() {
  const { t } = useApp();
  const [msgs, setMsgs] = useState<M[]>([]);
  const [q, setQ] = useState("");
  const [busy, setBusy] = useState(false);
  const [needLogin, setNeedLogin] = useState(false);
  const [img, setImg] = useState<{ media_type: string; data: string } | null>(null);
  const end = useRef<HTMLDivElement>(null);

  function pick(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    if (!f || !/^image\/(jpeg|png|webp)$/.test(f.type) || f.size > 3 * 1024 * 1024) { setImg(null); return; }
    const rd = new FileReader();
    rd.onload = () => setImg({ media_type: f.type, data: String(rd.result).split(",")[1] });
    rd.readAsDataURL(f);
  }
  async function send(e: React.FormEvent) {
    e.preventDefault();
    if (!q.trim() || busy) return;
    const { data } = await supabase.auth.getSession();
    if (!data.session) return setNeedLogin(true);
    const next = [...msgs, { role: "user", content: q.trim() } as M];
    setMsgs(next); setQ(""); setBusy(true); setImg(null);
    try {
      const r = await fetch("/api/ai", { method: "POST",
        headers: { "content-type": "application/json", authorization: `Bearer ${data.session.access_token}` },
        body: JSON.stringify({ messages: next, image: img }) });
      const j = await r.json();
      const text = r.ok ? j.text : r.status === 429 ? t("ai_limit") : t("err_generic");
      setMsgs([...next, { role: "assistant", content: text }]);
    } catch { setMsgs([...next, { role: "assistant", content: t("error") }]); }
    finally { setBusy(false); setTimeout(() => end.current?.scrollIntoView({ behavior: "smooth" }), 50); }
  }

  return (
    <main className="container" style={{ maxWidth: 760, padding: "24px 20px 64px" }}>
      <h1>🤖 {t("ai_title")}</h1>
      <p className="soft">{t("ai_hint")}</p>
      {needLogin && <div className="empty"><p>{t("login_first")}</p><Link className="btn" href="/login">{t("signin")}</Link></div>}
      <div style={{ display: "grid", gap: 10, margin: "16px 0" }}>
        {msgs.map((m, i) => (
          <div key={i} className="card feature" style={{ whiteSpace: "pre-wrap",
            background: m.role === "user" ? "var(--muted-bg)" : "var(--card)", marginLeft: m.role === "user" ? 40 : 0, marginRight: m.role === "user" ? 0 : 40 }}>
            {m.content}</div>))}
        {busy && <p className="soft">{t("loading")}</p>}
        <div ref={end} />
      </div>
      <form className="search" onSubmit={send}>
        <input type="file" accept="image/jpeg,image/png,image/webp" onChange={pick} aria-label="image" />
        <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t("ai_ph")} />
        <button className="btn" disabled={busy}>{t("send")}</button>
      </form>
    </main>
  );
}
