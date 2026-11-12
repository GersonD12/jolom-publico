"use client";

import { useCallback, useEffect, useState } from "react";
import {
  getAppConfigSettings,
  setAppUpdateConfig,
  setCanCreateSalon,
} from "@/lib/api/firestore";
import { formatFirebaseError } from "@/lib/firebase/errors";
import { PageShell } from "@/components/layout/page-shell";
import { ErrorBanner, PageHeader } from "@/components/shared/page-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import type {
  AppPlatformUpdateConfig,
  AppUpdateConfig,
} from "../types";

const EMPTY_UPDATE_CONFIG: AppUpdateConfig = {
  ios: {
    enabled: false,
    requiredVersion: "",
    storeUrl: "",
    releaseNotes: "",
  },
  android: {
    enabled: false,
    requiredVersion: "",
    storeUrl: "",
    releaseNotes: "",
  },
};

type Platform = keyof AppUpdateConfig;

const PLATFORM_LABELS: Record<Platform, string> = {
  ios: "iOS",
  android: "Android",
};

export function AppConfigPage() {
  const [canCreateSalon, setCanCreateSalonState] = useState(false);
  const [appUpdate, setAppUpdate] = useState<AppUpdateConfig>(
    EMPTY_UPDATE_CONFIG,
  );
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setSaved(false);
    setError(null);
    try {
      const settings = await getAppConfigSettings();
      setCanCreateSalonState(settings.canCreateSalon);
      setAppUpdate(settings.appUpdate);
    } catch (e) {
      setError(formatFirebaseError(e, "Error al cargar la configuración"));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const timer = window.setTimeout(() => void load(), 0);
    return () => window.clearTimeout(timer);
  }, [load]);

  const handleSalonToggle = async (next: boolean) => {
    const previous = canCreateSalon;
    setCanCreateSalonState(next);
    setBusy(true);
    setSaved(false);
    setError(null);
    try {
      await setCanCreateSalon(next);
    } catch (e) {
      setCanCreateSalonState(previous);
      setError(
        formatFirebaseError(
          e,
          "No se pudo actualizar el acceso a crear peluquerías",
        ),
      );
    } finally {
      setBusy(false);
    }
  };

  const updatePlatform = <K extends keyof AppPlatformUpdateConfig>(
    platform: Platform,
    key: K,
    value: AppPlatformUpdateConfig[K],
  ) => {
    setSaved(false);
    setAppUpdate((current) => ({
      ...current,
      [platform]: { ...current[platform], [key]: value },
    }));
  };

  const validateUpdateConfig = () => {
    for (const platform of ["ios", "android"] as const) {
      const config = appUpdate[platform];
      if (!config.enabled) continue;
      if (!/^\d+(\.\d+)*$/.test(config.requiredVersion.trim())) {
        return `Ingresa una versión válida para ${PLATFORM_LABELS[platform]} (por ejemplo, 1.2.0).`;
      }
      try {
        const url = new URL(config.storeUrl.trim());
        if (url.protocol !== "https:") throw new Error("invalid protocol");
      } catch {
        return `Ingresa un enlace https válido de la tienda para ${PLATFORM_LABELS[platform]}.`;
      }
    }
    return null;
  };

  const handleSaveUpdates = async () => {
    const validationError = validateUpdateConfig();
    if (validationError) {
      setError(validationError);
      return;
    }

    setBusy(true);
    setSaved(false);
    setError(null);
    try {
      const normalized: AppUpdateConfig = {
        ios: normalizePlatform(appUpdate.ios),
        android: normalizePlatform(appUpdate.android),
      };
      await setAppUpdateConfig(normalized);
      setAppUpdate(normalized);
      setSaved(true);
    } catch (e) {
      setError(
        formatFirebaseError(e, "No se pudo guardar la política de versiones"),
      );
    } finally {
      setBusy(false);
    }
  };

  return (
    <PageShell>
      <PageHeader
        title="Configuración"
        description="Controla funciones globales y las versiones obligatorias de Jolom."
        actions={
          <Button
            variant="outline"
            onClick={() => void load()}
            disabled={loading || busy}
          >
            Actualizar
          </Button>
        }
      />
      {error ? (
        <ErrorBanner message={error} onDismiss={() => setError(null)} />
      ) : null}

      {loading ? (
        <div className="space-y-4">
          <Skeleton className="h-24 w-full max-w-2xl" />
          <Skeleton className="h-96 w-full" />
        </div>
      ) : (
        <div className="space-y-6">
          <section className="max-w-2xl rounded-lg border border-border bg-card p-4">
            <div className="flex items-start justify-between gap-4">
              <div className="min-w-0 space-y-1">
                <div className="flex flex-wrap items-center gap-2">
                  <h2 className="text-sm font-medium text-foreground">
                    Permitir crear peluquerías
                  </h2>
                  <Badge variant={canCreateSalon ? "celadon" : "amber"}>
                    {canCreateSalon ? "Activo" : "Desactivado"}
                  </Badge>
                </div>
                <p className="text-sm text-muted-foreground">
                  Habilita la UI y el callable createSalon para todos los usuarios.
                </p>
              </div>
              <Switch
                checked={canCreateSalon}
                onCheckedChange={(next) => void handleSalonToggle(next)}
                disabled={busy}
                aria-label="Permitir crear peluquerías"
              />
            </div>
          </section>

          <section className="space-y-4 rounded-lg border border-border bg-card p-5">
            <div className="space-y-1">
              <div className="flex flex-wrap items-center gap-2">
                <h2 className="text-base font-semibold text-foreground">
                  Actualización obligatoria
                </h2>
                <Badge variant="amber">Bloqueo global</Badge>
              </div>
              <p className="max-w-3xl text-sm text-muted-foreground">
                Al activar una plataforma, las instalaciones anteriores a la versión
                indicada no podrán usar la app hasta actualizarla.
              </p>
            </div>

            <div className="grid gap-4 xl:grid-cols-2">
              {(["ios", "android"] as const).map((platform) => (
                <PlatformUpdateCard
                  key={platform}
                  platform={platform}
                  config={appUpdate[platform]}
                  disabled={busy}
                  onChange={(key, value) =>
                    updatePlatform(platform, key, value)
                  }
                />
              ))}
            </div>

            <div className="flex flex-wrap items-center justify-end gap-3 border-t border-border pt-4">
              {saved ? (
                <span className="text-sm font-medium text-celadon">
                  Política guardada
                </span>
              ) : null}
              <Button onClick={() => void handleSaveUpdates()} disabled={busy}>
                {busy ? "Guardando…" : "Guardar versiones"}
              </Button>
            </div>
          </section>
        </div>
      )}
    </PageShell>
  );
}

