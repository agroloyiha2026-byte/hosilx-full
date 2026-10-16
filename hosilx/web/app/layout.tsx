import "./globals.css";
import type { Metadata } from "next";
import Providers from "@/components/Providers";

export const metadata: Metadata = {
  title: "Hosil X — agroplatforma",
  description: "Fermerlar, xaridorlar va omborlar uchun yagona agroplatforma.",
};

// Sahifa chizilishidan oldin saqlangan mavzuni qo'llaydi (miltillashsiz)
const themeScript = `try{var t=localStorage.getItem('hx-theme');
if(!t){t=matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light'}
document.documentElement.dataset.theme=t;
var l=localStorage.getItem('hx-lang');if(l)document.documentElement.lang=l}catch(e){}`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="uz" suppressHydrationWarning>
      <head><script dangerouslySetInnerHTML={{ __html: themeScript }} /></head>
      <body><Providers>{children}</Providers></body>
    </html>
  );
}
