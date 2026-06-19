import type { Metadata } from "next";
import "./globals.css";
import AuthGuard from "@/components/AuthGuard";

export const metadata: Metadata = {
  title: "Konsumentenretter – Partner Portal",
  description: "Vertriebspartner Portal für Konsumentenretter",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="de">
      <body>
        <AuthGuard>{children}</AuthGuard>
      </body>
    </html>
  );
}
