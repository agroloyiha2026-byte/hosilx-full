"use client";
import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { useUser } from "@/lib/useUser";
import { useApp } from "@/components/Providers";

type S = { product_id: string; products: { title: string; price: number; currency: string; unit: string; region: string } };

export default function Saved() {
  const { t } = useApp();
  const { profile } = useUser();
  const [list, setList] = useState<S[]>([]);
  const load = useCallback(async () => {
    if (!profile) return;
    const { data } = await supabase.from("saved_products")
      .select("product_id,products(title,price,currency,unit,region)").eq("user_id", profile.id);
    setList((data ?? []) as unknown as S[]);
  }, [profile]);
  useEffect(() => { load(); }, [load]);
  async function remove(pid: string) { await supabase.from("saved_products").delete().eq("product_id", pid).eq("user_id", profile!.id); load(); }
  return (
    <main>
      <h1>{t("d_saved")}</h1>
      {list.length === 0 ? <div className="empty">{t("saved_empty")}</div> : (
        <div className="grid">{list.filter((x) => x.products).map((x) => (
          <div key={x.product_id} className="card feature">
            <h3>{x.products.title}</h3>
            <span className="price">{Number(x.products.price).toLocaleString()} {x.products.currency}/{x.products.unit}</span>
            <span className="soft">📍 {x.products.region}</span>
            <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
              <Link className="btn small" href={`/market/${x.product_id}`}>{t("details")}</Link>
              <button className="btn ghost small" onClick={() => remove(x.product_id)}>{t("del")}</button>
            </div>
          </div>))}</div>)}
    </main>
  );
}
