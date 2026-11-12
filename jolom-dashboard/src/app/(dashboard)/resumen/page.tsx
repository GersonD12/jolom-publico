import type { Metadata } from "next";
import { OverviewPage } from "@/features/overview";

export const metadata: Metadata = {
  title: "Resumen",
};

export default function Page() {
  return <OverviewPage />;
}
