import Link from "next/link";
import Image from "next/image";
import heroImg from "@/assets/hero-justice.jpg";
import person1 from "@/assets/person-1.jpg";
import person2 from "@/assets/person-2.jpg";
import person3 from "@/assets/person-3.jpg";
import step1Img from "@/assets/step-1.png";
import step2Img from "@/assets/step-2.png";
import step3Img from "@/assets/step-3.png";
import step4Img from "@/assets/step-4.png";
import serviceKreditImg from "@/assets/service-kredit.jpg";
import serviceKontoImg from "@/assets/service-konto.jpg";
import serviceCasinoImg from "@/assets/service-casino.jpg";
import { Logo } from "@/components/Logo";
import {
  ArrowUpRight,
  ShieldCheck,
  Scale,
  Banknote,
  Dice5,
  CheckCircle2,
  FileText,
  Handshake,
  Sparkles,
  Star,
} from "lucide-react";

export const metadata = {
  title: "Konsumentenretter – Wir holen Ihr Geld zurück",
  description: "Kreditgebühren, Servicepauschalen und Online-Casino Verluste in Österreich kostenlos und ohne Risiko zurückfordern.",
  openGraph: {
    title: "Konsumentenretter – Ihr Geld. Zurück.",
    description: "Als Konsument in Österreich haben Sie Ansprüche. Wir setzen sie durch – kostenlos und ohne Risiko.",
  }
};

export default function Home() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <Nav />
      <main>
        <Hero />
        <Trust />
        <Services />
        <Process />
        <Why />
        <FinalCTA />
      </main>
      <Footer />
    </div>
  );
}

/* ------------------------- NAV ------------------------- */

function Nav() {
  const links = [
    { href: "/anspruch-pruefen/kredit", label: "Kreditgebühren" },
    { href: "/anspruch-pruefen/telekom", label: "Servicepauschalen" },
    { href: "/anspruch-pruefen/casino", label: "Online Casino" },
    { href: "#ablauf", label: "Ablauf" },
  ];
  return (
    <header className="sticky top-0 z-50 backdrop-blur-md bg-background/75 border-b border-border/60">
      <div className="mx-auto max-w-7xl px-6 lg:px-10 h-18 flex items-center justify-between py-4">
        <Link href="/" className="group">
          <Logo />
        </Link>
        <nav className="hidden md:flex items-center gap-8 text-sm text-muted-foreground">
          {links.map((l) => (
            <Link
              key={l.label}
              href={l.href}
              className="hover:text-ink transition-colors"
            >
              {l.label}
            </Link>
          ))}
        </nav>
        <div className="flex items-center gap-2">
          <Link
            href="/impressum"
            className="hidden sm:inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-ink px-3 py-2"
          >
            Impressum
          </Link>
          <Link
            href="/anspruch-pruefen"
            className="inline-flex items-center gap-1.5 rounded-full bg-ink text-background px-4 py-2.5 text-sm font-medium hover:bg-brand-deep transition-colors"
          >
            Anspruch prüfen <ArrowUpRight className="size-4" />
          </Link>
        </div>
      </div>
    </header>
  );
}

/* ------------------------- HERO ------------------------- */

