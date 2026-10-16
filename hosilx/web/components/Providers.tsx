"use client";
import Link from "next/link";
import { createContext, useContext, useEffect, useState, ReactNode } from "react";
import { Lang, LANGS, dict } from "@/lib/i18n";

type Theme = "light" | "dark";
type Ctx = { lang: Lang; setLang: (l: Lang) => void; theme: Theme;
  setTheme: (t: Theme) => void; t: (k: string) => string };
const AppCtx = createContext<Ctx>(null as unknown as Ctx);
export const useApp = () => useContext(AppCtx);

function safeGet(k: string) { try { return localStorage.getItem(k); } catch { return null; } }
function safeSet(k: string, v: string) { try { localStorage.setItem(k, v); } catch {} }

export default function Providers({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>("uz");
  const [theme, setThemeState] = useState<Theme>("light");

  useEffect(() => {
    const l = safeGet("hx-lang") as Lang | null;
    if (l && LANGS.includes(l)) setLangState(l);
    const th = (document.documentElement.dataset.theme as Theme) || "light";
    setThemeState(th);
  }, []);

  const setLang = (l: Lang) => { setLangState(l); safeSet("hx-lang", l); document.documentElement.lang = l; };
  const setTheme = (th: Theme) => { setThemeState(th); safeSet("hx-theme", th);
    document.documentElement.dataset.theme = th; };
  const t = (k: string) => dict[lang][k] ?? dict.uz[k] ?? k;

  return (
    <AppCtx.Provider value={{ lang, setLang, theme, setTheme, t }}>
      <header className="top">
        <div className="container">
          <Link href="/" className="logo">🌾 Hosil X</Link>
          <nav>
            <Link href="/market">{t("nav_market")}</Link>
            <Link href="/warehouses">{t("nav_wh")}</Link>
            <Link href="/price">{t("nav_price")}</Link>
            <Link href="/ai">{t("nav_ai")}</Link>
          </nav>
          <select aria-label="Language" value={lang} onChange={(e) => setLang(e.target.value as Lang)}>
            {LANGS.map((l) => <option key={l} value={l}>{l.toUpperCase()}</option>)}
          </select>
          <button className="btn ghost small" aria-label="Theme"
            onClick={() => setTheme(theme === "dark" ? "light" : "dark")}>
            {theme === "dark" ? "☀️" : "🌙"}
          </button>
          <Link href="/login" className="btn small">{t("login")}</Link>
        </div>
      </header>
      {children}
    </AppCtx.Provider>
  );
}
