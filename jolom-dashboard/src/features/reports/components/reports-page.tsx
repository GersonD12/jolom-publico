"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import { listReports, type WithId } from "@/lib/api/firestore";
import { formatTimestamp } from "@/lib/format";
import { REPORT_STATUS_LABELS, reportStatusVariant } from "@/lib/labels";
import type { ReportDoc } from "@/types/firestore";
import { PageHeader, ErrorBanner } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
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

export function ReportsPage() {
  const [rows, setRows] = useState<WithId<ReportDoc>[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [openOnly, setOpenOnly] = useState(true);
  const [category, setCategory] = useState("");
  const [entity, setEntity] = useState("all");
  const [search, setSearch] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setRows(await listReports({ openOnly, max: 80 }));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al cargar reportes");
    } finally {
      setLoading(false);
    }
  }, [openOnly]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void load();
  }, [load]);

  const filtered = useMemo(() => {
    return rows.filter((r) => {
      if (category && !r.category?.toLowerCase().includes(category.toLowerCase())) {
        return false;
      }
      if (entity !== "all" && r.targetType !== entity) return false;
      if (search) {
        const q = search.toLowerCase();
        const hay = `${r.id} ${r.targetId} ${r.reporterId} ${r.description}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });
  }, [rows, category, entity, search]);

  return (
    <PageShell>
      <PageHeader
        title="Reportes y casos"
        description="Bandeja de denuncias. Cada acción crea un caso de moderación con auditoría."
        actions={
          <Button variant="outline" onClick={() => void load()} disabled={loading}>
            Actualizar
          </Button>
        }
      />

      {error ? <ErrorBanner message={error} onDismiss={() => setError(null)} /> : null}

      <div className="mb-4 flex flex-wrap gap-2">
        <Select
          value={openOnly ? "open" : "all"}
          onChange={(e) => setOpenOnly(e.target.value === "open")}
          aria-label="Filtrar por estado"
          className="w-40"
        >
          <option value="open">Abiertos</option>
          <option value="all">Todos</option>
        </Select>
        <Select
          value={entity}
          onChange={(e) => setEntity(e.target.value)}
          aria-label="Tipo de entidad"
          className="w-40"
        >
          <option value="all">Toda entidad</option>
          <option value="user">Usuario</option>
          <option value="barber">Peluquero</option>
          <option value="salon">Peluquería</option>
          <option value="content">Contenido</option>
        </Select>
        <Input
          className="w-40"
          placeholder="Categoría"
          value={category}
          onChange={(e) => setCategory(e.target.value)}
        />
        <Input
          className="min-w-[12rem] flex-1"
          placeholder="Buscar id, descripción…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      {loading ? (
        <div className="space-y-2">
          <Skeleton className="h-10 w-full" />
          <Skeleton className="h-10 w-full" />
          <Skeleton className="h-10 w-full" />
        </div>
      ) : filtered.length === 0 ? (
        <EmptyState
          title="Sin reportes"
          description="No hay denuncias con los filtros actuales."
        />
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Estado</TableHead>
              <TableHead>Entidad</TableHead>
              <TableHead>Categoría</TableHead>
              <TableHead>Descripción</TableHead>
              <TableHead>Fecha</TableHead>
              <TableHead>Acciones</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filtered.map((r) => {
              return (
                <TableRow key={r.id}>
                <TableCell>
                  <Badge variant={reportStatusVariant(r.status)}>
                    {REPORT_STATUS_LABELS[r.status] ?? r.status}
                  </Badge>
                </TableCell>
                <TableCell>
                  <div className="text-xs text-muted-foreground">{r.targetType}</div>
                  <Link
                    href={`/reportes/${r.id}`}
                    className="font-medium text-bondi hover:underline"
                  >
                    {r.targetId.slice(0, 10)}…
                  </Link>
                </TableCell>
                <TableCell>{r.category}</TableCell>
                <TableCell className="max-w-xs truncate">{r.description}</TableCell>
                <TableCell className="whitespace-nowrap text-muted-foreground">
                  {formatTimestamp(r.createdAt)}
                </TableCell>
                <TableCell>
                  <Link
                    href={`/reportes/${r.id}`}
                    className="text-sm font-medium text-bondi hover:underline"
                  >
                    Revisar
                  </Link>
                </TableCell>
                </TableRow>
              );
            })}
          </TableBody>
        </Table>
      )}
    </PageShell>
  );
}
