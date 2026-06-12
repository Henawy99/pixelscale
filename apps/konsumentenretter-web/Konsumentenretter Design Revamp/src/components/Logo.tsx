type LogoMarkProps = {
  className?: string;
  size?: number;
};

/**
 * Konsumentenretter — futuristic shield mark.
 * Pure SVG: crisp at any size, themable via currentColor + brand tokens.
 */
export function LogoMark({ className, size = 36 }: LogoMarkProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 48 48"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={`animate-logo-reveal ${className ?? ""}`}
      aria-hidden="true"
    >
      <defs>
        <linearGradient id="kr-shield" x1="6" y1="3" x2="42" y2="45" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="oklch(0.62 0.22 255)" />
          <stop offset="0.55" stopColor="oklch(0.42 0.18 260)" />
          <stop offset="1" stopColor="oklch(0.22 0.10 262)" />
        </linearGradient>
        <linearGradient id="kr-edge" x1="24" y1="3" x2="24" y2="45" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="oklch(0.95 0.04 250 / 0.9)" />
          <stop offset="1" stopColor="oklch(0.62 0.22 255 / 0)" />
        </linearGradient>
        <linearGradient id="kr-spark" x1="16" y1="14" x2="32" y2="34" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="oklch(0.99 0.03 250)" />
          <stop offset="1" stopColor="oklch(0.82 0.18 255)" />
        </linearGradient>
      </defs>

      {/* Shield body */}
      <path
        d="M24 3.5 6.5 9.2v13.4c0 9.3 6.6 17.7 17.5 22.4 10.9-4.7 17.5-13.1 17.5-22.4V9.2L24 3.5Z"
        fill="url(#kr-shield)"
      />

      {/* Inner faceted plate */}
      <path
        d="M24 8.2 10.7 12.5v9.8c0 7.5 5.2 14.3 13.3 18.3 8.1-4 13.3-10.8 13.3-18.3v-9.8L24 8.2Z"
        fill="oklch(0.16 0.05 258)"
        fillOpacity="0.35"
      />

      {/* Top-edge highlight */}
      <path
        d="M24 3.5 6.5 9.2v3.1L24 6.6l17.5 5.7V9.2L24 3.5Z"
        fill="url(#kr-edge)"
        opacity="0.9"
      />

      {/* Futuristic K / spark — geometric chevron */}
      <path
        d="M19 17.5h3.4v6.1l5.6-6.1h4.2l-6.4 6.9 6.8 9.1h-4.4l-4.9-6.7-.9 1v5.7H19V17.5Z"
        fill="url(#kr-spark)"
      />

      {/* Hairline circuit accent */}
      <path
        d="M14.5 22.5h2.6M30.9 22.5h2.6M14.5 29h2.6M30.9 29h2.6"
        stroke="oklch(0.85 0.12 250 / 0.55)"
        strokeWidth="0.8"
        strokeLinecap="round"
      />

      {/* Outer rim glow */}
      <path
        d="M24 3.5 6.5 9.2v13.4c0 9.3 6.6 17.7 17.5 22.4 10.9-4.7 17.5-13.1 17.5-22.4V9.2L24 3.5Z"
        stroke="oklch(0.7 0.18 255 / 0.5)"
        strokeWidth="0.6"
      />
    </svg>
  );
}

export function Logo({ className = "" }: { className?: string }) {
  return (
    <span className={`inline-flex items-center gap-2.5 ${className}`}>
      <LogoMark size={34} />
      <span className="text-[17px] tracking-tight font-semibold text-ink leading-none">
        Konsumenten<span className="text-brand">retter</span>
      </span>
    </span>
  );
}
