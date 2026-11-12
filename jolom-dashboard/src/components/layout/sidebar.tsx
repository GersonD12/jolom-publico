"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  ClipboardList,
  LayoutDashboard,
  Scissors,
  Settings,
  ShieldAlert,
  Trash2,
  Users,
  type LucideIcon,
} from "lucide-react";
import { navigation } from "@/config/navigation";
import { cn } from "@/lib/utils/cn";

const ICONS: Record<string, LucideIcon> = {
  overview: LayoutDashboard,
  reports: ClipboardList,
  users: Users,
  salons: Scissors,
  deletions: Trash2,
  audit: ShieldAlert,
  settings: Settings,
};

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="flex w-56 shrink-0 flex-col border-r border-sidebar-border bg-sidebar">
      <div className="flex h-14 items-center border-b border-sidebar-border px-4">
        <Link
          href="/resumen"
          className="flex items-center gap-2.5 text-base font-semibold tracking-tight text-sidebar-accent-foreground"
        >
          <Image
            src="/icons/icon-192.png"
            alt=""
            width={28}
            height={28}
            className="size-7 shrink-0"
            priority
          />
          <span>Jolom Admin</span>
        </Link>
      </div>
      <nav className="flex flex-1 flex-col gap-0.5 p-2" aria-label="Principal">
        {navigation.map((item) => {
          const Icon = (item.icon && ICONS[item.icon]) || LayoutDashboard;
          const active =
            pathname === item.href || pathname.startsWith(`${item.href}/`);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-2 rounded-md px-3 py-2 text-sm font-medium transition-colors",
                active
                  ? "bg-sidebar-accent text-sidebar-accent-foreground"
                  : "text-sidebar-foreground hover:bg-secondary",
              )}
              aria-current={active ? "page" : undefined}
            >
              <Icon className="h-4 w-4 shrink-0" aria-hidden />
              {item.label}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
