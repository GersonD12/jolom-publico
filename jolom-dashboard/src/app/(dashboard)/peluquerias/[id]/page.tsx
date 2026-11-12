import type { Metadata } from "next";
import { SalonDetailPage } from "@/features/salons";

export const metadata: Metadata = {
  title: "Peluquería",
};

export default function Page() {
  return <SalonDetailPage />;
}
