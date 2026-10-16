"use client";
import "@/app/shell.css";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { createContext, useContext, useEffect, useState, ReactNode } from "react";
import { Lang, LANGS, dict } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";

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
  const [email, setEmail] = useState<string | null>(null);
  const [open, setOpen] = useState(false);
  const path = usePathname();

  useEffect(() => {
    const l = safeGet("hx-lang") as Lang | null;
    if (l && LANGS.includes(l)) setLangState(l);
    setThemeState((document.documentElement.dataset.theme as Theme) || "light");
    supabase.auth.getSession().then(({ data }) => setEmail(data.session?.user.email ?? null));
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setEmail(s?.user.email ?? null));
    return () => sub.subscription.unsubscribe();
  }, []);
  useEffect(() => setOpen(false), [path]);

  const setLang = (l: Lang) => { setLangState(l); safeSet("hx-lang", l); document.documentElement.lang = l; };
  const setTheme = (th: Theme) => { setThemeState(th); safeSet("hx-theme", th); document.documentElement.dataset.theme = th; };
  const t = (k: string) => dict[lang][k] ?? dict.uz[k] ?? k;
  const nav: [string, string][] = [["/market", "nav_market"], ["/warehouses", "nav_wh"], ["/price", "nav_price"], ["/news", "news"], ["/ai", "nav_ai"]];

  return (
    <AppCtx.Provider value={{ lang, setLang, theme, setTheme, t }}>
      <header className="hdr">
        <div className="container">
          <Link href="/" className="logo">🌾 Hosil X</Link>
          <nav className={"hdr-nav" + (open ? " open" : "")}>
            {nav.map(([href, k]) => <Link key={href} href={href} className={path.startsWith(href) ? "on" : ""}>{t(k)}</Link>)}
          </nav>
          <div className="hdr-right">
            <div className="seg" role="group" aria-label="Language">
              {LANGS.map((l) => <button key={l} className={l === lang ? "on" : ""} onClick={() => setLang(l)}>{l.toUpperCase()}</button>)}
            </div>
            <button className="iconbtn" aria-label="Theme" onClick={() => setTheme(theme === "dark" ? "light" : "dark")}>{theme === "dark" ? "☀️" : "🌙"}</button>
            {email
              ? <Link href="/dashboard" className="avatar" title={email}>{email[0].toUpperCase()}</Link>
              : <Link href="/login" className="btn small">{t("login")}</Link>}
            <button className="iconbtn menu-btn" aria-label="Menu" onClick={() => setOpen(!open)}>{open ? "✕" : "☰"}</button>
          </div>
        </div>
      </header>
      {children}
      <footer className="footer">
        <div className="container">
          <span>© {new Date().getFullYear()} Hosil X</span>
          <span><Link href="/market">{t("nav_market")}</Link> · <Link href="/warehouses">{t("nav_wh")}</Link> · <Link href="/news">{t("news")}</Link></span>
        </div>
      </footer>
    </AppCtx.Provider>
  );
}
