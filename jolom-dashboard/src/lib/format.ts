import type { Timestamp } from "firebase/firestore";

export function formatTimestamp(
  value?: Timestamp | null,
  options?: Intl.DateTimeFormatOptions,
): string {
  if (!value) return "—";
  const date = value.toDate();
  return new Intl.DateTimeFormat("es-GT", {
    dateStyle: "medium",
    timeStyle: "short",
    ...options,
  }).format(date);
}

export function formatRelative(value?: Timestamp | null): string {
  if (!value) return "—";
  const ms = value.toDate().getTime() - Date.now();
  const rtf = new Intl.RelativeTimeFormat("es", { numeric: "auto" });
  const abs = Math.abs(ms);
  const minute = 60_000;
  const hour = 60 * minute;
  const day = 24 * hour;
  if (abs < hour) return rtf.format(Math.round(ms / minute), "minute");
  if (abs < day) return rtf.format(Math.round(ms / hour), "hour");
  return rtf.format(Math.round(ms / day), "day");
}
