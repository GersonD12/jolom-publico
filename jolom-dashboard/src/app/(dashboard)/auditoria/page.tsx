import type { Metadata } from "next";
import { AuditPage } from "@/features/audit";

export const metadata: Metadata = {
  title: "Auditoría",
};

export default function Page() {
  return <AuditPage />;
}
