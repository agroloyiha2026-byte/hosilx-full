import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

export const runtime = "nodejs";

const SYSTEM = `You are Hosil X AI, a friendly and professional agronomy assistant for farmers in Uzbekistan.
Reply in the user's language (Uzbek, Russian or English). Keep answers short, practical and simple.
Rules: ask follow-up questions (crop, age/stage, height, symptoms, irrigation, weather) when data is insufficient.
Give likely causes and next steps, not certainty. Never present unverified claims as facts.
Do not give exact pesticide/chemical doses; advise following the product label and local regulations.
For price or demand questions, say you rely only on listings on the platform and be open when data is insufficient.`;

export async function POST(req: NextRequest) {
  const token = req.headers.get("authorization")?.replace("Bearer ", "");
  if (!token) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const sb = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { global: { headers: { Authorization: `Bearer ${token}` } } });
  const { data: { user } } = await sb.auth.getUser(token);
  if (!user) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const since = new Date(); since.setHours(0, 0, 0, 0);
  const { count } = await sb.from("ai_messages").select("id", { count: "exact", head: true })
    .eq("user_id", user.id).eq("role", "user").gte("created_at", since.toISOString());
  if ((count ?? 0) >= 50) return NextResponse.json({ error: "limit" }, { status: 429 });

  const body = await req.json().catch(() => null);
  if (!body || !Array.isArray(body.messages)) return NextResponse.json({ error: "bad" }, { status: 400 });
  const messages = body.messages.slice(-12).map((m: { role: string; content: string }) => ({
    role: m.role === "assistant" ? "assistant" : "user", content: String(m.content).slice(0, 4000) }));
  if (!messages.length || messages[messages.length - 1].role !== "user") return NextResponse.json({ error: "bad" }, { status: 400 });

  const userText = messages[messages.length - 1].content as string;
  const img = body.image;
  if (img && typeof img.data === "string" && /^image\/(jpeg|png|webp)$/.test(img.media_type) && img.data.length < 4_500_000) {
    messages[messages.length - 1].content = [
      { type: "image", source: { type: "base64", media_type: img.media_type, data: img.data } },
      { type: "text", text: userText }];
  }
  try {
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "content-type": "application/json", "x-api-key": process.env.ANTHROPIC_API_KEY!, "anthropic-version": "2023-06-01" },
      body: JSON.stringify({ model: process.env.AI_MODEL || "claude-sonnet-5-5", max_tokens: 800, system: SYSTEM, messages }),
    });
    if (!r.ok) return NextResponse.json({ error: "ai" }, { status: 502 });
    const j = await r.json();
    const text = (j.content ?? []).map((c: { text?: string }) => c.text ?? "").join("").trim();
    await sb.from("ai_messages").insert([
      { user_id: user.id, role: "user", content: userText },
      { user_id: user.id, role: "assistant", content: text }]);
    return NextResponse.json({ text });
  } catch {
    return NextResponse.json({ error: "ai" }, { status: 502 });
  }
}
