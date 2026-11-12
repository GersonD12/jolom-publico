"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import { listSalons, type WithId } from "@/lib/api/firestore";
import { formatTimestamp } from "@/lib/format";
import { PUBLISH_STATUS_LABELS } from "@/lib/labels";
import type { ModerationActionType, SalonDoc } from "@/types/firestore";
import { PageHeader, ErrorBanner } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import {
  ModerationDialog,
  type ModerationTarget,
} from "@/components/shared/moderation-dialog";
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

function publishVariant(
  status?: string,
): "default" | "amber" | "celadon" | "destructive" | "bondi" {
  switch (status) {
    case "published":
      return "celadon";
    case "draft":
      return "default";
    case "hidden":
      return "amber";
    case "suspended":
    case "deleted":
      return "destructive";
    default:
      return "bondi";
  }
}

export function SalonsPage() {
  const [rows, setRows] = useState<WithId<SalonDoc>[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState("all");
  const [search, setSearch] = useState("");
  const [dialogOpen, setDialogOpen] = useState(false);
  const [target, setTarget] = useState<ModerationTarget | null>(null);
  const [defaultAction, setDefaultAction] =
    useState<ModerationActionType>("restore");

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setRows(await listSalons(120));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al cargar peluquerías");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const filtered = useMemo(() => {
    return rows.filter((s) => {
      if (status !== "all" && s.publishStatus !== status) return false;
      if (search) {
        const q = search.toLowerCase();
        const hay = `${s.id} ${s.name} ${s.city} ${s.ownerId}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });
  }, [rows, status, search]);

  function openLiftSuspension(salon: WithId<SalonDoc>) {
    setTarget({
      targetType: "salon",
      targetId: salon.id,
      label: salon.name,
    });
    setDefaultAction("restore");
    setDialogOpen(true);
  }

  return (
    <PageShell>
      <PageHeader
        title="Peluquerías"
        description="Publicación, sanciones y contexto de equipo. Sin operación de calendarios."
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
          aria-label="Estado de publicación"
        >
          <option value="all">Todos</option>
          <option value="published">Publicadas</option>
          <option value="draft">Borrador</option>
          <option value="hidden">Ocultas</option>
          <option value="suspended">Suspendidas</option>
          <option value="deleted">Eliminadas</option>
        </Select>
        <Input
          className="min-w-[14rem] flex-1"
          placeholder="Buscar nombre, ciudad o id…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      {loading ? (
        <Skeleton className="h-40 w-full" />
      ) : filtered.length === 0 ? (
        <EmptyState title="Sin peluquerías" description="No hay coincidencias." />
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Nombre</TableHead>
              <TableHead>Ciudad</TableHead>
              <TableHead>Publicación</TableHead>
              <TableHead>Alta</TableHead>
              <TableHead>Acciones</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filtered.map((s) => (
              <TableRow key={s.id}>
                <TableCell>
                  <Link
                    href={`/peluquerias/${s.id}`}
                    className="font-medium text-bondi hover:underline"
                  >
                    {s.name}
                  </Link>
                  <div className="text-xs text-muted-foreground">{s.id}</div>
                </TableCell>
                <TableCell>{s.city}</TableCell>
                <TableCell>
                  <Badge variant={publishVariant(s.publishStatus)}>
                    {PUBLISH_STATUS_LABELS[s.publishStatus] ?? s.publishStatus}
                  </Badge>
                  {s.isDeleted ? (
                    <Badge className="ml-1" variant="destructive">
                      Soft delete
                    </Badge>
                  ) : null}
                </TableCell>
                <TableCell className="text-muted-foreground">
                  {formatTimestamp(s.createdAt)}
                </TableCell>
                <TableCell>
                  {s.publishStatus === "suspended" ? (
                    <Button
                      size="sm"
                      variant="primary"
                      onClick={() => openLiftSuspension(s)}
                    >
                      Levantar suspensión
                    </Button>
                  ) : (
                    <span className="text-xs text-muted-foreground">—</span>
                  )}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}

      <ModerationDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        target={target}
        allowedActions={["restore"]}
        defaultAction={defaultAction}
        actionLabels={{ restore: "Levantar suspensión" }}
        hint="La peluquería volverá a estar visible para todos en la app."
        onSuccess={() => void load()}
      />
    </PageShell>
  );
}
