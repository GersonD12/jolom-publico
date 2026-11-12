import type { Metadata } from "next";
import { UserDetailPage } from "@/features/users";

export const metadata: Metadata = {
  title: "Usuario",
};

export default function Page() {
  return <UserDetailPage />;
}
