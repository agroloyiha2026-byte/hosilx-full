"use client";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useUser } from "@/lib/useUser";
import { useApp } from "@/components/Providers";
import { LANGS, Lang } from "@/lib/i18n";

export default function Settings() {
  const { t, lang, setLang, theme, setTheme } = useApp();
  const { profile } = useUser();
  const [name, setName] = useState("");
  const [region, setRegion] = useState("");
  const [msg, setMsg] = useState("");
  const [code, setCode] = useState("");

  useEffect(() => {
    if (!profile) return;
    supabase.from("profiles").select("full_name,region").eq("id", profile.id).single()
      .then(({ data }) => { setName(data?.full_name ?? ""); setRegion(data?.region ?? ""); });
  }, [profile]);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    const { error } = await supabase.from("profiles")
      .update({ full_name: name.trim(), region: region.trim() || null, language: lang, theme }).eq("id", profile!.id);
    setMsg(error ? t("err_generic") : t("saved"));
  }
  async function makeCode() {
    const bytes = crypto.getRandomValues(new Uint8Array(6));
    const c = Array.from(bytes, (b) => "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"[b % 32]).join("");
    const { error } = await supabase.from("link_codes").insert({ code: c, user_id: profile!.id });
    setCode(error ? "" : c); if (error) setMsg(t("err_generic"));
  }

  return (
    <main style={{ maxWidth: 480 }}>
      <h1>{t("d_settings")}</h1>
      <form className="card feature" style={{ display: "grid", gap: 10 }} onSubmit={save}>
        <input required placeholder={t("full_name")} value={name} onChange={(e) => setName(e.target.value)} />
        <input placeholder={t("f_region")} value={region} onChange={(e) => setRegion(e.target.value)} />
        <label className="soft">{t("lang_l")}</label>
        <select value={lang} onChange={(e) => setLang(e.target.value as Lang)}>{LANGS.map((l) => <option key={l} value={l}>{l.toUpperCase()}</option>)}</select>
        <label className="soft">{t("theme_l")}</label>
        <select value={theme} onChange={(e) => setTheme(e.target.value as "light" | "dark")}><option value="light">☀️ Light</option><option value="dark">🌙 Dark</option></select>
        <button className="btn">{t("save")}</button>
        {msg && <span className="soft">{msg}</span>}
      </form>
      <div className="card feature" style={{ marginTop: 16, display: "grid", gap: 8 }}>
        <h3 style={{ margin: 0 }}>✈️ {t("link_tg")}</h3>
        <button className="btn ghost small" onClick={makeCode}>{t("link_tg")}</button>
        {code && <><b style={{ fontSize: 24, letterSpacing: 3 }}>{code}</b><span className="soft">{t("link_hint")}</span></>}
      </div>
    </main>
  );
}
