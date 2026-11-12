"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useParams } from "next/navigation";
import {
  getSalon,
  listReportsForTarget,
  listSalonMemberships,
  listSalonServices,
  type WithId,
} from "@/lib/api/firestore";
import { formatTimestamp } from "@/lib/format";
import { PUBLISH_STATUS_LABELS, REPORT_STATUS_LABELS } from "@/lib/labels";
import type {
  ModerationActionType,
  PublishStatus,
  ReportDoc,
  SalonDoc,
  SalonMembershipDoc,
  ServiceDoc,
} from "@/types/firestore";
import { PageHeader, ErrorBanner } from "@/components/shared/page-header";
import {
  ModerationDialog,
  type ModerationTarget,
} from "@/components/shared/moderation-dialog";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { PageShell } from "@/components/layout/page-shell";
import { ACTION_LABELS } from "@/components/shared/moderation-dialog";

function salonActionsFor(status: PublishStatus): ModerationActionType[] {
  switch (status) {
    case "suspended":
      return ["restore", "softDelete"];
    case "deleted":
      return ["restore"];
    case "hidden":
      return ["warn", "restore", "suspend", "softDelete"];
    case "draft":
      return ["warn", "suspend", "softDelete"];
    case "published":
    default:
      return ["warn", "unpublish", "suspend", "softDelete"];
  }
}

function restoreLabelFor(status: PublishStatus): string {
  return status === "suspended" ? "Levantar suspensión" : "Restaurar";
}

