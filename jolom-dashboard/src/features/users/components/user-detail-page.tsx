"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { useParams } from "next/navigation";
import {
  getBarberProfile,
  getMembership,
  getSalon,
  getUser,
  listReportsForTarget,
  type WithId,
} from "@/lib/api/firestore";
import { formatTimestamp } from "@/lib/format";
import {
  MODERATION_STATUS_LABELS,
  effectiveUserModerationStatus,
  moderationVariant,
  REPORT_STATUS_LABELS,
} from "@/lib/labels";
import type {
  BarberProfileDoc,
  ModerationActionType,
  ReportDoc,
  SalonDoc,
  SalonMembershipDoc,
  UserDoc,
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

function userActionsFor(user: WithId<UserDoc> | null): ModerationActionType[] {
  if (!user || (user.accountStatus && user.accountStatus !== "active") || user.isDeleted) {
    return [];
  }
  if (user.isBanned || user.moderationStatus === "banned") {
    return ["unban", "softDelete"];
  }
  if (user.moderationStatus === "warned") {
    return ["ban", "restore", "softDelete"];
  }
  return ["warn", "ban", "softDelete"];
}

export function UserDetailPage() {
  const params = useParams<{ id: string }>();
  const id = params.id;
  const [user, setUser] = useState<WithId<UserDoc> | null>(null);
  const [barber, setBarber] = useState<WithId<BarberProfileDoc> | null>(null);
  const [membership, setMembership] =
    useState<WithId<SalonMembershipDoc> | null>(null);
  const [salon, setSalon] = useState<WithId<SalonDoc> | null>(null);
  const [reports, setReports] = useState<WithId<ReportDoc>[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [defaultAction, setDefaultAction] =
    useState<ModerationActionType>("warn");

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [u, b, m, reps] = await Promise.all([
        getUser(id),
        getBarberProfile(id),
        getMembership(id),
        listReportsForTarget(id),
      ]);
      setUser(u);
      setBarber(b);
      setMembership(m);
      setReports(reps);
      if (m?.salonId) {
        setSalon(await getSalon(m.salonId));
      } else {
        setSalon(null);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al cargar usuario");
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    // Carga inicial del detalle; `load` también se reutiliza después de moderar.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void load();
  }, [load]);

  const target: ModerationTarget | null = user
    ? {
        targetType: "user",
        targetId: user.id,
        label: user.displayName || user.email || user.id,
      }
    : null;
  const userActions = userActionsFor(user);
  const restoreLabel = "Quitar advertencia";
  const effectiveStatus = effectiveUserModerationStatus(
    user?.moderationStatus,
    user?.isBanned,
  );

  return (
    <PageShell>
      <PageHeader
        title={user?.displayName || user?.email || "Usuario"}
        description={id}
        actions={
          <Link
            href="/usuarios"
            className="inline-flex h-9 items-center rounded-md border border-border bg-card px-4 text-sm font-medium hover:bg-secondary"
          >
            Volver
          </Link>
        }
      />
      {error ? <ErrorBanner message={error} onDismiss={() => setError(null)} /> : null}

      {loading ? (
        <Skeleton className="h-48 w-full" />
      ) : !user ? (
        <p className="text-sm text-muted-foreground">Usuario no encontrado.</p>
      ) : (
        <div className="space-y-6">
          <section className="rounded-lg border border-border bg-card p-4">
            <div className="flex flex-wrap gap-2">
              <Badge variant={moderationVariant(effectiveStatus)}>
                {MODERATION_STATUS_LABELS[effectiveStatus]}
              </Badge>
              {user.isBanned ? <Badge variant="destructive">Bloqueado</Badge> : null}
              {user.isDeleted ? (
                <Badge variant="destructive">Eliminado</Badge>
              ) : null}
              {user.deletionRequestedAt ? (
                <Badge variant="amber">Solicitud de eliminación</Badge>
              ) : null}
            </div>
            <dl className="mt-4 grid gap-3 sm:grid-cols-2">
              <div>
                <dt className="text-xs text-muted-foreground">Email</dt>
                <dd>{user.email ?? "—"}</dd>
              </div>
              <div>
                <dt className="text-xs text-muted-foreground">Teléfono</dt>
                <dd>{user.phone ?? "—"}</dd>
              </div>
              <div>
                <dt className="text-xs text-muted-foreground">Capacidades</dt>
                <dd>
                  Cliente: {user.capabilities?.client ? "sí" : "no"} · Peluquero:{" "}
                  {user.capabilities?.barber ? "sí" : "no"}
                </dd>
              </div>
            </dl>
          </section>

          {barber ? (
            <section className="rounded-lg border border-border bg-card p-4">
              <h2 className="text-sm font-semibold">Perfil de peluquero</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                Estado: {barber.status}
              </p>
              {barber.bio ? <p className="mt-2 text-sm">{barber.bio}</p> : null}
            </section>
          ) : null}

          {membership ? (
            <section className="rounded-lg border border-border bg-card p-4">
              <h2 className="text-sm font-semibold">Pertenencia</h2>
              <p className="mt-1 text-sm">
                Rol {membership.role} · {membership.status}
                {salon ? (
                  <>
                    {" · "}
                    <Link
                      href={`/peluquerias/${salon.id}`}
                      className="text-bondi hover:underline"
                    >
                      {salon.name}
                    </Link>
                  </>
                ) : null}
              </p>
            </section>
          ) : null}

          <section>
            <h2 className="mb-2 text-sm font-semibold">Acciones sobre cuenta</h2>
            <div className="flex flex-wrap gap-2">
              {userActions.length === 0 ? (
                <p className="text-sm text-muted-foreground">
                  No hay acciones compatibles con el estado actual.
                </p>
              ) : (
                userActions.map((a) => (
                  <Button
                    key={a}
                    size="sm"
                    variant={
                      a === "ban" || a === "softDelete"
                        ? "destructive"
                        : "outline"
                    }
                    onClick={() => {
                      setDefaultAction(a);
                      setDialogOpen(true);
                    }}
                  >
                    {ACTION_LABELS[a]}
                  </Button>
                ))
              )}
            </div>
          </section>

          <section>
            <h2 className="mb-2 text-sm font-semibold">Reportes del objetivo</h2>
            {reports.length === 0 ? (
              <p className="text-sm text-muted-foreground">Sin reportes.</p>
            ) : (
              <ul className="space-y-2">
                {reports.map((r) => (
                  <li key={r.id}>
                    <Link
                      href={`/reportes/${r.id}`}
                      className="text-sm text-bondi hover:underline"
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
        allowedActions={userActions}
        defaultAction={defaultAction}
        actionLabels={{
          softDelete: "Eliminar cuenta y anonimizar",
          restore: restoreLabel,
        }}
        hint={
          defaultAction === "softDelete"
            ? "Esta acción bloquea la cuenta, inicia la anonimización automática y elimina Firebase Auth. No puede restaurarse."
            : undefined
        }
        onSuccess={() => void load()}
      />
    </PageShell>
  );
}
