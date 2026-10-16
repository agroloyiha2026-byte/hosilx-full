"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import Onboarding from "@/components/Onboarding";
import { useApp } from "@/components/Providers";

export default function DashLayout({ children }: { children: React.ReactNode }) {
  const { t } = useApp();
  const router = useRouter();
  const links: [string, string][] = [
    ["/dashboard", "d_home"], ["/dashboard/products", "d_products"],
    ["/dashboard/tasks", "d_tasks"], ["/dashboard/finance", "d_fin"],
    ["/dashboard/inquiries", "d_inq"], ["/dashboard/warehouses", "d_wh"], ["/dashboard/saved", "d_saved"], ["/dashboard/settings", "d_settings"], ["/price", "nav_price"],
  ];
  return (
    <div className="container" style={{ padding: "16px 20px 64px" }}>
      <nav style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 20 }}>
        {links.map(([href, k]) => <Link key={href} href={href} className="btn ghost small">{t(k)}</Link>)}
        <button className="btn small" style={{ marginLeft: "auto" }}
          onClick={async () => { await supabase.auth.signOut(); router.push("/"); }}>{t("logout")}</button>
      </nav>
      <Onboarding />
      {children}
    </div>
  );
}
