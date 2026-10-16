"use client";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useApp } from "@/components/Providers";

type Ad = { id: string; title: string; image_url: string; link_url: string | null };

export default function AdBanner({ placement }: { placement: "home_top" | "home_middle" | "market_top" }) {
  const { t } = useApp();
  const [ad, setAd] = useState<Ad | null>(null);
  useEffect(() => {
    supabase.from("ads").select("id,title,image_url,link_url").eq("placement", placement)
      .eq("active", true).or(`ends_at.is.null,ends_at.gt.${new Date().toISOString()}`)
      .order("created_at", { ascending: false }).limit(1)
      .then(({ data }) => setAd((data && data[0]) || null));
  }, [placement]);
  if (!ad) return null;
  const safe = ad.link_url && /^https?:\/\//i.test(ad.link_url) ? ad.link_url : null; // javascript: havolalarga yo'l yo'q
  const img = <><img src={ad.image_url} alt={ad.title} /><span className="badge">{t("ad_label")}</span></>;
  return safe
    ? <a className="ad" href={safe} target="_blank" rel="noopener noreferrer sponsored">{img}</a>
    : <div className="ad">{img}</div>;
}
