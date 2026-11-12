import type { Metadata } from "next";
import { ReportDetailPage } from "@/features/reports";

export const metadata: Metadata = {
  title: "Detalle de reporte",
};

export default function Page() {
  return <ReportDetailPage />;
}
