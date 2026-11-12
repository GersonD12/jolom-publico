"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import { listUsers, type WithId } from "@/lib/api/firestore";
import { formatTimestamp } from "@/lib/format";
import {
  MODERATION_STATUS_LABELS,
  effectiveUserModerationStatus,
  moderationVariant,
} from "@/lib/labels";
import type { UserDoc } from "@/types/firestore";
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

export function UsersPage() {
  const [rows, setRows] = useState<WithId<UserDoc>[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState("all");
  const [search, setSearch] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setRows(await listUsers(120));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al cargar usuarios");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // Carga inicial; `load` también se reutiliza al actualizar filtros remotos.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void load();
  }, [load]);

  const filtered = useMemo(() => {
    return rows.filter((u) => {
      const effectiveStatus = effectiveUserModerationStatus(
        u.moderationStatus,
        u.isBanned,
      );
      if (status !== "all" && effectiveStatus !== status) return false;
      if (search) {
        const q = search.toLowerCase();
        const hay = `${u.id} ${u.email ?? ""} ${u.displayName ?? ""}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });
  }, [rows, status, search]);

  return (
    <PageShell>
      <PageHeader
        title="Usuarios"
        description="Búsqueda y estado de moderación. Las sanciones se aplican desde el detalle."
        actions={
          <Button variant="outline" onClick={() => void load()} disabled={loading}>
            Actualizar
          </Button>
        }
      />
      {error ? <ErrorBanner message={error} onDismiss={() => setError(null)} /> : null}

      <div className="mb-4 flex flex-wrap gap-2">
        <Select
          className="w-44"
          value={status}
          onChange={(e) => setStatus(e.target.value)}
          aria-label="Estado de moderación"
        >
          <option value="all">Todos los estados</option>
          <option value="none">Sin sanción</option>
          <option value="warned">Advertidos</option>
          <option value="banned">Bloqueados</option>
        </Select>
        <Input
          className="min-w-[14rem] flex-1"
          placeholder="Buscar email, nombre o uid…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      {loading ? (
        <Skeleton className="h-40 w-full" />
      ) : filtered.length === 0 ? (
        <EmptyState title="Sin usuarios" description="No hay coincidencias." />
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Usuario</TableHead>
              <TableHead>Capacidades</TableHead>
              <TableHead>Moderación</TableHead>
              <TableHead>Alta</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filtered.map((u) => {
              const effectiveStatus = effectiveUserModerationStatus(
                u.moderationStatus,
                u.isBanned,
              );
              return <TableRow key={u.id}>
                <TableCell>
                  <Link
                    href={`/usuarios/${u.id}`}
                    className="font-medium text-bondi hover:underline"
                  >
                    {u.displayName || u.email || u.id.slice(0, 8)}
                  </Link>
                  <div className="text-xs text-muted-foreground">
                    {u.email ?? u.id}
                  </div>
                </TableCell>
                <TableCell className="text-xs">
                  {u.capabilities?.client ? "Cliente" : ""}
                  {u.capabilities?.barber ? " · Peluquero" : ""}
                </TableCell>
                <TableCell>
                  <Badge variant={moderationVariant(effectiveStatus)}>
                    {MODERATION_STATUS_LABELS[effectiveStatus]}
                  </Badge>
                  {u.isDeleted ? (
                    <Badge className="ml-1" variant="destructive">
                      Eliminado
                    </Badge>
                  ) : null}
                </TableCell>
                <TableCell className="text-muted-foreground">
                  {formatTimestamp(u.createdAt)}
                </TableCell>
              </TableRow>;
            })}
          </TableBody>
        </Table>
      )}
    </PageShell>
  );
}