function PlatformUpdateCard({
  platform,
  config,
  disabled,
  onChange,
}: {
  platform: Platform;
  config: AppPlatformUpdateConfig;
  disabled: boolean;
  onChange: <K extends keyof AppPlatformUpdateConfig>(
    key: K,
    value: AppPlatformUpdateConfig[K],
  ) => void;
}) {
  const label = PLATFORM_LABELS[platform];
  return (
    <div className="space-y-5 rounded-lg border border-border bg-background p-4">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h3 className="font-semibold text-foreground">{label}</h3>
          <p className="text-xs text-muted-foreground">
            Configuración exclusiva para {label}.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Badge variant={config.enabled ? "amber" : "default"}>
            {config.enabled ? "Obligatoria" : "Inactiva"}
          </Badge>
          <Switch
            checked={config.enabled}
            onCheckedChange={(next) => onChange("enabled", next)}
            disabled={disabled}
            aria-label={`Activar actualización obligatoria en ${label}`}
          />
        </div>
      </div>

      <div className="space-y-2">
        <Label htmlFor={`${platform}-version`}>Versión requerida</Label>
        <Input
          id={`${platform}-version`}
          value={config.requiredVersion}
          onChange={(event) => onChange("requiredVersion", event.target.value)}
          placeholder="1.2.0"
          disabled={disabled}
          inputMode="numeric"
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor={`${platform}-store`}>Enlace de la tienda</Label>
        <Input
          id={`${platform}-store`}
          type="url"
          value={config.storeUrl}
          onChange={(event) => onChange("storeUrl", event.target.value)}
          placeholder={
            platform === "ios"
              ? "https://apps.apple.com/app/..."
              : "https://play.google.com/store/apps/details?id=..."
          }
          disabled={disabled}
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor={`${platform}-notes`}>Novedades</Label>
        <Textarea
          id={`${platform}-notes`}
          value={config.releaseNotes}
          onChange={(event) => onChange("releaseNotes", event.target.value)}
          placeholder="Describe las mejoras y cambios principales de esta versión."
          rows={5}
          disabled={disabled}
        />
        <p className="text-xs text-muted-foreground">
          Este texto aparecerá en la pantalla que bloquea la app.
        </p>
      </div>
    </div>
  );
}

function normalizePlatform(
  config: AppPlatformUpdateConfig,
): AppPlatformUpdateConfig {
  return {
    ...config,
    requiredVersion: config.requiredVersion.trim(),
    storeUrl: config.storeUrl.trim(),
    releaseNotes: config.releaseNotes.trim(),
  };
}
