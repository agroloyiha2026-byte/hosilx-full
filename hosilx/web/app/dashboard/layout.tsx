"use client";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { useUser } from "@/lib/useUser";
import Onboarding from "@/components/Onboarding";
import { useApp } from "@/components/Providers";

type L = { href: string; ico: string; k: string; roles: string[] } | "sep";
const F = "farmer", B = "buyer", W = "warehouse_owner";
const LINKS: L[] = [
  { href: "/dashboard", ico: "🏠", k: "d_home", roles: [F, B, W] },
  { href: "/dashboard/products", ico: "🌿", k: "d_products", roles: [F] },
  { href: "/dashboard/inquiries", ico: "✉️", k: "d_inq", roles: [F, B] },
  { href: "/dashboard/saved", ico: "❤️", k: "d_saved", roles: [F, B] },
  { href: "/dashboard/warehouses", ico: "🏭", k: "d_wh", roles: [F, W] },
  "sep",
  { href: "/dashboard/tasks", ico: "✅", k: "d_tasks", roles: [F] },
  { href: "/dashboard/finance", ico: "💰", k: "d_fin", roles: [F] },
  "sep",
  { href: "/market", ico: "🛒", k: "nav_market", roles: [F, B, W] },
  { href: "/ai", ico: "🤖", k: "nav_ai", roles: [F, B, W] },
  { href: "/dashboard/settings", ico: "⚙️", k: "d_settings", roles: [F, B, W] },
];

export default function DashLayout({ children }: { children: React.ReactNode }) {
  const { t } = useApp();
  const { profile } = useUser();
  const router = useRouter();
  const path = usePathname();
  const role = profile?.role ?? F;
  const isAdmin = role === "admin";
  const items = LINKS.filter((l) => l === "sep" || isAdmin || l.roles.includes(role));
  const admin: L[] = isAdmin ? ["sep", { href: "/admin", ico: "🛡️", k: "admin", roles: [] }, { href: "/admin/content", ico: "📰", k: "admin_c", roles: [] }] : [];
  const roleLabel = ({ farmer: "role_farmer", buyer: "role_buyer", warehouse_owner: "role_wh", admin: "admin" } as Record<string, string>)[role] ?? "role_farmer";
  const logout = async () => { await supabase.auth.signOut(); router.push("/"); };

  return (
    <div className="dash">
      <aside className="side">
        <div className="me">
          <div className="avatar">{(profile?.full_name || "?")[0].toUpperCase()}</div>
          <div><b>{profile?.full_name || "—"}</b><span className="soft">{t(roleLabel)}</span></div>
        </div>
        <nav className="sidenav">
          {[...items, ...admin].map((l, i) => l === "sep" ? <div key={i} className="sep" /> : (
            <Link key={l.href} href={l.href} className={path === l.href ? "active" : ""}><span className="ico">{l.ico}</span>{t(l.k)}</Link>))}
        </nav>
        <button className="btn ghost small" onClick={logout}>{t("logout")}</button>
      </aside>
      <section className="dmain">
        <Onboarding />
        {children}
      </section>
    </div>
  );
}
