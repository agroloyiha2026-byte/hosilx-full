"use client";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useApp } from "@/components/Providers";

type N = { id: string; title: string; body: string; image_url: string | null; created_at: string };

export default function News() {
  const { t } = useApp();
  const [list, setList] = useState<N[] | null>(null);
  useEffect(() => {
    supabase.from("news").select("id,title,body,image_url,created_at").eq("published", true)
      .order("created_at", { ascending: false }).limit(50).then(({ data }) => setList((data ?? []) as N[]));
  }, []);
  return (
    <main className="container" style={{ padding: "32px 20px 64px", maxWidth: 820 }}>
      <h1>{t("news")}</h1>
      {list === null ? <p className="soft">{t("loading")}</p> : list.length === 0 ? <div className="empty">{t("no_news")}</div> : list.map((n) => (
        <article key={n.id} className="card" style={{ marginBottom: 20 }}>
          {n.image_url && <div className="img" style={{ backgroundImage: `url(${n.image_url})` }} />}
          <div className="body">
            <span className="soft">{new Date(n.created_at).toLocaleDateString()}</span>
            <h2 style={{ margin: "4px 0" }}>{n.title}</h2>
            <p style={{ whiteSpace: "pre-wrap", margin: 0 }}>{n.body}</p>
          </div>
        </article>))}
    </main>
  );
}
