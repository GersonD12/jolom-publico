"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  listAccountDeletionJobs,
  listDeletedSalons,
  listDeletedUsers,
  type WithId,
} from "@/lib/api/firestore";
import { formatTimestamp } from "@/lib/format";
import { PUBLISH_STATUS_LABELS } from "@/lib/labels";
import { cn } from "@/lib/utils/cn";
import type {
  AccountDeletionJobDoc,
  ModerationActionType,
  SalonDoc,
  UserDoc,
} from "@/types/firestore";
import { PageHeader, ErrorBanner } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import {
  ModerationDialog,
  type ModerationTarget,
} from "@/components/shared/moderation-dialog";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
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

type TabId = "pending" | "deletedUsers" | "salons";

const TABS: { id: TabId; label: string }[] = [
  { id: "pending", label: "Procesos automáticos" },
  { id: "deletedUsers", label: "Usuarios eliminados" },
  { id: "salons", label: "Peluquerías" },
];

const TAB_HINTS: Record<TabId, string> = {
  pending:
    "La eliminación no requiere aprobación. Aquí puedes supervisar la cola, los reintentos y los trabajos completados.",
  deletedUsers:
    "Los tombstones anonimizados se purgan automáticamente después del plazo operativo. Las eliminaciones definitivas no se restauran.",
  salons:
    "Peluquerías eliminadas o suspendidas. Las acciones aquí afectan al negocio, no a una cuenta personal.",
};

