import type { ReactNode } from "react";
import Link from "next/link";
import { cn } from "@/lib/utils/cn";

type StatCardProps = {
  label: string;
  value: string | number;
  hint?: string;
  tone?: "default" | "amber" | "celadon" | "destructive";
  href?: string;
  className?: string;
};

const toneClass: Record<NonNullable<StatCardProps["tone"]>, string> = {
  default: "border-border",
  amber: "border-amber/30 bg-amber-soft/30",
  celadon: "border-celadon/30 bg-celadon-soft/30",
  destructive: "border-destructive/30 bg-destructive-soft/40",
};

export function StatCard({
  label,
  value,
  hint,
  tone = "default",
  href,
  className,
}: StatCardProps) {
  const content = (
    <>
      <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
        {label}
      </p>
      <p className="mt-2 text-3xl font-semibold tabular-nums text-foreground">
        {value}
      </p>
      {hint ? (
        <p className="mt-1 text-xs text-muted-foreground">{hint}</p>
      ) : null}
    </>
  );

  const classes = cn(
    "rounded-lg border bg-card p-4 transition-colors",
    toneClass[tone],
    href && "hover:border-bondi focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
    className,
  );

  if (href) {
    return (
      <Link href={href} className={classes}>
        {content}
      </Link>
    );
  }

  return <div className={classes}>{content}</div>;
}

type PageHeaderProps = {
  title: string;
  description?: string;
  actions?: ReactNode;
  className?: string;
};

export function PageHeader({
  title,
  description,
  actions,
  className,
}: PageHeaderProps) {
  return (
    <div
      className={cn(
        "mb-6 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between",
        className,
      )}
    >
      <div>
        <h1 className="text-2xl font-semibold tracking-tight text-foreground">
          {title}
        </h1>
        {description ? (
          <p className="mt-1 text-sm text-muted-foreground">{description}</p>
        ) : null}
      </div>
      {actions ? <div className="flex flex-wrap gap-2">{actions}</div> : null}
    </div>
  );
}

type ErrorBannerProps = {
  message: string;
  onDismiss?: () => void;
};

function localizeErrorMessage(message: string): string {
  if (
    message.includes("Missing or insufficient permissions") ||
    message === "permission-denied"
  ) {
    return "Sin permisos de Firestore. Verifica el claim role=admin y las reglas de seguridad.";
  }
  return message;
}

export function ErrorBanner({ message, onDismiss }: ErrorBannerProps) {
  return (
    <div
      role="alert"
      className="mb-4 flex items-start justify-between gap-3 rounded-md border border-destructive/30 bg-destructive-soft px-3 py-2 text-sm text-destructive"
    >
      <p>{localizeErrorMessage(message)}</p>
      {onDismiss ? (
        <button
          type="button"
          className="shrink-0 font-medium underline-offset-2 hover:underline"
          onClick={onDismiss}
        >
          Cerrar
        </button>
      ) : null}
    </div>
  );
}
