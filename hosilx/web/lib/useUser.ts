"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "./supabase";

export type Profile = { id: string; full_name: string; role: string; language: string };

export function useUser() {
  const router = useRouter();
  const [profile, setProfile] = useState<Profile | null>(null);
  useEffect(() => {
    (async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) { router.replace("/login"); return; }
      const { data } = await supabase.from("profiles")
        .select("id,full_name,role,language").eq("id", user.id).single();
      setProfile(data as Profile);
    })();
  }, [router]);
  return { profile };
}
