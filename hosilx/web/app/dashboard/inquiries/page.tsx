"use client";
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useUser } from "@/lib/useUser";
import { useApp } from "@/components/Providers";

type I = { id: string; offered_price: number | null; quantity: number | null; message: string | null;
  status: string; created_at: string; products: { title: string; seller_id: string; currency: string } };

export default function Inquiries() {
  const { t } = useApp();
  const { profile } = useUser();
  const [list, setList] = useState<I[]>([]);
  const load = useCallback(async () => {
    const { data } = await supabase.from("inquiries")
      .select("id,offered_price,quantity,message,status,created_at,products(title,seller_id,currency)")
      .order("created_at", { ascending: false }).limit(100);
    setList((data ?? []) as unknown as I[]);
  }, []);
  useEffect(() => { if (profile) load(); }, [profile, load]);
  async function setStatus(id: string, status: string) { await supabase.from("inquiries").update({ status }).eq("id", id); load(); }

  return (
    <main>
      <h1>{t("d_inq")}</h1>
      {list.length === 0 ? <div className="empty">{t("no_inq")}</div> : list.map((x) => (
        <div key={x.id} className="card feature" style={{ marginBottom: 10 }}>
          <b>{x.products?.title}</b>
          <span className="soft">{t("st_" + x.status)} · {new Date(x.created_at).toLocaleDateString()}</span>
          <span>{x.offered_price ? `${Number(x.offered_price).toLocaleString()} ${x.products?.currency}` : ""} {x.quantity ? `· ${Number(x.quantity)}` : ""}</span>
          {x.message && <span className="soft">{x.message}</span>}
          {profile && x.products?.seller_id === profile.id && x.status === "new" && (
            <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
              <button className="btn small" onClick={() => setStatus(x.id, "accepted")}>{t("accept")}</button>
              <button className="btn ghost small" onClick={() => setStatus(x.id, "rejected")}>{t("reject")}</button>
            </div>)}
        </div>))}
    </main>
  );
}
