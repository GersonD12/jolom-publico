import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Jolom Admin",
  description: "Dashboard de moderación Jolom",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="es">
      <body style={{ margin: 0 }}>{children}</body>
    </html>
  );
}
