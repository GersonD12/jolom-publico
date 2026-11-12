import type { Metadata } from "next";
import { DeletionsPage } from "@/features/deletions";

export const metadata: Metadata = {
  title: "Eliminaciones",
};

export default function Page() {
  return <DeletionsPage />;
}
