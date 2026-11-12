import type { ReactNode } from "react";
import { cn } from "@/lib/utils/cn";

type PageShellProps = {
  children: ReactNode;
  className?: string;
};

export function PageShell({ children, className }: PageShellProps) {
  return (
    <div className={cn("mx-auto w-full max-w-6xl p-4 sm:p-6", className)}>
      {children}
    </div>
  );
}
