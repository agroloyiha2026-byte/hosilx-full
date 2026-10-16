"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { useApp } from "@/components/Providers";

export default function Login() {
  const { t, lang } = useApp();
  const router = useRouter();
  const [mode, setMode] = useState<"in" | "up">("in");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [role, setRole] = useState("farmer");
  const [msg, setMsg] = useState<{ text: string; ok?: boolean } | null>(null);
    const [busy, setBusy] = useState(false);

  async function google() {
    setMsg(null);
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google", options: { redirectTo: `${window.location.origin}/dashboard` } });
    if (error) setMsg({ text: t("err_generic") });
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setMsg(null);
    if (mode === "up" && password.length < 8) return setMsg({ text: t("err_weak") });
    setBusy(true);
    try {
      if (mode === "in") {
        const { error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) return setMsg({ text: t("err_auth") });
        router.push("/dashboard");
      } else {
        const { data, error } = await supabase.auth.signUp({
          email, password, options: { data: { full_name: name, role } },
        });
        if (error) return setMsg({ text: t("err_generic") });
        if (data.session) {
          await supabase.from("profiles").update({ language: lang }).eq("id", data.user!.id);
          router.push("/dashboard");
        } else setMsg({ text: t("check_email"), ok: true });
      }
    } catch {
      setMsg({ text: t("err_generic") });
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="container" style={{ maxWidth: 440, padding: "40px 20px" }}>
      <form className="card" style={{ padding: 24, gap: 12 }} onSubmit={submit}>
        <h2 style={{ margin: 0 }}>{mode === "in" ? t("signin") : t("signup")}</h2>
        <button type="button" className="btn ghost" onClick={google}>G&nbsp; {t("google")}</button>
        <span className="soft" style={{ textAlign: "center" }}>— {t("or")} —</span>
        {mode === "up" && (
          <>
            <input required placeholder={t("full_name")} value={name} onChange={(e) => setName(e.target.value)} />
            <label className="soft">{t("role")}</label>
            <select value={role} onChange={(e) => setRole(e.target.value)}>
              <option value="farmer">{t("role_farmer")}</option>
              <option value="buyer">{t("role_buyer")}</option>
              <option value="warehouse_owner">{t("role_wh")}</option>
            </select>
          </>
        )}
        <input required type="email" placeholder={t("email")} value={email} onChange={(e) => setEmail(e.target.value)} />
        <input required type="password" placeholder={t("password")} value={password}
          onChange={(e) => setPassword(e.target.value)} />
        {msg && <p style={{ margin: 0, color: msg.ok ? "var(--accent)" : "#B3261E" }}>{msg.text}</p>}
        <button className="btn" disabled={busy}>{mode === "in" ? t("signin") : t("signup")}</button>
        <button type="button" className="btn ghost small" onClick={() => { setMode(mode === "in" ? "up" : "in"); setMsg(null); }}>
          {mode === "in" ? t("no_acc") : t("have_acc")}
        </button>
      </form>
    </main>
  );
}
