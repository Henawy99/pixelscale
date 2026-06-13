'use client';

import { use, useState, useEffect, useRef } from "react";
import Link from "next/link";
import { Logo } from "@/components/Logo";
import SignaturePad from "@/components/SignaturePad";
import {
  ArrowLeft,
  Banknote,
  Dice5,
  Smartphone,
  ShieldCheck,
  CheckCircle2,
  Lock,
  Upload,
  X,
  ChevronDown,
  Check,
} from "lucide-react";

type CaseConfig = {
  slug: string;
  title: string;
  headline: string;
  intro: string;
  longIntro: string[];
  icon: typeof Banknote;
  providerLabel: string;
  providerOptions: string[];
  secondUploadLabel?: string;
  secondUploadHint?: string;
};

const CASES: Record<string, CaseConfig> = {
  kredit: {
    slug: "kredit",
    title: "Kreditbearbeitungsgebühren zurückfordern",
    headline: "Wir holen deine Bearbeitungsgebühren von Kreditverträgen zurück.",
    intro: "Kostenlos & ohne Risiko – wir prüfen Ihren Kreditvertrag.",
    longIntro: [
      "Vielen Dank für Ihr Interesse an unserer Sammelaktion „Kreditvertragsgebühr“ und für Ihr Vertrauen. Anbei finden Sie die wesentlichen Konditionen unseres Angebots, welches wir gemeinsam mit unserem Prozessfinanzierungspartner organisieren.",
      "Wir führen zurzeit Musterverfahren, um das von Kreditnehmern beim Vertragsabschluss bezahlte Entgelt erfolgreich zurückzufordern. Unsere Partner-Kanzlei kümmert sich um die rechtliche Durchsetzung der Ansprüche. Der Prozessfinanzierer zahlt das Honorar. Wenn Sie über eine Rechtsschutzversicherung verfügen, übernimmt der Prozessfinanzierer einen allfälligen Selbstbehalt sowie alle Kosten, die von der Rechtsschutzversicherung nicht übernommen werden.",
      "Die Anmeldung und das Ausfüllen der Formulare sind unverbindlich und kostenlos. Sie können es sich jederzeit anders überlegen – es entstehen Ihnen keine Kosten.",
      "Wenn ausreichend Erfahrungswerte bzw. entsprechende Erfolgschancen vorliegen, können wir Ihr Verfahren starten. Im Erfolgsfall erhalten Sie 64,5 % des erzielten Erlöses. Der Prozessfinanzierer erhält für die übernommenen Kosten und Risiken 35,5 %. Ohne Ihre ausdrückliche Freigabe wird Ihr Verfahren nicht eingeleitet. Im Falle einer aufrechten Rechtsschutzversicherung reduziert sich die Quote des Prozessfinanzierers um die Hälfte.",
      "Für Sie gibt es keine Risiken oder Kosten – unabhängig davon, ob das Verfahren erfolgreich verläuft oder verloren geht.",
      "Bitte hinterlassen Sie unten Ihre Daten, laden Sie Ihren Ausweis hoch, setzen Sie die entsprechenden Häkchen und unterschreiben Sie. Wir kümmern uns um alles Weitere.",
    ],
    icon: Banknote,
    providerLabel: "Bei welcher Bank oder welchen Banken besteht der Kreditvertrag?",
    providerOptions: [
      "Wüstenrot",
      "BAWAG",
      "Bank Austria",
      "Erste / Sparkasse",
      "Raiffeisen",
      "Oberbank",
      "Santander",
      "Volksbank",
      "Andere",
    ],
    secondUploadLabel: "Kreditvertrag",
    secondUploadHint: "Optional – beschleunigt die Prüfung erheblich.",
  },
  casino: {
    slug: "casino",
    title: "Online-Casino Verluste zurückfordern",
    headline: "Wir holen deine Verluste aus Online-Casinos zurück.",
    intro: "Kostenlos & ohne Risiko – wir prüfen Ihre Ansprüche.",
    longIntro: [
      "Vielen Dank für Ihr Interesse an unserer Sammelaktion „Online-Casino“ und für Ihr Vertrauen. Anbei finden Sie die wesentlichen Konditionen unseres Angebots, welches wir gemeinsam mit unserem Prozessfinanzierungspartner organisieren.",
      "Verluste bei in Österreich nicht-konzessionierten Online-Casinos sind nach ständiger Rechtsprechung des OGH rückforderbar. Unsere Partner-Kanzlei kümmert sich um die rechtliche Durchsetzung. Der Prozessfinanzierer zahlt das Honorar und übernimmt das gesamte Kostenrisiko.",
      "Die Anmeldung und das Ausfüllen der Formulare sind unverbindlich und kostenlos.",
      "Im Erfolgsfall erhalten Sie 64,5 % des erzielten Erlöses. Der Prozessfinanzierer erhält 35,5 %. Bei aufrechter Rechtsschutzversicherung reduziert sich die Quote des Prozessfinanzierers um die Hälfte.",
      "Für Sie gibt es keine Risiken oder Kosten – unabhängig vom Ausgang des Verfahrens.",
      "Bitte hinterlassen Sie unten Ihre Daten, laden Sie Ihren Ausweis hoch und unterschreiben Sie. Wir kümmern uns um alles Weitere.",
    ],
    icon: Dice5,
    providerLabel: "Bei welchen Online-Casinos haben Sie gespielt?",
    providerOptions: [
      "Bet-at-home",
      "Mr Green",
      "Bwin",
      "Tipico",
      "Interwetten",
      "888 Casino",
      "LeoVegas",
      "Andere",
    ],
    secondUploadLabel: "Kontoauszüge / Spielnachweise",
    secondUploadHint: "Optional – beschleunigt die Prüfung erheblich.",
  },
  telekom: {
    slug: "telekom",
    title: "Servicepauschalen zurückholen",
    headline: "Wir holen deine Servicepauschalen aus Verträgen zurück.",
    intro: "Kostenlos & ohne Risiko – wir prüfen Ihre Verträge.",
    longIntro: [
      "Vielen Dank für Ihr Interesse an unserer Sammelaktion „Servicepauschalen“ und für Ihr Vertrauen. Anbei finden Sie die wesentlichen Konditionen unseres Angebots, welches wir gemeinsam mit unserem Prozessfinanzierungspartner organisieren.",
      "Viele Handy-, Internet- und Fitnessverträge enthalten unzulässige Klauseln für jährliche „Servicepauschalen“. Österreichische Gerichte kippen diese Gebühren reihenweise. Unsere Partner-Kanzlei kümmert sich um die rechtliche Durchsetzung. Der Prozessfinanzierer zahlt das Honorar.",
      "Die Anmeldung und das Ausfüllen der Formulare sind unverbindlich und kostenlos.",
      "Im Erfolgsfall erhalten Sie 64,5 % des erzielten Erlöses. Der Prozessfinanzierer erhält 35,5 %. Bei aufrechter Rechtsschutzversicherung reduziert sich die Quote des Prozessfinanzierers um die Hälfte.",
      "Für Sie gibt es keine Risiken oder Kosten – unabhängig vom Ausgang des Verfahrens.",
      "Bitte hinterlassen Sie unten Ihre Daten, laden Sie Ihren Ausweis hoch und unterschreiben Sie. Wir kümmern uns um alles Weitere.",
    ],
    icon: Smartphone,
    providerLabel: "Bei welchem Anbieter besteht der Vertrag?",
    providerOptions: [
      "A1",
      "Magenta",
      "Drei",
      "spusu",
      "HoT",
      "McFit",
      "Fitness First",
      "Clever Fit",
      "Andere",
    ],
    secondUploadLabel: "Vertrag / Rechnungen",
    secondUploadHint: "Optional – beschleunigt die Prüfung erheblich.",
  },
};

