import Link from "next/link";
import { BrandLogo } from "@/components/brand-logo";
import { footerNav, site } from "@/content/site";

export function SiteFooter() {
  const year = new Date().getFullYear();

  return (
    <footer className="border-t border-outline/20 bg-background">
      <div className="mx-auto grid w-full max-w-6xl gap-10 px-6 py-14 sm:grid-cols-2 lg:grid-cols-3">
        <div className="flex flex-col gap-4">
          <Link href="/#inicio" className="flex w-fit items-center gap-2.5">
            <BrandLogo size={28} />
            <span className="font-semibold tracking-tight">{site.name}</span>
          </Link>
          <p className="max-w-xs text-sm text-muted text-pretty">
            {site.description}
          </p>
          <p className="text-sm text-muted">
            © {year} {site.name}
          </p>
        </div>

        {footerNav.support.length > 0 && (
          <div>
            <p className="text-sm font-medium text-foreground">Contacto</p>
            <ul className="mt-4 space-y-2">
              {footerNav.support.map((item) => (
                <li key={item.label}>
                  <a
                    href={item.href}
                    className="text-sm text-muted transition-colors hover:text-foreground"
                  >
                    {item.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        )}

        <div>
          <p className="text-sm font-medium text-foreground">Legal</p>
          <ul className="mt-4 space-y-2">
            {footerNav.legal.map((item) => (
              <li key={item.label}>
                <a
                  href={item.href}
                  className="text-sm text-muted transition-colors hover:text-foreground"
                >
                  {item.label}
                </a>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </footer>
  );
}
