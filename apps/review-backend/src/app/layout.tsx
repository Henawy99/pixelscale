import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Review App – GetYourGuide Tour Review & Visuals Generator',
  description:
    'Paste any GetYourGuide tour link to generate realistic traveler reviews and 3 matching high-quality photos using Google Gemini AI.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-slate-50 text-slate-900 antialiased selection:bg-indigo-100 selection:text-indigo-900">
        {children}
      </body>
    </html>
  );
}