interface PageProps {
  params: Promise<{ typ: string }>;
}

export default function AnspruchFormPage({ params }: PageProps) {
  const resolvedParams = use(params);
  const typ = resolvedParams.typ;

  if (!CASES[typ]) {
    return (
      <div className="min-h-screen grid place-content-center text-center px-6">
        <h1 className="text-3xl font-semibold text-ink font-bold">Anspruchstyp nicht gefunden</h1>
        <Link href="/anspruch-pruefen" className="mt-4 text-brand underline">
          Zurück zur Auswahl
        </Link>
      </div>
    );
  }

  const cfg = CASES[typ];
  const Icon = cfg.icon;
  const [submitted, setSubmitted] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [providerOpen, setProviderOpen] = useState(false);
  const [providers, setProviders] = useState<string[]>([]);
  const [ausweis, setAusweis] = useState<File[]>([]);
  const [vertrag, setVertrag] = useState<File[]>([]);
  const [signature, setSignature] = useState("");
  const providerRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (typeof window !== "undefined") {
      const urlParams = new URLSearchParams(window.location.search);
      const urlRef = urlParams.get("ref");
      if (urlRef) {
        localStorage.setItem("kr_ref", urlRef);
      }
    }
  }, []);

  useEffect(() => {
    if (!providerOpen) return;
    function onDown(e: MouseEvent | TouchEvent) {
      if (providerRef.current && !providerRef.current.contains(e.target as Node)) {
        setProviderOpen(false);
      }
    }
    document.addEventListener("mousedown", onDown);
    document.addEventListener("touchstart", onDown);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("touchstart", onDown);
    };
  }, [providerOpen]);

  function toggleProvider(p: string) {
    setProviders((prev) => (prev.includes(p) ? prev.filter((x) => x !== p) : [...prev, p]));
  }

  function handleFiles(setter: (f: File[]) => void, current: File[], files: FileList | null) {
    if (!files) return;
    const next = [...current, ...Array.from(files)].slice(0, 50);
    setter(next);
  }

  const [submitError, setSubmitError] = useState("");

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (ausweis.length === 0) {
      alert("Bitte laden Sie eine Kopie Ihres Ausweises hoch.");
      return;
    }
    if (!signature) {
      alert("Bitte unterschreiben Sie das Formular.");
      return;
    }
    setSubmitting(true);
    setSubmitError("");

    try {
      // Gather form text fields from the native form
      const formEl = e.currentTarget;
      const fd = new FormData();

      fd.append("firstName", (formEl.elements.namedItem("firstName") as HTMLInputElement)?.value || "");
      fd.append("lastName", (formEl.elements.namedItem("lastName") as HTMLInputElement)?.value || "");
      fd.append("email", (formEl.elements.namedItem("email") as HTMLInputElement)?.value || "");
      fd.append("birthdate", (formEl.elements.namedItem("birthdate") as HTMLInputElement)?.value || "");
      fd.append("street", (formEl.elements.namedItem("street") as HTMLInputElement)?.value || "");
      fd.append("zip", (formEl.elements.namedItem("zip") as HTMLInputElement)?.value || "");
      fd.append("city", (formEl.elements.namedItem("city") as HTMLInputElement)?.value || "");
      fd.append("phone", (formEl.elements.namedItem("phone") as HTMLInputElement)?.value || "");
      fd.append("campaign", cfg.slug);

      // Default rechtsschutz to Nein
      fd.append("rechtsschutz", "Nein");

      // Providers (banks/casinos/telcos)
      fd.append("providers", JSON.stringify(providers));

      // Signature (base64)
      fd.append("signature", signature);

      // Confirmation checkboxes
      const checkboxes = formEl.querySelectorAll<HTMLInputElement>('input[type="checkbox"]');
      fd.append("confirmation", String(checkboxes[0]?.checked || false));
      fd.append("newsletter", String(checkboxes[1]?.checked || false));

      // File uploads
      for (const file of ausweis) {
        fd.append("ausweis", file);
      }
      for (const file of vertrag) {
        fd.append("vertrag", file);
      }

      // Partner ref code (if present in URL or localStorage)
      const urlRef = new URLSearchParams(window.location.search).get("ref");
      const storedRef = typeof localStorage !== "undefined" ? localStorage.getItem("kr_ref") : null;
      if (urlRef || storedRef) {
        fd.append("ref", urlRef || storedRef || "");
      }

      const response = await fetch("/api/submit-claim", {
        method: "POST",
        body: fd,
      });

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || "Fehler beim Senden");
      }

      setSubmitted(true);
    } catch (err) {
      console.error("Form submission error:", err);
      setSubmitError(
        err instanceof Error ? err.message : "Ein Fehler ist aufgetreten. Bitte versuchen Sie es erneut."
      );
    } finally {
      setSubmitting(false);
    }
  }

  if (submitted) {
    return (
      <PageShell>
        <div className="mx-auto max-w-2xl px-6 lg:px-10 py-20">
          <div className="rounded-2xl border border-brand/30 bg-card p-10 text-center">
            <CheckCircle2 className="mx-auto size-14 text-brand" />
            <h2 className="mt-5 text-2xl font-semibold text-ink font-bold">Vielen Dank!</h2>
            <p className="mt-3 text-muted-foreground leading-relaxed">
              Ihre Anmeldung wurde an unsere Partner-Kanzlei weitergeleitet. Sie erhalten innerhalb
              von 24 Stunden eine erste Einschätzung per E-Mail.
            </p>
            <Link
              href="/"
              className="mt-7 inline-flex items-center gap-1.5 rounded-full bg-ink text-background px-5 py-2.5 text-sm font-medium hover:bg-brand-deep transition-colors"
            >
              Zur Startseite
            </Link>
          </div>
        </div>
      </PageShell>
    );
  }

  return (
    <PageShell>
      <main className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-10 py-8 sm:py-12 lg:py-16">
        <div className="flex flex-wrap items-center gap-3">
          <div className="grid place-content-center size-12 sm:size-14 rounded-2xl bg-gradient-to-br from-brand to-brand-deep text-white shadow-[0_10px_30px_-10px_oklch(0.58_0.22_255/0.5)] shrink-0">
            <Icon className="size-6 sm:size-7" />
          </div>
          <div className="inline-flex items-center gap-2 rounded-full border border-border bg-card px-3 py-1.5 text-xs font-medium text-muted-foreground">
            <ShieldCheck className="size-3.5 text-brand" />
            Kostenlos &amp; ohne Risiko
          </div>
        </div>

        <h1 className="mt-5 text-2xl sm:text-3xl lg:text-[44px] leading-[1.1] tracking-tight text-ink text-balance font-bold">
          {cfg.headline}
        </h1>
        <p className="mt-3 text-sm sm:text-base text-muted-foreground leading-relaxed">{cfg.intro}</p>

        <form
          onSubmit={handleSubmit}
          className="mt-8 w-full rounded-2xl border border-border bg-card p-4 sm:p-6 lg:p-8 grid gap-5 sm:gap-6 overflow-hidden"
        >
          <Section title="Persönliche Daten">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <Field label="Vorname *" name="firstName" required placeholder="Max" />
              <Field label="Nachname *" name="lastName" required placeholder="Mustermann" />
            </div>
            <Field
              label="E-Mail *"
              name="email"
              type="email"
              required
              placeholder="max@example.at"
            />
            <Field label="Geburtsdatum *" name="birthdate" type="date" required />
            <div className="grid grid-cols-[1fr_100px] sm:grid-cols-[1fr_120px] gap-3 sm:gap-4">
              <Field
                label="Straße und Hausnummer *"
                name="street"
                required
                placeholder="Musterstraße 1"
              />
              <Field label="PLZ *" name="zip" required placeholder="1010" />
            </div>
            <Field label="Ort *" name="city" required placeholder="Wien" />
            <Field
              label="Telefonnummer *"
              name="phone"
              type="tel"
              required
              placeholder="+43 660 1234567"
            />
          </Section>

          <Section title={cfg.providerLabel}>
            <div className="relative" ref={providerRef}>
              <button
                type="button"
                onClick={() => setProviderOpen((v) => !v)}
                className="w-full flex items-center justify-between gap-3 rounded-xl border border-border bg-background px-4 py-3 text-sm text-ink hover:border-brand/60 transition-colors"
              >
                <span className="truncate text-left">
                  {providers.length === 0
                    ? "Bitte auswählen (Mehrfachauswahl möglich)"
                    : providers.join(", ")}
                </span>
                <ChevronDown
                  className={`size-4 shrink-0 text-muted-foreground transition-transform ${
                    providerOpen ? "rotate-180" : ""
                  }`}
                />
              </button>
              {providerOpen && (
                <div className="absolute z-20 mt-2 w-full max-h-72 overflow-auto rounded-xl border border-border bg-card shadow-lg p-1">
                  {cfg.providerOptions.map((p) => {
                    const active = providers.includes(p);
                    return (
                      <button
                        type="button"
                        key={p}
                        onClick={() => toggleProvider(p)}
                        className={`w-full flex items-center justify-between gap-2 rounded-lg px-3 py-2 text-sm text-left transition-colors ${
                          active ? "bg-brand/10 text-ink" : "text-muted-foreground hover:bg-muted/50 hover:text-ink"
                        }`}
                      >
                        <span>{p}</span>
                        {active && <Check className="size-4 text-brand" />}
                      </button>
                    );
                  })}
                </div>
              )}
            </div>
          </Section>

          <Section title="Dokumente hochladen">
            <FileDrop
              label="Ausweis *"
              hint="Vorder- und Rückseite, gut lesbar (JPG, PNG oder PDF, bis 50 Dateien)."
              files={ausweis}
              onAdd={(fl) => handleFiles(setAusweis, ausweis, fl)}
              onRemove={(i) => setAusweis(ausweis.filter((_, idx) => idx !== i))}
            />
            {cfg.secondUploadLabel && (
              <FileDrop
                label={cfg.secondUploadLabel}
                hint={cfg.secondUploadHint ?? ""}
                files={vertrag}
                onAdd={(fl) => handleFiles(setVertrag, vertrag, fl)}
                onRemove={(i) => setVertrag(vertrag.filter((_, idx) => idx !== i))}
              />
            )}
          </Section>

          <Section title="Unterschrift *">
            <SignaturePad onChange={(sig) => setSignature(sig)} />
          </Section>

          <Section title="Bestätigungen">
            <label className="flex items-start gap-3 text-sm text-muted-foreground cursor-pointer">
              <input type="checkbox" required className="mt-1 size-4 accent-brand shrink-0" />
              <span>
                Ich stimme zu, dass meine Daten und Unterlagen zur Bearbeitung meines Falls an
                unsere Partner-Kanzlei und den Prozessfinanzierer weitergeleitet werden. *
              </span>
            </label>

            <label className="flex items-start gap-3 text-sm text-muted-foreground cursor-pointer">
              <input type="checkbox" className="mt-1 size-4 accent-brand shrink-0" />
              <span>
                Ich möchte den Newsletter erhalten und bin mit der Verarbeitung meiner Daten zum
                Versand einverstanden.
              </span>
            </label>
          </Section>

          {submitError && (
            <div className="rounded-xl border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
              <p className="font-medium">Fehler beim Senden</p>
              <p className="mt-1">{submitError}</p>
            </div>
          )}

          <button
            type="submit"
            disabled={submitting}
            className="mt-2 w-full sm:w-auto sm:self-start inline-flex items-center justify-center gap-2 rounded-full bg-brand text-white px-6 py-3.5 text-[15px] font-medium hover:bg-brand-deep transition-colors shadow-[0_8px_24px_-8px_oklch(0.58_0.22_255/0.5)] disabled:opacity-60 cursor-pointer"
          >
            {submitting ? "Wird gesendet …" : "Senden"}
          </button>

          <p className="flex items-center justify-center gap-1.5 text-xs text-muted-foreground text-center">
            <Lock className="size-3 shrink-0" /> Ihre Daten werden vertraulich behandelt und ausschließlich
            zur Bearbeitung Ihres Falls verwendet.
          </p>
        </form>
      </main>
    </PageShell>
  );
}

function PageShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-background text-foreground overflow-x-hidden w-full">
      <header className="sticky top-0 z-50 backdrop-blur-md bg-background/75 border-b border-border/60">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-10 h-14 sm:h-16 flex items-center justify-between">
          <Link href="/" className="group">
            <Logo />
          </Link>
          <Link
            href="/anspruch-pruefen"
            className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-ink px-2 sm:px-3 py-2"
          >
            <ArrowLeft className="size-4" />
            <span className="hidden sm:inline">Andere Auswahl</span>
            <span className="sm:hidden">Zurück</span>
          </Link>
        </div>
      </header>
      {children}
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="grid gap-4 min-w-0">
      <h3 className="text-sm font-semibold text-ink uppercase tracking-wide break-words">{title}</h3>
      <div className="grid gap-4 min-w-0">{children}</div>
    </div>
  );
}

function Field({
  label,
  name,
  type = "text",
  required,
  placeholder,
}: {
  label: string;
  name: string;
  type?: string;
  required?: boolean;
  placeholder?: string;
}) {
  return (
    <div className="grid gap-1.5">
      <label className="text-sm font-medium text-ink">{label}</label>
      <input
        name={name}
        type={type}
        required={required}
        maxLength={200}
        placeholder={placeholder}
        className="w-full h-11 rounded-xl border border-border bg-background px-3 text-base sm:text-sm text-ink focus:outline-none focus:ring-2 focus:ring-brand min-w-0 touch-manipulation"
      />
    </div>
  );
}

