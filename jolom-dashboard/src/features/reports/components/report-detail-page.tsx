"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { useParams } from "next/navigation";
import {
  closeReportWithoutAction,
  getReport,
  getSalon,
  getUser,
  listModerationCases,
  type WithId,
} from "@/lib/api/firestore";
import { formatTimestamp } from "@/lib/format";
import { REPORT_STATUS_LABELS, reportStatusVariant } from "@/lib/labels";
import type {
  ModerationCaseDoc,
  ReportDoc,
  ModerationActionType,
  SalonDoc,
  UserDoc,
} from "@/types/firestore";
import { PageHeader, ErrorBanner } from "@/components/shared/page-header";
import {
  ModerationDialog,
  type ModerationTarget,
} from "@/components/shared/moderation-dialog";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Dialog, DialogFooter } from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import { Textarea } from "@/components/ui/textarea";
import { PageShell } from "@/components/layout/page-shell";
import { ACTION_LABELS } from "@/components/shared/moderation-dialog";

function actionsForReport(
  report: WithId<ReportDoc> | null,
  user: WithId<UserDoc> | null,
  salon: WithId<SalonDoc> | null,
): ModerationActionType[] {
  if (!report || report.status.startsWith("closed")) return [];
  if (report.targetType === "salon") {
    if (!salon) return [];
    if (salon.isDeleted || salon.publishStatus === "deleted") return [];
    if (salon.publishStatus === "suspended") return ["softDelete"];
    if (salon.publishStatus === "hidden") {
      return ["warn", "suspend", "softDelete"];
    }
    if (salon.publishStatus === "draft") {
      return ["warn", "suspend", "softDelete"];
    }
    return ["warn", "unpublish", "suspend", "softDelete"];
  }
  if (report.targetType === "user" || report.targetType === "barber") {
    if (!user || (user.accountStatus && user.accountStatus !== "active") || user.isDeleted) {
      return [];
    }
    if (user.isBanned || user.moderationStatus === "banned") {
      return [];
    }
    if (user.moderationStatus === "warned") {
      return ["ban"];
    }
    return ["warn", "ban"];
  }
  return [];
}

