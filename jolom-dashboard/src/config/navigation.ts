export type NavItem = {
  href: string;
  label: string;
  icon?: string;
};

export const navigation: NavItem[] = [
  { href: "/resumen", label: "Resumen", icon: "overview" },
  { href: "/reportes", label: "Reportes y casos", icon: "reports" },
  { href: "/usuarios", label: "Usuarios", icon: "users" },
  { href: "/peluquerias", label: "Peluquerías", icon: "salons" },
  { href: "/eliminaciones", label: "Eliminaciones", icon: "deletions" },
  { href: "/auditoria", label: "Auditoría", icon: "audit" },
  { href: "/configuracion", label: "Configuración", icon: "settings" },
];