function FileDrop({
  label,
  hint,
  files,
  onAdd,
  onRemove,
}: {
  label: string;
  hint: string;
  files: File[];
  onAdd: (fl: FileList | null) => void;
  onRemove: (i: number) => void;
}) {
  const [dragOver, setDragOver] = useState(false);
  return (
    <div className="grid gap-2">
      <label className="text-sm font-medium text-ink">{label}</label>
      <label
        onDragOver={(e) => {
          e.preventDefault();
          setDragOver(true);
        }}
        onDragLeave={() => setDragOver(false)}
        onDrop={(e) => {
          e.preventDefault();
          setDragOver(false);
          onAdd(e.dataTransfer.files);
        }}
        className={`flex flex-col items-center justify-center gap-2 rounded-xl border-2 border-dashed px-4 py-8 text-center cursor-pointer transition-colors ${
          dragOver ? "border-brand bg-brand/5" : "border-border bg-background hover:border-brand/50"
        }`}
      >
        <Upload className="size-6 text-muted-foreground" />
        <div className="text-sm text-ink">
          <span className="font-medium text-brand">Datei wählen</span> oder hierher ziehen
        </div>
        <p className="text-xs text-muted-foreground">{hint}</p>
        <input
          type="file"
          multiple
          accept="image/*,application/pdf"
          className="sr-only"
          onChange={(e) => onAdd(e.currentTarget.files)}
        />
      </label>
      {files.length > 0 && (
        <ul className="grid gap-1.5 list-none p-0">
          {files.map((f, i) => (
            <li
              key={i}
              className="flex items-center justify-between gap-3 rounded-lg border border-border bg-background px-3 py-2 text-sm text-ink"
            >
              <span className="truncate">{f.name}</span>
              <button
                type="button"
                onClick={() => onRemove(i)}
                className="text-muted-foreground hover:text-ink cursor-pointer"
                aria-label="Entfernen"
              >
                <X className="size-4" />
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}