export function SalonDetailPage() {
  const params = useParams<{ id: string }>();
  const id = params.id;
  const [salon, setSalon] = useState<WithId<SalonDoc> | null>(null);
  const [members, setMembers] = useState<WithId<SalonMembershipDoc>[]>([]);
  const [services, setServices] = useState<WithId<ServiceDoc>[]>([]);
  const [reports, setReports] = useState<WithId<ReportDoc>[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [defaultAction, setDefaultAction] =
    useState<ModerationActionType>("unpublish");

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [s, m, svc, reps] = await Promise.all([
        getSalon(id),
        listSalonMemberships(id),
        listSalonServices(id),
        listReportsForTarget(id),
      ]);
      setSalon(s);
      setMembers(m);
      setServices(svc);
      setReports(reps);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al cargar peluquería");
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void load();
  }, [load]);

  const target: ModerationTarget | null = salon
    ? { targetType: "salon", targetId: salon.id, label: salon.name }
    : null;

  const allowedActions = useMemo(
    () => (salon ? salonActionsFor(salon.publishStatus) : []),
    [salon],
  );

  const actionLabels = useMemo(() => {
    if (!salon) return undefined;
    if (!allowedActions.includes("restore")) return undefined;
    return { restore: restoreLabelFor(salon.publishStatus) };
  }, [salon, allowedActions]);

  function openAction(action: ModerationActionType) {
    setDefaultAction(action);
    setDialogOpen(true);
  }

  return (
    <PageShell>
      <PageHeader
        title={salon?.name ?? "Peluquería"}
        description={id}
        actions={
          <Link
            href="/peluquerias"
            className="inline-flex h-9 items-center rounded-md border border-border bg-card px-4 text-sm font-medium hover:bg-secondary"
          >
            Volver
          </Link>
        }
      />
      {error ? <ErrorBanner message={error} onDismiss={() => setError(null)} /> : null}

      {loading ? (
        <Skeleton className="h-48 w-full" />
      ) : !salon ? (
        <p className="text-sm text-muted-foreground">Peluquería no encontrada.</p>
      ) : (
        <div className="space-y-6">
          <section className="rounded-lg border border-border bg-card p-4">
            <Badge variant="outline">
              {PUBLISH_STATUS_LABELS[salon.publishStatus] ?? salon.publishStatus}
            </Badge>
            <dl className="mt-4 grid gap-3 sm:grid-cols-2">
              <div>
                <dt className="text-xs text-muted-foreground">Ciudad</dt>
                <dd>{salon.city}</dd>
              </div>
              <div>
                <dt className="text-xs text-muted-foreground">Propietario</dt>
                <dd>
                  <Link
                    href={`/usuarios/${salon.ownerId}`}
                    className="text-bondi hover:underline"
                  >
                    {salon.ownerId}
                  </Link>
                </dd>
              </div>
              <div>
                <dt className="text-xs text-muted-foreground">Contacto</dt>
                <dd>
                  {salon.contactPhone ?? "—"} · {salon.contactEmail ?? "—"}
                </dd>
              </div>
              <div>
                <dt className="text-xs text-muted-foreground">Dirección</dt>
                <dd>{salon.address ?? "—"}</dd>
              </div>
            </dl>
            {salon.description ? (
              <p className="mt-3 text-sm text-muted-foreground">{salon.description}</p>
            ) : null}
          </section>

          <section>
            <h2 className="mb-2 text-sm font-semibold">Acciones</h2>
            <div className="flex flex-wrap gap-2">
              {allowedActions.map((a) => {
                const isLift =
                  a === "restore" &&
                  (salon.publishStatus === "suspended" ||
                    salon.publishStatus === "deleted");
                const label =
                  a === "restore"
                    ? restoreLabelFor(salon.publishStatus)
                    : ACTION_LABELS[a];
                return (
                  <Button
                    key={a}
                    size="sm"
                    variant={
                      a === "softDelete"
                        ? "destructive"
                        : isLift
                          ? "primary"
                          : "outline"
                    }
                    onClick={() => openAction(a)}
                  >
                    {label}
                  </Button>
                );
              })}
            </div>
          </section>

          <section>
            <h2 className="mb-2 text-sm font-semibold">Equipo</h2>
            {members.length === 0 ? (
              <p className="text-sm text-muted-foreground">Sin pertenencias.</p>
            ) : (
              <ul className="space-y-1 text-sm">
                {members.map((m) => (
                  <li key={m.id}>
                    <Link
                      href={`/usuarios/${m.userId}`}
                      className="text-bondi hover:underline"
                    >
                      {m.userId}
                    </Link>{" "}
                    · {m.role} · {m.status}
                  </li>
                ))}
              </ul>
            )}
          </section>

          <section>
            <h2 className="mb-2 text-sm font-semibold">Servicios (solo lectura)</h2>
            {services.length === 0 ? (
              <p className="text-sm text-muted-foreground">Sin servicios.</p>
            ) : (
              <ul className="space-y-1 text-sm">
                {services.map((s) => (
                  <li key={s.id}>
                    {s.name} · {s.durationMinutes} min · {s.price} {s.currency} ·{" "}
                    {s.status}
                    {s.isDeleted ? " · eliminado" : ""}
                  </li>
                ))}
              </ul>
            )}
          </section>

          <section>
            <h2 className="mb-2 text-sm font-semibold">Reportes</h2>
            {reports.length === 0 ? (
              <p className="text-sm text-muted-foreground">Sin reportes.</p>
            ) : (
              <ul className="space-y-1 text-sm">
                {reports.map((r) => (
                  <li key={r.id}>
                    <Link
                      href={`/reportes/${r.id}`}
                      className="text-bondi hover:underline"
                    >
                      {REPORT_STATUS_LABELS[r.status]} · {r.category} ·{" "}
                      {formatTimestamp(r.createdAt)}
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      )}

      <ModerationDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        target={target}
        allowedActions={allowedActions}
        defaultAction={defaultAction}
        actionLabels={actionLabels}
        hint={
          salon?.publishStatus === "suspended" && defaultAction === "restore"
            ? "La peluquería volverá a estar visible para todos en la app."
            : undefined
        }
        onSuccess={() => void load()}
      />
    </PageShell>
  );
}
