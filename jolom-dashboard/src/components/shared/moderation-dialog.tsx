"use client";

import { useState } from "react";
import {
  callApplyModeration,
  type ModerationActionPayload,
} from "@/lib/firebase/client";
import { formatFirebaseError } from "@/lib/firebase/errors";
import { Button } from "@/components/ui/button";
import { Dialog, DialogFooter } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import type { ModerationActionType } from "@/types/firestore";

export type ModerationTarget = {
  targetType: ModerationActionPayload["targetType"];
  targetId: string;
  reportId?: string;
  label?: string;
};

const ACTION_LABELS: Record<ModerationActionType, string> = {
  warn: "Advertir",
  suspend: "Suspender",
  ban: "Bloquear cuenta",
  unban: "Desbloquear cuenta",
  unpublish: "Despublicar",
  softDelete: "Eliminar",
  restore: "Restaurar",
};

type ModerationDialogProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  target: ModerationTarget | null;
  allowedActions: ModerationActionType[];
  defaultAction?: ModerationActionType;
  /** Overrides for action option labels. */
  actionLabels?: Partial<Record<ModerationActionType, string>>;
  /** Extra context shown under the target description. */
  hint?: string;
  onSuccess?: () => void;
};

function labelFor(
  action: ModerationActionType,
  overrides?: Partial<Record<ModerationActionType, string>>,
) {
  return overrides?.[action] ?? ACTION_LABELS[action];
}

export function ModerationDialog({
  open,
  target,
  ...props
}: ModerationDialogProps) {
  if (!open || !target) return null;
  return (
    <ModerationDialogContent
      key={`${target.targetType}-${target.targetId}-${props.defaultAction ?? ""}`}
      {...props}
      target={target}
    />
  );
}

type ModerationDialogContentProps = Omit<
  ModerationDialogProps,
  "open" | "target"
> & { target: ModerationTarget };

function ModerationDialogContent({
  onOpenChange,
  target,
  allowedActions,
  defaultAction,
  actionLabels,
  hint,
  onSuccess,
}: ModerationDialogContentProps) {
  const [action, setAction] = useState<ModerationActionType>(
    defaultAction ?? allowedActions[0] ?? "warn",
  );
  const [reason, setReason] = useState("");
  const [scope, setScope] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    if (!reason.trim()) {
      setError("El motivo es obligatorio.");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await callApplyModeration({
        targetType: target.targetType,
        targetId: target.targetId,
        action,
        reason: reason.trim(),
        scope: scope.trim() || undefined,
        reportId: target.reportId,
        idempotencyKey: `${target.targetId}-${action}-${Date.now()}`,
      });
      setReason("");
      setScope("");
      onOpenChange(false);
      onSuccess?.();
    } catch (e) {
      setError(formatFirebaseError(e, "No se pudo aplicar la acción"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog
      open
      onOpenChange={onOpenChange}
      title="Confirmar acción de moderación"
      description={`Objetivo: ${target.label ?? `${target.targetType} ${target.targetId}`}`}
    >
      <div className="space-y-4">
        {hint ? (
          <p className="text-sm text-muted-foreground">{hint}</p>
        ) : null}
        <div className="space-y-1.5">
          <Label htmlFor="mod-action">Acción</Label>
          <Select
            id="mod-action"
            value={action}
            onChange={(e) => setAction(e.target.value as ModerationActionType)}
          >
            {allowedActions.map((a) => (
              <option key={a} value={a}>
                {labelFor(a, actionLabels)}
              </option>
            ))}
          </Select>
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="mod-reason">Motivo</Label>
          <Textarea
            id="mod-reason"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="Describe el motivo de la medida…"
            required
          />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="mod-scope">Alcance (opcional)</Label>
          <Input
            id="mod-scope"
            value={scope}
            onChange={(e) => setScope(e.target.value)}
            placeholder="p. ej. plataforma, reservas"
          />
        </div>
        {error ? (
          <p className="text-sm text-destructive" role="alert">
            {error}
          </p>
        ) : null}
      </div>
      <DialogFooter>
        <Button variant="outline" onClick={() => onOpenChange(false)} disabled={busy}>
          Cancelar
        </Button>
        <Button
          variant={
            action === "ban" || action === "softDelete"
              ? "destructive"
              : "primary"
          }
          onClick={submit}
          disabled={busy}
        >
          {busy ? "Aplicando…" : "Confirmar"}
        </Button>
      </DialogFooter>
    </Dialog>
  );
}

export { ACTION_LABELS };
