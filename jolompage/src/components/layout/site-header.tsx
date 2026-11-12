import Link from "next/link";
import { BrandLogo } from "@/components/brand-logo";
import { nav } from "@/content/site";

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-50 border-b border-outline/20 bg-background/80 backdrop-blur-md">
      <div className="mx-auto flex h-16 w-full max-w-6xl items-center justify-between gap-4 px-6">
        <Link
          href="/#inicio"
          className="flex shrink-0 items-center gap-2.5 font-semibold tracking-tight text-foreground"
        >
          <BrandLogo size={32} priority />
          <span>Jolom</span>
        </Link>

        <nav aria-label="Principal" className="hidden items-center gap-8 md:flex">
          {nav.map((item) => (
            <a
              key={item.href}
              href={item.href}
              className="text-sm text-muted transition-colors hover:text-foreground"
            >
              {item.label}
            </a>
          ))}
        </nav>

        <Link
          href="/#descargar"
          className="rounded-full bg-primary px-4 py-2 text-sm font-medium text-on-primary transition-opacity hover:opacity-90"
        >
          Descargar la app
        </Link>
      </div>
    </header>
  );
}
