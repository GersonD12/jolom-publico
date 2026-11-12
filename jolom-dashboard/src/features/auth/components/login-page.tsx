"use client";

import { useEffect } from "react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth";
import { Button } from "@/components/ui/button";
import { ErrorBanner } from "@/components/shared/page-header";
import { ThemeToggle } from "@/components/shared/theme-toggle";

export function LoginPage() {
  const { user, loading, error, signInWithGoogle, clearError } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading && user) {
      router.replace("/resumen");
    }
  }, [loading, user, router]);

  return (
    <main className="relative flex min-h-screen items-center justify-center bg-background px-4">
      <div className="absolute right-4 top-4">
        <ThemeToggle />
      </div>
      <div className="w-full max-w-md rounded-lg border border-border bg-card p-8 shadow-sm">
        <div className="flex items-center gap-3">
          <Image
            src="/icons/icon-192.png"
            alt="Jolom"
            width={40}
            height={40}
            className="size-10 shrink-0"
            priority
          />
          <p className="text-sm font-medium text-bondi">Jolom</p>
        </div>
        <h1 className="mt-3 text-2xl font-semibold text-foreground">
          Moderación
        </h1>
        <p className="mt-2 text-sm text-muted-foreground">
          Acceso exclusivo para administradores de la plataforma. Inicia sesión
          con Google. Tu cuenta debe tener el claim{" "}
          <code className="rounded bg-secondary px-1 text-xs">role=admin</code>.
        </p>

        {error ? (
          <div className="mt-4">
            <ErrorBanner message={error} onDismiss={clearError} />
          </div>
        ) : null}

        <Button
          className="mt-6 w-full"
          size="lg"
          onClick={() => void signInWithGoogle()}
          disabled={loading}
        >
          {loading ? "Cargando…" : "Continuar con Google"}
        </Button>
      </div>
    </main>
  );
}
