"use client";

import { LogOut } from "lucide-react";
import { useAuth } from "@/lib/auth";
import { Button } from "@/components/ui/button";
import { ThemeToggle } from "@/components/shared/theme-toggle";

export function Header() {
  const { user, signOut } = useAuth();

  return (
    <header className="flex h-14 items-center justify-between border-b border-border bg-card px-4 sm:px-6">
      <p className="text-sm text-muted-foreground">
        Moderación de plataforma
      </p>
      <div className="flex items-center gap-3">
        {user ? (
          <div className="text-right">
            <p className="text-sm font-medium text-foreground">
              {user.name ?? user.email}
            </p>
            <p className="text-xs text-muted-foreground">{user.email}</p>
          </div>
        ) : null}
        <ThemeToggle />
        <Button
          variant="outline"
          size="sm"
          onClick={() => void signOut()}
          aria-label="Cerrar sesión"
        >
          <LogOut className="h-3.5 w-3.5" />
          Salir
        </Button>
      </div>
    </header>
  );
}