export function ReportDetailPage() {
  const params = useParams<{ id: string }>();
  const id = params.id;
  const [report, setReport] = useState<WithId<ReportDoc> | null>(null);
  const [cases, setCases] = useState<WithId<ModerationCaseDoc>[]>([]);
  const [targetUser, setTargetUser] = useState<WithId<UserDoc> | null>(null);
  const [targetSalon, setTargetSalon] = useState<WithId<SalonDoc> | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [defaultAction, setDefaultAction] =
    useState<ModerationActionType>("warn");
  const [closing, setClosing] = useState(false);
  const [closeOpen, setCloseOpen] = useState(false);
  const [closeReason, setCloseReason] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [r, allCases] = await Promise.all([
        getReport(id),
        listModerationCases(80),
      ]);
      setReport(r);
      if (r?.targetType === "salon") {
        setTargetSalon(await getSalon(r.targetId));
        setTargetUser(null);
      } else if (r?.targetType === "user" || r?.targetType === "barber") {
        setTargetUser(await getUser(r.targetId));
        setTargetSalon(null);
      } else {
        setTargetUser(null);
        setTargetSalon(null);
      }
      setCases(
        allCases.filter(
          (c) => c.reportIds?.includes(id) || c.targetId === r?.targetId,
        ),
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error al cargar reporte");
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void load();
  }, [load]);

  const target: ModerationTarget | null = report && report.targetType !== "content"
    ? {
        targetType: report.targetType as ModerationTarget["targetType"],
        targetId: report.targetId,
        reportId: report.id,
        label: `${report.targetType} · ${report.targetId}`,
      }
    : null;
  const actions = actionsForReport(report, targetUser, targetSalon);

  const entityHref =
    report?.targetType === "salon"
      ? `/peluquerias/${report.targetId}`
      : report
        ? `/usuarios/${report.targetId}`
        : "#";

  return (
    <PageShell>
      <PageHeader
        title="Detalle del reporte"
        description={id}
        actions={
          <Link
            href="/reportes"
            className="inline-flex h-9 items-center rounded-md border border-border bg-card px-4 text-sm font-medium hover:bg-secondary"
          >
            Volver
          </Link>
        }
      />

      {error ? <ErrorBanner message={error} onDismiss={() => setError(null)} /> : null}

      {loading ? (
        <Skeleton className="h-40 w-full" />
      ) : !report ? (
        <p className="text-sm text-muted-foreground">Reporte no encontrado.</p>
      ) : (
        <div className="space-y-6">
          <section className="rounded-lg border border-border bg-card p-4">
            <div className="flex flex-wrap items-center gap-2">
              <Badge variant={reportStatusVariant(report.status)}>
                {REPORT_STATUS_LABELS[report.status] ?? report.status}
              </Badge>
              <span className="text-sm text-muted-foreground">
                {formatTimestamp(report.createdAt)}
              </span>
            </div>
            <dl className="mt-4 grid gap-3 sm:grid-cols-2">
              <div>
                <dt className="text-xs text-muted-foreground">Categoría</dt>
                <dd className="font-medium">{report.category}</dd>
              </div>
              <div>
                <dt className="text-xs text-muted-foreground">Reportante</dt>
                <dd className="font-mono text-sm">{report.reporterId}</dd>
              </div>
              <div>
                <dt className="text-xs text-muted-foreground">Objetivo</dt>
                <dd>
                  <Link href={entityHref} className="text-bondi hover:underline">
                    {report.targetType} · {report.targetId}
                  </Link>
                </dd>
              </div>
              {report.sourceSalonId ? (
                <div>
                  <dt className="text-xs text-muted-foreground">
                    Peluquería que bloqueó
                  </dt>
                  <dd>
                    <Link
                      href={`/peluquerias/${report.sourceSalonId}`}
                      className="font-mono text-sm text-bondi hover:underline"
                    >
                      {report.sourceSalonId}
                    </Link>
                  </dd>
                </div>
              ) : null}
              {report.sourceAppointmentId ? (
                <div>
                  <dt className="text-xs text-muted-foreground">Cita de origen</dt>
                  <dd className="font-mono text-sm">
                    {report.sourceAppointmentId}
                  </dd>
                </div>
              ) : null}
            </dl>
            <p className="mt-4 text-sm text-foreground">{report.description}</p>
          </section>

          <section>
            <h2 className="mb-2 text-sm font-semibold">Acciones</h2>
            <div className="flex flex-wrap gap-2">
              {actions.map((a) => (
                <Button
                  key={a}
                  size="sm"
                  variant={
                    a === "ban" || a === "softDelete" ? "destructive" : "outline"
                  }
                  onClick={() => {
                    setDefaultAction(a);
                    setDialogOpen(true);
                  }}
                >
                  {ACTION_LABELS[a]}
                </Button>
              ))}
              {actions.length === 0 && !report.status.startsWith("closed") ? (
                <p className="text-sm text-muted-foreground">
                  Este tipo de reporte todavía no admite acciones.
                </p>
              ) : null}
              <Button
                size="sm"
                variant="secondary"
                disabled={
                  closing ||
                  report.status === "closedWithAction" ||
                  report.status === "closedWithoutAction"
                }
                onClick={() => {
                  setCloseReason("");
                  setCloseOpen(true);
                }}
              >
                Cerrar sin acción
              </Button>
            </div>
          </section>

          <section>
            <h2 className="mb-2 text-sm font-semibold">Casos relacionados</h2>
            {cases.length === 0 ? (
              <p className="text-sm text-muted-foreground">
                Aún no hay casos vinculados. Al aplicar una acción se creará uno.
              </p>
            ) : (
              <ul className="space-y-2">
                {cases.map((c) => (
                  <li
                    key={c.id}
                    className="rounded-md border border-border bg-card px-3 py-2 text-sm"
                  >
                    <div className="flex flex-wrap items-center gap-2">
                      <Badge variant="bondi">{c.action}</Badge>
                      <Badge variant="outline">{c.status}</Badge>
                      <span className="text-muted-foreground">
                        {formatTimestamp(c.createdAt)}
                      </span>
                    </div>
                    <p className="mt-1">{c.reason}</p>
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
        allowedActions={actions}
        defaultAction={defaultAction}
        onSuccess={() => void load()}
      />

      <Dialog
        open={closeOpen}
        onOpenChange={setCloseOpen}
        title="Cerrar sin acción"
        description="El reporte quedará cerrado sin sanción. El motivo es obligatorio."
      >
        <div className="space-y-1.5">
          <Label htmlFor="close-reason">Motivo</Label>
          <Textarea
            id="close-reason"
            value={closeReason}
            onChange={(e) => setCloseReason(e.target.value)}
            placeholder="Explica por qué se descarta…"
          />
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => setCloseOpen(false)}>
            Cancelar
          </Button>
          <Button
            disabled={closing || !closeReason.trim() || !report}
            onClick={async () => {
              if (!report || !closeReason.trim()) return;
              setClosing(true);
              setError(null);
              try {
                await closeReportWithoutAction(report.id, closeReason.trim());
                setCloseOpen(false);
                await load();
              } catch (e) {
                setError(
                  e instanceof Error
                    ? e.message
                    : "No se pudo cerrar el reporte",
                );
              } finally {
                setClosing(false);
              }
            }}
          >
            {closing ? "Cerrando…" : "Confirmar cierre"}
          </Button>
        </DialogFooter>
      </Dialog>
    </PageShell>
  );
}
