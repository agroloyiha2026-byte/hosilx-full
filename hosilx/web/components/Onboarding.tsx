"use client";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useUser } from "@/lib/useUser";
import { useApp } from "@/components/Providers";

export default function Onboarding() {
  const { t } = useApp();
  const { profile } = useUser();
  const [show, setShow] = useState(false);
  useEffect(() => {
    if (!profile) return;
    supabase.from("profiles").select("onboarded").eq("id", profile.id).single()
      .then(({ data }) => setShow(data ? !data.onboarded : false));
  }, [profile]);
  if (!show) return null;
  async function done() { await supabase.from("profiles").update({ onboarded: true }).eq("id", profile!.id); setShow(false); }
  return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,.5)", display: "grid", placeItems: "center", zIndex: 50, padding: 16 }}>
      <div className="card feature" style={{ maxWidth: 420 }}>
        <h2 style={{ marginTop: 0 }}>🌾 {t("ob_title")}</h2>
        <p>🛒 {t("ob_1")}</p><p>🏭 {t("ob_2")}</p><p>🤖 {t("ob_3")}</p>
        <button className="btn" onClick={done}>{t("ob_ok")}</button>
      </div>
    </div>
  );
}
