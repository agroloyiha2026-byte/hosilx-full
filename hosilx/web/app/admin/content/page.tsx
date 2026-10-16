"use client";
import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { useUser } from "@/lib/useUser";
import { uploadImage } from "@/lib/upload";

type News = { id: string; title: string; published: boolean };
type Ad = { id: string; title: string; placement: string; active: boolean };
const PL = [["home_top", "Bosh sahifa — tepa"], ["home_middle", "Bosh sahifa — o‘rta"], ["market_top", "Bozor — tepa"]];

export default function Content() {
  const { profile } = useUser();
  const ok = profile?.role === "admin";
  const [tab, setTab] = useState<"news" | "ads" | "site">("news");
  const [news, setNews] = useState<News[]>([]);
  const [ads, setAds] = useState<Ad[]>([]);
  const [msg, setMsg] = useState("");
  const [nt, setNt] = useState(""); const [nb, setNb] = useState(""); const [nf, setNf] = useState<File | null>(null);
  const [at, setAt] = useState(""); const [al, setAl] = useState(""); const [ap, setAp] = useState("home_top");
  const [af, setAf] = useState<File | null>(null); const [ae, setAe] = useState("");
  const [hero, setHero] = useState<File | null>(null); const [ann, setAnn] = useState("");

  const load = useCallback(async () => {
    const [n, a, s] = await Promise.all([
      supabase.from("news").select("id,title,published").order("created_at", { ascending: false }),
      supabase.from("ads").select("id,title,placement,active").order("created_at", { ascending: false }),
      supabase.from("site_settings").select("value").eq("key", "announcement").maybeSingle(),
    ]);
    setNews((n.data ?? []) as News[]); setAds((a.data ?? []) as Ad[]); setAnn(s.data?.value ?? "");
  }, []);
  useEffect(() => { if (ok) load(); }, [ok, load]);

  if (!profile) return <p className="soft">Yuklanmoqda...</p>;
  if (!ok) return <div className="empty">403</div>;
  const done = (e: { message: string } | null) => { setMsg(e ? "Xatolik: " + e.message : "Saqlandi ✓"); load(); };

  async function addNews(e: React.FormEvent) {
    e.preventDefault();
    try {
      const image_url = nf ? await uploadImage(nf, profile!.id) : null;
      const { error } = await supabase.from("news").insert({ title: nt.trim(), body: nb.trim(), image_url });
      if (!error) { setNt(""); setNb(""); setNf(null); }
      done(error);
    } catch { setMsg("Rasm yuklanmadi (5 MB gacha rasm)"); }
  }
  async function addAd(e: React.FormEvent) {
    e.preventDefault();
    if (al && !/^https?:\/\//i.test(al)) return setMsg("Havola https:// bilan boshlansin");
    if (!af) return setMsg("Reklama rasmini tanlang");
    try {
      const image_url = await uploadImage(af, profile!.id);
      const { error } = await supabase.from("ads").insert({ title: at.trim(), link_url: al || null, placement: ap, image_url, ends_at: ae ? new Date(ae).toISOString() : null });
      if (!error) { setAt(""); setAl(""); setAf(null); setAe(""); }
      done(error);
    } catch { setMsg("Rasm yuklanmadi (5 MB gacha rasm)"); }
  }
  async function saveHero() {
    if (!hero) return setMsg("Rasmni tanlang");
    try { const v = await uploadImage(hero, profile!.id); done((await supabase.from("site_settings").upsert({ key: "hero_image", value: v })).error); }
    catch { setMsg("Rasm yuklanmadi (5 MB gacha rasm)"); }
  }
  const clearHero = async () => done((await supabase.from("site_settings").upsert({ key: "hero_image", value: "" })).error);
  const saveAnn = async () => done((await supabase.from("site_settings").upsert({ key: "announcement", value: ann.trim() })).error);

  return (
    <main>
      <h1>📰 Kontent boshqaruvi</h1>
      <div className="chips" style={{ marginBottom: 16 }}>
        {(["news", "ads", "site"] as const).map((k) => (
          <button key={k} className={"btn small" + (tab === k ? "" : " ghost")} onClick={() => { setTab(k); setMsg(""); }}>
            {k === "news" ? "Yangiliklar" : k === "ads" ? "Reklamalar" : "Sayt fon rasmi"}</button>))}
      </div>
      {msg && <p className="soft">{msg}</p>}

      {tab === "news" && <>
        <form className="card feature" style={{ display: "grid", gap: 10, marginBottom: 20 }} onSubmit={addNews}>
          <input required placeholder="Sarlavha" value={nt} onChange={(e) => setNt(e.target.value)} />
          <textarea required rows={5} placeholder="Matn" value={nb} onChange={(e) => setNb(e.target.value)} />
          <input type="file" accept="image/*" onChange={(e) => setNf(e.target.files?.[0] ?? null)} />
          <button className="btn">Yangilik qo‘shish</button>
        </form>
        {news.map((n) => (
          <div key={n.id} className="card feature" style={{ flexDirection: "row", alignItems: "center", gap: 10, marginBottom: 8, padding: 14 }}>
            <b style={{ flex: 1 }}>{n.title} {!n.published && <span className="badge">yashirin</span>}</b>
            <button className="btn ghost small" onClick={async () => done((await supabase.from("news").update({ published: !n.published }).eq("id", n.id)).error)}>{n.published ? "Yashirish" : "Chiqarish"}</button>
            <button className="btn ghost small" onClick={async () => done((await supabase.from("news").delete().eq("id", n.id)).error)}>O‘chirish</button>
          </div>))}
      </>}

      {tab === "ads" && <>
        <form className="card feature" style={{ display: "grid", gap: 10, marginBottom: 20 }} onSubmit={addAd}>
          <input required placeholder="Reklama nomi" value={at} onChange={(e) => setAt(e.target.value)} />
          <input placeholder="Havola (https://...) — ixtiyoriy" value={al} onChange={(e) => setAl(e.target.value)} />
          <select value={ap} onChange={(e) => setAp(e.target.value)}>{PL.map(([v, l]) => <option key={v} value={v}>{l}</option>)}</select>
          <label className="soft">Tugash sanasi (ixtiyoriy)<input type="datetime-local" value={ae} onChange={(e) => setAe(e.target.value)} style={{ display: "block", marginTop: 4 }} /></label>
          <input type="file" accept="image/*" onChange={(e) => setAf(e.target.files?.[0] ?? null)} />
          <span className="soft">Tavsiya: keng banner, taxminan 1200×300 px.</span>
          <button className="btn">Reklama qo‘shish</button>
        </form>
        {ads.map((a) => (
          <div key={a.id} className="card feature" style={{ flexDirection: "row", alignItems: "center", gap: 10, marginBottom: 8, padding: 14 }}>
            <b style={{ flex: 1 }}>{a.title} <span className="badge">{PL.find((p) => p[0] === a.placement)?.[1]}</span> {!a.active && <span className="badge">o‘chiq</span>}</b>
            <button className="btn ghost small" onClick={async () => done((await supabase.from("ads").update({ active: !a.active }).eq("id", a.id)).error)}>{a.active ? "O‘chirib qo‘yish" : "Yoqish"}</button>
            <button className="btn ghost small" onClick={async () => done((await supabase.from("ads").delete().eq("id", a.id)).error)}>O‘chirish</button>
          </div>))}
      </>}

      {tab === "site" && <div style={{ display: "grid", gap: 16, maxWidth: 520 }}>
        <div className="card feature" style={{ display: "grid", gap: 10 }}>
          <h3 style={{ margin: 0 }}>Bosh sahifa fon rasmi</h3>
          <input type="file" accept="image/*" onChange={(e) => setHero(e.target.files?.[0] ?? null)} />
          <div style={{ display: "flex", gap: 8 }}><button className="btn" onClick={saveHero}>Saqlash</button><button className="btn ghost" onClick={clearHero}>Standartga qaytarish</button></div>
        </div>
        <div className="card feature" style={{ display: "grid", gap: 10 }}>
          <h3 style={{ margin: 0 }}>Yuqori e’lon satri</h3>
          <input placeholder="Masalan: Yangi mavsum aksiyasi!" value={ann} onChange={(e) => setAnn(e.target.value)} />
          <button className="btn" onClick={saveAnn}>Saqlash</button><span className="soft">Bo‘sh qoldirsangiz, satr ko‘rinmaydi.</span>
        </div>
      </div>}
    </main>
  );
}
