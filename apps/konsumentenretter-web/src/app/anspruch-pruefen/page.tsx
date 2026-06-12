import Link from "next/link";
import { Logo } from "@/components/Logo";
import { ArrowUpRight, Banknote, Dice5, Smartphone, ShieldCheck, ArrowLeft } from "lucide-react";

export const metadata = {
  title: "Anspruch prüfen – Konsumentenretter",
  description: "Wählen Sie Ihren Anspruch: Kreditbearbeitungsgebühren, Online-Casino Verluste oder Handy- und Internetverträge. Kostenlos & ohne Risiko.",
  openGraph: {
    title: "Anspruch prüfen – Konsumentenretter",
    description: "Drei Wege Ihr Geld zurückzuholen – wählen Sie Ihren Fall. Kostenlos und ohne Prozessrisiko.",
  }
};

const cases = [
  {
    slug: "kredit",
    title: "Kreditbearbeitungsgebühren",
    short: "Bei Kredit- oder Leasingverträgen",
    desc: "Wir holen unzulässig verrechnete Bearbeitungsgebühren aus Ihrem Kredit- oder Leasingvertrag zurück.",
    icon: Banknote,
  },
  {
    slug: "telekom",
    title: "Servicepauschalen & Entgelte",
    short: "Handy- & Internetverträge",
    desc: "Unzulässige Servicepauschalen und überhöhte Entgelte bei A1, Magenta & Co. – wir prüfen Ihren Vertrag kostenlos.",
    icon: Smartphone,
  },
  {
    slug: "casino",
    title: "Online-Casino Verluste",
    short: "Verluste bei nicht-lizenzierten Anbietern",
    desc: "Haben Sie in Österreich bei einem nicht-konzessionierten Online-Casino verloren? Diese Verluste sind rückforderbar.",
    icon: Dice5,
  },
] as const;

export default function AnspruchAuswahl() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="sticky top-0 z-50 backdrop-blur-md bg-background/75 border-b border-border/60">
        <div className="mx-auto max-w-7xl px-6 lg:px-10 h-18 flex items-center justify-between py-4">
          <Link href="/" className="group">
            <Logo />
          </Link>
          <Link
            href="/"
            className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-ink px-3 py-2"
          >
            <ArrowLeft className="size-4" /> Zur Startseite
          </Link>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-6 lg:px-10 py-16 lg:py-24">
        <div className="max-w-3xl">
          <div className="inline-flex items-center gap-2 rounded-full border border-border bg-card px-3 py-1.5 text-xs font-medium text-muted-foreground">
            <ShieldCheck className="size-3.5 text-brand" />
            Kostenlos &amp; ohne Prozessrisiko
          </div>
          <h1 className="mt-6 text-[40px] sm:text-5xl lg:text-6xl leading-[1.05] tracking-tight text-ink text-balance font-bold">
            Welchen <span className="font-serif italic text-brand-deep font-normal">Anspruch</span> möchten Sie prüfen lassen?
          </h1>
          <p className="mt-5 text-lg text-muted-foreground leading-relaxed">
            Wählen Sie Ihren Fall – wir melden uns innerhalb von 24 Stunden mit einer ersten Einschätzung. Alles kostenlos, vertraulich und unverbindlich.
          </p>
        </div>

        <div className="mt-12 grid gap-6 md:grid-cols-3">
          {cases.map((c, i) => {
            const Icon = c.icon;
            return (
              <Link
                key={c.slug}
                href={`/anspruch-pruefen/${c.slug}`}
                className="group relative flex flex-col rounded-2xl border border-border bg-card p-8 hover:border-brand transition-all hover:shadow-[0_20px_50px_-20px_oklch(0.58_0.22_255/0.35)] hover:-translate-y-1"
              >
                <div className="flex items-center justify-between">
                  <div className="grid place-content-center size-14 rounded-2xl bg-gradient-to-br from-brand to-brand-deep text-white shadow-[0_10px_30px_-10px_oklch(0.58_0.22_255/0.5)]">
                    <Icon className="size-7" />
                  </div>
                  <span className="text-xs font-mono text-muted-foreground">0{i + 1}</span>
                </div>
                <h2 className="mt-6 text-xl font-semibold text-ink leading-tight font-bold">{c.title}</h2>
                <p className="mt-1 text-sm text-brand-deep font-medium">{c.short}</p>
                <p className="mt-4 text-sm text-muted-foreground leading-relaxed flex-1">{c.desc}</p>
                <span className="mt-6 inline-flex items-center gap-1.5 text-sm font-medium text-brand group-hover:gap-2.5 transition-all">
                  Anspruch prüfen <ArrowUpRight className="size-4" />
                </span>
              </Link>
            );
          })}
        </div>

        <div className="mt-16 rounded-2xl border border-border bg-secondary/40 p-8 text-sm text-muted-foreground leading-relaxed">
          <strong className="text-ink">Wie geht es weiter?</strong> Sie füllen ein kurzes Formular aus (ca. 1 Minute).
          Unsere Partnerkanzlei prüft Ihren Fall kostenlos und meldet sich mit den nächsten Schritten. Erst wenn wir Geld für Sie zurückholen, fällt eine Erfolgsbeteiligung an – ansonsten haben Sie kein Risiko.
        </div>
      </main>
    </div>
  );
}
