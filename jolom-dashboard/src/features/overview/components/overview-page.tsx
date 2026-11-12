"use client";

import { useCallback, useEffect, useState } from "react";
import { getOverviewCounts } from "@/lib/api/firestore";
import { PageHeader, ErrorBanner, StatCard } from "@/components/shared/page-header";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { PageShell } from "@/components/layout/page-shell";

type Counts = Awaited<ReturnType<typeof getOverviewCounts>>;

export function OverviewPage() {
  const [counts, setCounts] = useState<Counts | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setCounts(await getOverviewCounts());
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al cargar resumen");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void load();
  }, [load]);

  return (
    <PageShell>
      <PageHeader
        title="Resumen"
        description="Reportes abiertos, sanciones activas y solicitudes de eliminación."
        actions={
          <Button variant="outline" onClick={() => void load()} disabled={loading}>
            Actualizar
          </Button>
        }
      />
      {error ? <ErrorBanner message={error} onDismiss={() => setError(null)} /> : null}

      {loading || !counts ? (
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <Skeleton className="h-28" />
          <Skeleton className="h-28" />
          <Skeleton className="h-28" />
        </div>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <StatCard
            label="Reportes abiertos"
            value={counts.openReports}
            tone="amber"
            href="/reportes"
            hint="Recibidos o en revisión"
          />
          <StatCard
            label="Casos abiertos"
            value={counts.openCases}
            tone="default"
            href="/reportes"
            hint="Casos de moderación sin resolver"
          />
          <StatCard
            label="Cuentas bloqueadas"
            value={counts.blockedUsers}
            tone="destructive"
            href="/usuarios"
            hint="Bloqueo global activo"
          />
          <StatCard
            label="Peluquerías restringidas"
            value={counts.suspendedSalons}
            tone="amber"
            href="/peluquerias"
            hint="Ocultas, suspendidas o eliminadas"
          />
          <StatCard
            label="Solicitudes de eliminación"
            value={counts.deletionRequests}
            tone="destructive"
            href="/eliminaciones"
            hint="Usuarios con deletionRequestedAt"
          />
        </div>
      )}
    </PageShell>
  );
}
