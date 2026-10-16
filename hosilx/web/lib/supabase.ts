import { createClient } from "@supabase/supabase-js";

// Faqat anon kalit: xavfsizlik RLS qoidalari orqali ta'minlanadi.
export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);
