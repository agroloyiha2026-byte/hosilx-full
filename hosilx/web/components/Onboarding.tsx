"use client";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useUser } from "@/lib/useUser";
import { useApp } from "@/components/Providers";

export default function Onboarding() {
  const { t } = useApp();
  const { profile } = useUser();
  const [show, setShow] = useState(false);
  const [role, setRole] = useState("farmer");

  useEffect(() => {
    if (!profile) return;
    supabase.from("profiles").select("onboarded,role").eq("id", profile.id).single()
      .then(({ data }) => { if (data) { setShow(!data.onboarded); setRole(data.role === "admin" ? "farmer" : data.role); } });
  }, [profile]);

  if (!show) return null;
  async function done() {
    if (profile!.role !== "admin") await supabase.rpc("set_my_role", { new_role: role });
    await supabase.from("profiles").update({ onboarded: true }).eq("id", profile!.id);
    setShow(false);
    window.location.reload();
  }
  return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,.5)", display: "grid", placeItems: "center", zIndex: 50, padding: 16 }}>
      <div className="card feature" style={{ maxWidth: 420 }}>
        <h2 style={{ marginTop: 0 }}>🌾 {t("ob_title")}</h2>
        <p>🛒 {t("ob_1")}</p><p>🏭 {t("ob_2")}</p><p>🤖 {t("ob_3")}</p>
        {profile?.role !== "admin" && (
          <>
            <label className="soft">{t("role")}</label>
            <select value={role} onChange={(e) => setRole(e.target.value)} style={{ marginBottom: 12 }}>
              <option value="farmer">{t("role_farmer")}</option>
              <option value="buyer">{t("role_buyer")}</option>
              <option value="warehouse_owner">{t("role_wh")}</option>
            </select>
          </>)}
        <button className="btn" onClick={done}>{t("ob_ok")}</button>
      </div>
    </div>
  );
}
