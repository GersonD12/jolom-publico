import type { Metadata } from "next";
import { ReportsPage } from "@/features/reports";

export const metadata: Metadata = {
  title: "Reportes",
};

export default function Page() {
  return <ReportsPage />;
}
