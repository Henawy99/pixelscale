import type { Metadata, Viewport } from "next";
import "./globals.css";

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
};

export const metadata: Metadata = {
  title: "Konsumentenretter – Wir holen Ihr Geld zurück",
  description: "Kostenlos & ohne Risiko: Rückforderung von Bearbeitungsgebühren, Servicepauschalen und Online-Casino Verlusten in Österreich.",
  keywords: "Konsumentenretter, Bearbeitungsgebühren, Servicepauschalen, Online Casino, Geld zurück, Österreich",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="de">
      <body>{children}</body>
    </html>
  );
}