function Hero() {
  return (
    <section className="relative">
      <div className="mx-auto max-w-7xl px-6 lg:px-10 pt-10 lg:pt-16 pb-20 lg:pb-28 grid lg:grid-cols-12 gap-10 lg:gap-14 items-center">
        <div className="lg:col-span-7">
          <div className="inline-flex items-center gap-2 rounded-full border border-border bg-card px-3 py-1.5 text-xs font-medium text-muted-foreground">
            <span className="size-1.5 rounded-full bg-brand animate-pulse" />
            Kostenlos & ohne Prozessrisiko · Österreichweit
          </div>
          <h1 className="mt-6 text-[44px] sm:text-6xl lg:text-7xl leading-[1.02] tracking-tight text-ink text-balance font-bold">
            Ihr Geld.{" "}
            <span className="font-serif italic text-brand-deep font-normal">Zurück</span> –
            <br className="hidden sm:block" /> wo es Ihnen{" "}
            <span className="font-serif italic font-normal">zusteht</span>.
          </h1>
          <p className="mt-6 max-w-xl text-lg text-muted-foreground leading-relaxed">
            Unzulässige Kreditgebühren, überhöhte Servicepauschalen oder Verluste bei
            nicht-lizenzierten Online-Casinos? Als Konsument in Österreich haben Sie
            Ansprüche – wir setzen sie für Sie durch.
          </p>
          <div className="mt-9 flex flex-wrap items-center gap-3">
            <Link
              href="/anspruch-pruefen"
              className="inline-flex items-center gap-2 rounded-full bg-brand text-white px-6 py-3.5 text-[15px] font-medium hover:bg-brand-deep transition-colors shadow-[0_8px_24px_-8px_oklch(0.58_0.22_255/0.5)]"
            >
              Jetzt Anspruch prüfen
              <ArrowUpRight className="size-4.5" />
            </Link>
            <a
              href="#ablauf"
              className="inline-flex items-center gap-2 rounded-full border border-border bg-card px-6 py-3.5 text-[15px] font-medium text-ink hover:bg-secondary transition-colors"
            >
              So funktioniert es
            </a>
          </div>

          <div className="mt-12 flex items-center gap-5">
            <div className="flex -space-x-2">
              {[person1, person2, person3].map((src, i) => (
                <Image
                  key={i}
                  src={src}
                  alt="Zufriedener Mandant"
                  loading="lazy"
                  width={36}
                  height={36}
                  className="size-9 rounded-full ring-2 ring-background object-cover"
                />
              ))}
            </div>
            <div>
              <div className="flex items-center gap-1 text-amber-500">
                {Array.from({ length: 5 }).map((_, i) => (
                  <Star key={i} className="size-4 fill-current" />
                ))}
                <span className="ml-2 text-sm font-medium text-ink">4.9 / 5.0</span>
              </div>
              <p className="text-xs text-muted-foreground mt-0.5">
                Hunderte Konsumenten in Österreich vertreten
              </p>
            </div>
          </div>
        </div>

        <div className="lg:col-span-5 relative">
          <div className="relative aspect-[4/5] rounded-3xl overflow-hidden bg-secondary ring-soft">
            <Image
              src={heroImg}
              alt="Justitia mit Waage – Sinnbild für Konsumentenrecht in Österreich"
              className="absolute inset-0 size-full object-cover"
              width={1080}
              height={1350}
              priority
            />
            <div className="absolute inset-0 bg-gradient-to-t from-brand-deep/40 via-transparent to-transparent" />
          </div>

          <div className="absolute -left-6 bottom-8 hidden sm:flex items-center gap-3 rounded-2xl bg-card border border-border px-4 py-3 ring-soft">
            <div className="grid place-items-center size-10 rounded-xl bg-brand/10 text-brand">
              <ShieldCheck className="size-5" />
            </div>
            <div>
              <div className="text-sm font-semibold text-ink">100 % Erfolgsbasis</div>
              <div className="text-xs text-muted-foreground">Sie zahlen nur bei Erfolg</div>
            </div>
          </div>

          <div className="absolute -right-4 top-10 hidden sm:flex flex-col items-end rounded-2xl bg-ink text-background px-4 py-3 ring-soft">
            <span className="text-[11px] uppercase tracking-widest opacity-60">
              Rückforderung
            </span>
            <span className="font-serif text-3xl leading-none mt-1">€ 3.2 Mio+</span>
            <span className="text-xs opacity-70 mt-1">for our clients</span>
          </div>
        </div>
      </div>
    </section>
  );
}

/* ------------------------- TRUST STRIP ------------------------- */

