import type { Metadata } from "next";
import { AppConfigPage } from "@/features/app-config";

export const metadata: Metadata = {
  title: "Configuración",
};

export default function Page() {
  return <AppConfigPage />;
}
