import type { Metadata } from "next";
import { SalonsPage } from "@/features/salons";

export const metadata: Metadata = {
  title: "Peluquerías",
};

export default function Page() {
  return <SalonsPage />;
}
