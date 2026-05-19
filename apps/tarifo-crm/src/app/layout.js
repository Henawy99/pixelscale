import './globals.css';

export const metadata = {
  title: 'TARIFO CRM - Vertriebs- & Kundenmanagement',
  description: 'Tarifo CRM Plattform für Strom, Gas, Internet & Prozessfinanzierungsverträge',
};

export default function RootLayout({ children }) {
  return (
    <html lang="de">
      <body>{children}</body>
    </html>
  );
}
