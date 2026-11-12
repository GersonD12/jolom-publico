"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { listAuditLogs, type WithId } from "@/lib/api/firestore";
import { formatTimestamp } from "@/lib/format";
import type { AuditLogDoc } from "@/types/firestore";
import { PageHeader, ErrorBanner } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { PageShell } from "@/components/layout/page-shell";

export function AuditPage() {
  const [rows, setRows] = useState<WithId<AuditLogDoc>[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actor, setActor] = useState("");
  const [entity, setEntity] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setRows(await listAuditLogs(100));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al cargar auditoría");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const filtered = useMemo(() => {
    return rows.filter((r) => {
      if (actor && !r.actorId.toLowerCase().includes(actor.toLowerCase())) {
        return false;
      }
      if (entity) {
        const q = entity.toLowerCase();
        const hay = `${r.entityType} ${r.entityId}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });
  }, [rows, actor, entity]);

  return (
    <PageShell>
      <PageHeader
        title="Auditoría"
        description="Registro de mutaciones sensibles: actor, acción, entidad, motivo y fecha."
        actions={
          <Button variant="outline" onClick={() => void load()} disabled={loading}>
            Actualizar
          </Button>
        }
      />
      {error ? <ErrorBanner message={error} onDismiss={() => setError(null)} /> : null}

      <div className="mb-4 flex flex-wrap gap-2">
        <Input
          className="w-48"
          placeholder="Filtrar actor…"
          value={actor}
          onChange={(e) => setActor(e.target.value)}
        />
        <Input
          className="min-w-[12rem] flex-1"
          placeholder="Entidad o id…"
          value={entity}
          onChange={(e) => setEntity(e.target.value)}
        />
      </div>

      {loading ? (
        <Skeleton className="h-40 w-full" />
      ) : filtered.length === 0 ? (
        <EmptyState
          title="Sin registros"
          description="Aún no hay entradas de auditoría o no coinciden con el filtro."
        />
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Fecha</TableHead>
              <TableHead>Acción</TableHead>
              <TableHead>Entidad</TableHead>
              <TableHead>Actor</TableHead>
              <TableHead>Motivo</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filtered.map((r) => (
              <TableRow key={r.id}>
                <TableCell className="whitespace-nowrap text-muted-foreground">
                  {formatTimestamp(r.createdAt)}
                </TableCell>
                <TableCell>
                  <Badge variant="bondi">{r.action}</Badge>
                </TableCell>
                <TableCell>
                  <div className="text-xs text-muted-foreground">{r.entityType}</div>
                  <div className="font-mono text-xs">{r.entityId}</div>
                </TableCell>
                <TableCell className="font-mono text-xs">{r.actorId}</TableCell>
                <TableCell className="max-w-xs truncate text-sm">
                  {r.reason ?? "—"}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </PageShell>
  );
}
