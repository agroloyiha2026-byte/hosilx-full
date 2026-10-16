import { supabase } from "./supabase";

export async function uploadImage(file: File, uid: string): Promise<string> {
  if (!file.type.startsWith("image/") || file.size > 5 * 1024 * 1024) throw new Error("bad file");
  const ext = (file.name.split(".").pop() || "jpg").toLowerCase().replace(/[^a-z0-9]/g, "") || "jpg";
  const path = `${uid}/${crypto.randomUUID()}.${ext}`;
  const { error } = await supabase.storage.from("images").upload(path, file, { contentType: file.type });
  if (error) throw error;
  return supabase.storage.from("images").getPublicUrl(path).data.publicUrl;
}