function Trust() {
  const items = [
    "OGH-konforme Prüfung",
    "Anwaltliche Vertretung",
    "Kein Kostenrisiko",
    "DSGVO-konform",
    "Österreichweit tätig",
  ];
  return (
    <section className="border-y border-border bg-surface">
      <div className="mx-auto max-w-7xl px-6 lg:px-10 py-6 overflow-hidden">
        <div className="flex flex-wrap items-center justify-center gap-x-10 gap-y-3 text-sm text-muted-foreground">
          {items.map((t, i) => (
            <div key={t} className="flex items-center gap-2">
              <CheckCircle2 className="size-4 text-brand" />
              <span>{t}</span>
              {i < items.length - 1 && (
                <span className="hidden md:inline-block size-1 rounded-full bg-border ml-8" />
              )}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ------------------------- SERVICES ------------------------- */

const services = [
  {
    id: "kreditgebuehren",
    slug: "kredit",
    icon: Banknote,
    image: serviceKreditImg,
    label: "Kreditgebühren",
    title: "Unzulässige Kreditbearbeitungsgebühren",
    body: "Banken haben jahrelang Bearbeitungsgebühren verrechnet, die laut OGH unzulässig sind. Wir prüfen Ihren Kreditvertrag und holen Ihr Geld vollständig zurück.",
    bullet: "Durchschnittlich € 800 – € 3.500 pro Kredit",
  },
  {
    id: "servicepauschalen",
    slug: "telekom",
    icon: FileText,
    image: serviceKontoImg,
    label: "Servicepauschalen",
    title: "Servicepauschalen aus Verträgen zurückholen",
    body: "Viele Handy-, Internet- und Fitnessverträge enthalten jährliche Pauschalen ohne echten Mehrwert. Österreichische Gerichte kippen diese Gebühren reihenweise.",
    bullet: "Rückforderung der gesamten Pauschalen",
  },
  {
    id: "online-casino",
    slug: "casino",
    icon: Dice5,
    image: serviceCasinoImg,
    label: "Online Casino",
    title: "Verluste in nicht-lizenzierten Online-Casinos",
    body: "Glücksspiel ohne österreichische Lizenz ist rechtlich nichtig. Verluste der letzten 30 Jahre können in voller Höhe von den Anbietern zurückgefordert werden.",
    bullet: "Bis zu 100 % Rückerstattung der Verluste",
  },
];

function Services() {
  return (
    <section className="py-24 lg:py-32">
      <div className="mx-auto max-w-7xl px-6 lg:px-10">
        <div className="flex items-end justify-between gap-10 flex-wrap mb-14">
          <div className="max-w-2xl">
            <SectionLabel>Aktuelle Verfahren</SectionLabel>
            <h2 className="mt-4 text-4xl lg:text-5xl tracking-tight text-ink text-balance font-bold">
              Drei Bereiche, in denen wir{" "}
              <span className="font-serif italic font-normal text-brand-deep">Ihr Recht</span> durchsetzen.
            </h2>
          </div>
          <p className="max-w-md text-muted-foreground">
            Wir prüfen kostenlos, ob Sie Ansprüche haben – und übernehmen die
            gesamte rechtliche Abwicklung gemeinsam mit unseren Partneranwälten.
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-5">
          {services.map((s) => (
            <article
              key={s.id}
              id={s.id}
              className="group relative rounded-3xl border border-border bg-card overflow-hidden flex flex-col hover:border-brand/40 hover:-translate-y-0.5 transition-all duration-300"
            >
              <div className="relative aspect-[16/10] overflow-hidden bg-muted">
                <Image
                  src={s.image}
                  alt={s.title}
                  loading="lazy"
                  width={1280}
                  height={768}
                  className="absolute inset-0 size-full object-cover transition-transform duration-700 group-hover:scale-105"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-brand-deep/70 via-brand-deep/15 to-transparent mix-blend-multiply" />
                <div className="absolute inset-0 bg-gradient-to-br from-transparent via-transparent to-brand/25" />
                <span className="absolute top-4 left-4 inline-flex items-center gap-1.5 rounded-full bg-background/90 backdrop-blur px-3 py-1 text-[11px] uppercase tracking-widest text-ink">
                  <s.icon className="size-3.5 text-brand" />
                  {s.label}
                </span>
              </div>
              <div className="p-7 lg:p-8 flex flex-col flex-1">
                <h3 className="text-2xl text-ink leading-snug text-balance font-bold">
                  {s.title}
                </h3>
                <p className="mt-4 text-[15px] text-muted-foreground leading-relaxed flex-1">
                  {s.body}
                </p>
                <div className="mt-7 pt-5 border-t border-border flex items-center gap-2 text-sm text-brand-deep font-medium">
                  <Sparkles className="size-4 text-brand" />
                  {s.bullet}
                </div>
                <Link
                  href={`/anspruch-pruefen/${s.slug}`}
                  className="mt-6 inline-flex items-center justify-between text-sm font-medium text-ink hover:text-brand transition-colors"
                >
                  Anspruch prüfen
                  <ArrowUpRight className="size-4" />
                </Link>
              </div>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ------------------------- PROCESS ------------------------- */

const steps = [
  {
    n: 1,
    img: step1Img,
    title: "Kostenloser Check",
    text: "Sie schildern uns Ihren Fall online in wenigen Minuten. Wir prüfen Ihre Anfrage umgehend und melden uns schnell und zuverlässig mit einer ersten Einschätzung zurück.",
  },
  {
    n: 2,
    img: step2Img,
    title: "Persönliches Gespräch",
    text: "Wir kontaktieren Sie persönlich und besprechen Ihre Rückforderung. Sie entscheiden in Ruhe, ob Sie uns beauftragen möchten – digital, sicher und unkompliziert.",
  },
  {
    n: 3,
    img: step3Img,
    title: "Geld zurückfordern",
    text: "Spezialisierte Kooperationsanwälte setzen Ihre Forderungen durch. Wir übernehmen sämtliche Kosten und tragen das Prozesskostenrisiko für Sie.",
  },
  {
    n: 4,
    img: step4Img,
    title: "Auszahlung erhalten",
    text: "Sobald unsere Anwälte Ihre Ansprüche erfolgreich durchgesetzt haben, wird die Entschädigung direkt auf Ihr Konto überwiesen.",
  },
];

function Process() {
  return (
    <section id="ablauf" className="relative py-24 lg:py-32 bg-background text-ink overflow-hidden">
      <div
        className="absolute inset-0 opacity-40 pointer-events-none"
        style={{
          backgroundImage: "radial-gradient(circle at 1px 1px, rgba(0,0,0,0.06) 1px, transparent 0)",
          backgroundSize: "24px 24px",
        }}
      />
      <div className="mx-auto max-w-7xl px-6 lg:px-10 relative">
        <div className="max-w-3xl mx-auto text-center">
          <SectionLabel className="text-muted-foreground justify-center">Ablauf</SectionLabel>
          <h2 className="mt-4 text-3xl lg:text-5xl tracking-tight text-balance leading-[1.15] font-bold">
            Starten Sie in nur <span className="font-serif italic text-brand font-normal">2 Minuten</span> und reichen Sie Ihr Anliegen{" "}
            <span className="font-semibold">einfach und schnell</span> bei uns ein – ohne Papierkram und Aufwand.
          </h2>
        </div>

        <ol className="mt-16 grid sm:grid-cols-2 lg:grid-cols-4 gap-6 list-none">
          {steps.map((s, i) => (
            <li
              key={s.n}
              className="group relative flex flex-col rounded-3xl bg-white border border-border shadow-sm p-6 lg:p-7 hover:border-brand/30 hover:shadow-md transition-all duration-300"
            >
              {/* Icon panel */}
              <div className="relative aspect-square w-full rounded-2xl bg-gradient-to-br from-muted to-background border border-border flex items-center justify-center overflow-hidden">
                <div className="absolute inset-0 bg-gradient-to-br from-brand/5 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
                <Image
                  src={s.img}
                  alt={s.title}
                  width={512}
                  height={512}
                  loading="lazy"
                  className="relative w-3/4 h-3/4 object-contain drop-shadow-[0_12px_24px_rgba(0,0,0,0.12)] transition-transform duration-500 group-hover:-translate-y-1 group-hover:scale-105"
                />
                {/* connector arrow */}
                {i < steps.length - 1 && (
                  <div className="hidden lg:flex absolute top-1/2 -right-6 -translate-y-1/2 w-12 h-12 items-center justify-center z-10 pointer-events-none">
                    <div className="w-12 h-px bg-gradient-to-r from-brand/40 to-transparent" />
                  </div>
                )}
              </div>

              {/* Step badge */}
              <div className="mt-6 inline-flex self-start items-center gap-2 rounded-full bg-brand/10 border border-brand/20 px-3 py-1">
                <span className="text-[10px] uppercase tracking-[0.2em] text-muted-foreground">Schritt</span>
                <span className="font-serif text-sm text-brand leading-none">{s.n}</span>
              </div>

              <h3 className="mt-4 text-xl lg:text-2xl font-semibold tracking-tight leading-snug">
                {s.title}
              </h3>
              <p className="mt-3 text-sm text-muted-foreground leading-relaxed">
                {s.text}
              </p>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}

/* ------------------------- WHY ------------------------- */

function Why() {
  const points = [
    {
      icon: ShieldCheck,
      title: "Kein Risiko",
      text: "Sie zahlen nur, wenn wir für Sie erfolgreich Geld zurückholen.",
    },
    {
      icon: Handshake,
      title: "Anwaltliche Stärke",
      text: "Wir arbeiten mit erfahrenen österreichischen Rechtsanwaltskanzleien.",
    },
    {
      icon: Scale,
      title: "OGH-Rechtsprechung",
      text: "Unsere Verfahren basieren auf höchstgerichtlicher Judikatur.",
    },
    {
      icon: Sparkles,
      title: "Digitale Abwicklung",
      text: "Alles online – Unterlagen hochladen, Vollmacht digital signieren.",
    },
  ];
  return (
    <section className="py-24 lg:py-32">
      <div className="mx-auto max-w-7xl px-6 lg:px-10 grid lg:grid-cols-12 gap-12">
        <div className="lg:col-span-5">
          <SectionLabel>Warum Konsumentenretter</SectionLabel>
          <h2 className="mt-4 text-4xl lg:text-5xl tracking-tight text-ink text-balance font-bold">
            Wir sind die{" "}
            <span className="font-serif italic font-normal text-brand-deep">leise Stimme</span> an Ihrer Seite –
            mit der nötigen Härte vor Gericht.
          </h2>
          <p className="mt-6 text-muted-foreground">
            Als Verbraucher gegen Banken oder Glücksspielkonzerne antreten? Allein
            kaum machbar. Wir bündeln Ihre Ansprüche mit denen tausender anderer
            Konsumenten – und schaffen so Augenhöhe.
          </p>
        </div>
        <div className="lg:col-span-7 grid sm:grid-cols-2 gap-px bg-border rounded-3xl overflow-hidden border border-border">
          {points.map((p) => (
            <div key={p.title} className="bg-card p-7 lg:p-8 group">
              <div className="relative inline-flex">
                <div
                  className="absolute inset-0 rounded-2xl bg-gradient-to-br from-brand/40 to-brand-deep/30 blur-xl opacity-70 group-hover:opacity-100 transition-opacity"
                  aria-hidden
                />
                <div className="relative grid place-items-center size-14 rounded-2xl bg-gradient-to-br from-brand-deep to-brand text-white shadow-lg shadow-brand-deep/30 ring-1 ring-white/20 group-hover:-translate-y-0.5 transition-transform">
                  <div className="absolute inset-x-2 top-1 h-2 rounded-full bg-white/30 blur-sm" aria-hidden />
                  <p.icon className="size-7 relative" strokeWidth={1.75} />
                </div>
              </div>
              <h3 className="mt-6 text-lg font-semibold text-ink">{p.title}</h3>
              <p className="mt-2 text-sm text-muted-foreground leading-relaxed">
                {p.text}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ------------------------- CTA ------------------------- */

function FinalCTA() {
  return (
    <section id="kontakt" className="pb-24 lg:pb-32">
      <div className="mx-auto max-w-7xl px-6 lg:px-10">
        <div className="relative rounded-[2rem] bg-gradient-to-br from-brand-deep via-brand-deep to-brand p-10 lg:p-16 overflow-hidden">
          <div className="absolute inset-0 bg-grain opacity-20" />
          <div className="relative grid lg:grid-cols-12 gap-10 items-end">
            <div className="lg:col-span-8">
              <p className="text-sm uppercase tracking-widest text-white/60">
                Bereit?
              </p>
              <h2 className="mt-4 text-4xl lg:text-6xl tracking-tight text-white text-balance font-bold">
                Lassen Sie Ihren Anspruch{" "}
                <span className="font-serif italic font-normal text-amber-300">kostenlos prüfen</span>.
              </h2>
              <p className="mt-5 max-w-xl text-white/75">
                Wenige Minuten Aufwand – möglicher Rückerstattungsbetrag im vier-
                bis fünfstelligen Bereich.
              </p>
            </div>
            <div className="lg:col-span-4 flex lg:justify-end">
              <Link
                href="/anspruch-pruefen"
                className="inline-flex items-center gap-2 rounded-full bg-white text-ink px-7 py-4 text-[15px] font-medium hover:bg-amber-300 hover:text-ink transition-colors"
              >
                Jetzt Anspruch prüfen <ArrowUpRight className="size-4.5" />
              </Link>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

/* ------------------------- FOOTER ------------------------- */

function Footer() {
  return (
    <footer className="border-t border-border bg-surface">
      <div className="mx-auto max-w-7xl px-6 lg:px-10 py-14 grid lg:grid-cols-12 gap-10">
        <div className="lg:col-span-5">
          <Logo />
          <p className="mt-5 max-w-sm text-sm text-muted-foreground leading-relaxed">
            Wir setzen Konsumentenrechte in Österreich durch – kostenlos, digital
            und ohne Prozessrisiko für Sie.
          </p>
        </div>

        <div className="lg:col-span-7 grid grid-cols-2 sm:grid-cols-3 gap-8 text-sm">
          <FooterCol
            title="Verfahren"
            links={[
              ["Kreditgebühren", "/anspruch-pruefen/kredit"],
              ["Servicepauschalen", "/anspruch-pruefen/telekom"],
              ["Online Casino", "/anspruch-pruefen/casino"],
            ]}
          />
          <FooterCol
            title="Unternehmen"
            links={[
              ["Ablauf", "#ablauf"],
              ["Kontakt", "#kontakt"],
              ["Impressum", "/impressum"],
            ]}
          />
          <FooterCol
            title="Rechtliches"
            links={[
              ["Datenschutz", "/datenschutz"],
              ["AGB", "/agb"],
              ["Cookies", "/cookies"],
            ]}
          />
        </div>
      </div>
      <div className="border-t border-border">
        <div className="mx-auto max-w-7xl px-6 lg:px-10 py-6 flex flex-wrap items-center justify-between gap-4 text-xs text-muted-foreground">
          <span>© {new Date().getFullYear()} Konsumentenretter. Alle Rechte vorbehalten.</span>
          <span>Made with care in Österreich.</span>
        </div>
      </div>
    </footer>
  );
}

function FooterCol({ title, links }: { title: string; links: [string, string][] }) {
  return (
    <div>
      <h4 className="text-xs uppercase tracking-widest text-ink font-medium">
        {title}
      </h4>
      <ul className="mt-4 space-y-2.5 list-none p-0">
        {links.map(([label, href]) => (
          <li key={label}>
            <Link href={href} className="text-muted-foreground hover:text-ink transition-colors">
              {label}
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}

/* ------------------------- ATOMS ------------------------- */

function SectionLabel({
  children,
  className = "",
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <p
      className={`text-xs uppercase tracking-[0.2em] text-brand font-medium flex items-center ${className}`}
    >
      {children}
    </p>
  );
}