export function DeletionsPage() {
  const [users, setUsers] = useState<WithId<UserDoc>[]>([]);
  const [salons, setSalons] = useState<WithId<SalonDoc>[]>([]);
  const [jobs, setJobs] = useState<WithId<AccountDeletionJobDoc>[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [tab, setTab] = useState<TabId>("pending");
  const [target, setTarget] = useState<ModerationTarget | null>(null);
  const [defaultAction, setDefaultAction] =
    useState<ModerationActionType>("softDelete");
  const [dialogOpen, setDialogOpen] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [u, s, j] = await Promise.all([
        listDeletedUsers(),
        listDeletedSalons(),
        listAccountDeletionJobs(),
      ]);
      setUsers(u.filter((x) => x.isDeleted || Boolean(x.deletionRequestedAt)));
      setSalons(s);
      setJobs(j);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al cargar eliminaciones");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // Carga inicial controlada; `load` también se reutiliza en el botón Actualizar.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void load();
  }, [load]);

  const deletedUsers = useMemo(
    () => users.filter((u) => u.isDeleted),
    [users],
  );

  const counts: Record<TabId, number> = {
    pending: jobs.length,
    deletedUsers: deletedUsers.length,
    salons: salons.length,
  };

  function openAction(t: ModerationTarget, action: ModerationActionType) {
    setTarget(t);
    setDefaultAction(action);
    setDialogOpen(true);
  }

  const salonForDialog =
    target?.targetType === "salon"
      ? salons.find((s) => s.id === target.targetId)
      : undefined;

  return (
    <PageShell>
      <PageHeader
        title="Eliminaciones"
        description="Supervisa eliminaciones automáticas y gestiona acciones administrativas sobre cuentas y negocios."
        actions={
          <Button variant="outline" onClick={() => void load()} disabled={loading}>
            Actualizar
          </Button>
        }
      />
      {error ? <ErrorBanner message={error} onDismiss={() => setError(null)} /> : null}

      {loading ? (
        <Skeleton className="h-40 w-full" />
      ) : (
        <div className="space-y-4">
          <div
            role="tablist"
            aria-label="Colas de eliminaciones"
            className="inline-flex flex-wrap gap-1 rounded-lg border border-border bg-secondary p-1"
          >
            {TABS.map((t) => {
              const selected = tab === t.id;
              return (
                <button
                  key={t.id}
                  type="button"
                  role="tab"
                  aria-selected={selected}
                  id={`tab-${t.id}`}
                  className={cn(
                    "rounded-md px-3 py-1.5 text-sm font-medium transition-colors",
                    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
                    selected
                      ? "bg-card text-foreground shadow-sm"
                      : "text-muted-foreground hover:text-foreground",
                  )}
                  onClick={() => setTab(t.id)}
                >
                  {t.label} ({counts[t.id]})
                </button>
              );
            })}
          </div>

          <div role="tabpanel" aria-labelledby={`tab-${tab}`} className="space-y-4">
            <p className="text-sm text-muted-foreground">{TAB_HINTS[tab]}</p>

            {tab === "pending" ? (
              jobs.length === 0 ? (
                <EmptyState
                  title="Sin trabajos de eliminación"
                  description="No hay eliminaciones automáticas recientes."
                />
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Referencia</TableHead>
                      <TableHead>Tipo</TableHead>
                      <TableHead>Solicitado</TableHead>
                      <TableHead>Estado</TableHead>
                      <TableHead className="text-right">Intentos</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {jobs.map((job) => (
                      <TableRow key={job.id}>
                        <TableCell>
                          {job.userId ? (
                            <Link
                              href={`/usuarios/${job.userId}`}
                              className="text-bondi hover:underline"
                            >
                              {job.userId.slice(0, 10)}…
                            </Link>
                          ) : (
                            <span className="text-muted-foreground">
                              Anónima {job.anonymousId.slice(0, 8)}…
                            </span>
                          )}
                        </TableCell>
                        <TableCell>
                          {job.role === "owner"
                            ? "Propietario y negocio"
                            : job.role === "barber"
                              ? "Peluquero"
                              : "Cliente"}
                        </TableCell>
                        <TableCell>{formatTimestamp(job.requestedAt)}</TableCell>
                        <TableCell>
                          <Badge
                            variant={
                              job.status === "completed"
                                ? "celadon"
                                : job.status === "failed"
                                  ? "destructive"
                                  : "amber"
                            }
                          >
                            {job.status === "queued"
                              ? "En cola"
                              : job.status === "processing"
                                ? "Procesando"
                                : job.status === "failed"
                                  ? "Reintentando"
                                  : "Completada"}
                          </Badge>
                          {job.lastError ? (
                            <div className="mt-1 text-xs text-destructive">
                              {job.lastError}
                            </div>
                          ) : null}
                        </TableCell>
                        <TableCell className="text-right">{job.attempts}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )
            ) : null}

            {tab === "deletedUsers" ? (
              deletedUsers.length === 0 ? (
                <EmptyState
                  title="Ningún usuario eliminado"
                  description="Aquí aparecerán las cuentas con soft delete."
                />
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Usuario</TableHead>
                      <TableHead>Estado</TableHead>
                      <TableHead className="text-right">Acción</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {deletedUsers.map((u) => (
                      <TableRow key={u.id}>
                        <TableCell>
                          <Link
                            href={`/usuarios/${u.id}`}
                            className="text-bondi hover:underline"
                          >
                            {u.email || u.displayName || u.id}
                          </Link>
                        </TableCell>
                        <TableCell>
                          <Badge variant="destructive">Eliminado</Badge>
                        </TableCell>
                        <TableCell className="text-right">
                          {u.accountStatus === "deleted" ? (
                            <span className="text-sm text-muted-foreground">
                              Eliminación permanente
                            </span>
                          ) : (
                            <Button
                              size="md"
                              variant="outline"
                              onClick={() =>
                                openAction(
                                  {
                                    targetType: "user",
                                    targetId: u.id,
                                    label: `Usuario: ${u.email || u.displayName || u.id}`,
                                  },
                                  "restore",
                                )
                              }
                            >
                              Restaurar cuenta legacy
                            </Button>
                          )}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )
            ) : null}

            {tab === "salons" ? (
              salons.length === 0 ? (
                <EmptyState
                  title="Ninguna peluquería"
                  description="No hay peluquerías eliminadas ni suspendidas."
                />
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Peluquería</TableHead>
                      <TableHead>Estado</TableHead>
                      <TableHead className="text-right">Acción</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {salons.map((s) => {
                      const suspended = s.publishStatus === "suspended";
                      return (
                        <TableRow key={s.id}>
                          <TableCell>
                            <Link
                              href={`/peluquerias/${s.id}`}
                              className="text-bondi hover:underline"
                            >
                              {s.name}
                            </Link>
                          </TableCell>
                          <TableCell>
                            <Badge variant="destructive">
                              {PUBLISH_STATUS_LABELS[s.publishStatus] ??
                                s.publishStatus}
                            </Badge>
                          </TableCell>
                          <TableCell className="text-right">
                            <Button
                              size="md"
                              variant={suspended ? "primary" : "outline"}
                              onClick={() =>
                                openAction(
                                  {
                                    targetType: "salon",
                                    targetId: s.id,
                                    label: `Peluquería: ${s.name}`,
                                  },
                                  "restore",
                                )
                              }
                            >
                              {suspended
                                ? "Levantar suspensión"
                                : "Restaurar peluquería"}
                            </Button>
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              )
            ) : null}
          </div>
        </div>
      )}

      <ModerationDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        target={target}
        allowedActions={
          target?.targetType === "salon"
            ? ["restore", "softDelete"]
            : ["softDelete", "restore"]
        }
        defaultAction={defaultAction}
        actionLabels={
          salonForDialog?.publishStatus === "suspended" &&
          defaultAction === "restore"
            ? { restore: "Levantar suspensión" }
            : undefined
        }
        hint={
          salonForDialog?.publishStatus === "suspended" &&
          defaultAction === "restore"
            ? "La peluquería volverá a estar visible para todos en la app."
            : target?.targetType === "user" && defaultAction === "softDelete"
              ? "La cuenta se bloqueará y entrará al mismo proceso automático de anonimización y eliminación de Firebase Auth."
              : undefined
        }
        onSuccess={() => void load()}
      />
    </PageShell>
  );
}
