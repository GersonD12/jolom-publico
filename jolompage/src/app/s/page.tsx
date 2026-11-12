import type { Metadata } from "next";
import Image from "next/image";
import { ShareLinkQr } from "@/components/share-link-qr";
import { StoreButtons } from "@/components/store-buttons";

export const metadata: Metadata = {
  title: "Este contenido está en la app",
  description:
    "Descarga Jolom para encontrar el negocio, servicio o perfil que te compartieron.",
  robots: {
    index: false,
    follow: true,
  },
};

const reasons = [
  "Encuentra el negocio que te compartieron",
  "Consulta sus servicios, precios y horarios",
  "Reserva tu próxima cita desde la app",
] as const;

export default function SharedLinkPage() {
  return (
    <section className="relative isolate flex min-h-[calc(100svh-4rem)] items-center overflow-hidden px-6 py-14 sm:py-20">
      <div className="pointer-events-none absolute inset-0 -z-20 bg-background" />
      <div className="pointer-events-none absolute -right-32 -top-32 -z-10 h-96 w-96 rounded-full bg-primary-container/70 blur-3xl" />
      <div className="pointer-events-none absolute -bottom-44 -left-24 -z-10 h-96 w-96 rounded-full bg-secondary-container/45 blur-3xl" />

      <div className="mx-auto grid w-full max-w-5xl items-center gap-10 lg:grid-cols-[1.05fr_0.95fr] lg:gap-16">
        <div>
          <div className="inline-flex items-center gap-2 rounded-full border border-brand/20 bg-card/80 px-3 py-1.5 text-sm font-medium text-primary shadow-sm backdrop-blur">
            <span className="h-2 w-2 rounded-full bg-brand" aria-hidden="true" />
            Te compartieron algo en Jolom
          </div>

          <h1 className="mt-6 max-w-2xl text-4xl font-semibold tracking-tight text-balance text-foreground sm:text-5xl lg:text-6xl">
            Este contenido está en la app de Jolom
          </h1>
          <p className="mt-6 max-w-xl text-lg leading-8 text-pretty text-muted">
            Descarga Jolom para encontrar el negocio, servicio o perfil que te
            compartieron y tener todo lo necesario para tu próxima cita.
          </p>

          <ul className="mt-8 space-y-4" aria-label="Lo que puedes hacer en Jolom">
            {reasons.map((reason) => (
              <li key={reason} className="flex items-start gap-3 text-foreground">
                <span
                  aria-hidden="true"
                  className="mt-0.5 grid h-6 w-6 shrink-0 place-items-center rounded-full bg-tertiary-container text-sm font-bold text-tertiary"
                >
                  ✓
                </span>
                <span className="leading-6">{reason}</span>
              </li>
            ))}
          </ul>
        </div>

        <div className="rounded-[2rem] border border-outline/20 bg-card/90 p-6 shadow-[0_24px_80px_rgba(0,80,95,0.12)] backdrop-blur sm:p-8">
          <div className="flex items-center gap-4">
            <div className="grid h-14 w-14 shrink-0 place-items-center overflow-hidden rounded-2xl bg-primary-container p-2">
              <Image
                src="/images/icon.png"
                alt=""
                width={48}
                height={48}
                className="h-full w-full object-contain"
              />
            </div>
            <div>
              <p className="text-sm font-medium text-brand">Jolom · Guatemala</p>
              <h2 className="mt-0.5 text-xl font-semibold tracking-tight text-foreground">
                Descarga la app para continuar
              </h2>
            </div>
          </div>

          <p className="mt-6 text-sm leading-6 text-muted">
            Jolom te ayuda a descubrir barberías, peluquerías y salones, revisar
            sus servicios y reservar citas desde tu teléfono.
          </p>

          <StoreButtons className="mt-6 flex flex-col gap-3 sm:flex-row lg:flex-col xl:flex-row" />

          <ShareLinkQr />

          <p className="mt-6 border-t border-outline/15 pt-5 text-center text-xs leading-5 text-muted">
            La descarga te llevará a la tienda oficial correspondiente a tu
            dispositivo.
          </p>
        </div>
      </div>
    </section>
  );
}
