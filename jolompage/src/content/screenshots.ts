export const showScreenshots = process.env.NEXT_PUBLIC_SHOW_SCREENSHOTS === "true";

export const screenshots = {
  inicio: {
    src: "/images/screenshots/01-inicio.png",
    alt: "Pantalla de inicio de Jolom",
  },
  explorar: {
    src: "/images/screenshots/02-explorar.png",
    alt: "Explorar barberías, peluquerías y salones en Jolom",
  },
  peluqueria: {
    src: "/images/screenshots/03-peluqueria.png",
    alt: "Detalle de un negocio en Jolom",
  },
  reservar: {
    src: "/images/screenshots/04-reservar.png",
    alt: "Reservar cita en Jolom",
  },
  negocio: {
    src: "/images/screenshots/07-negocio.png",
    alt: "Gestión de negocio en Jolom",
  },
  negocioEditar: {
    src: "/images/screenshots/08-negocio-editar.png",
    alt: "Editar negocio en Jolom",
  },
  disponibilidad: {
    src: "/images/screenshots/09-disponibilidad.png",
    alt: "Disponibilidad y horario en Jolom",
  },
  agenda: {
    src: "/images/screenshots/10-agenda.png",
    alt: "Agenda de citas en Jolom",
  },
} as const;

/** Capturas del flujo cliente (carrusel / hero). */
export const clientScreenshots = [
  screenshots.inicio,
  screenshots.explorar,
  screenshots.peluqueria,
  screenshots.reservar,
] as const;

/** Capturas del flujo peluquería. */
export const salonScreenshots = [
  screenshots.negocio,
  screenshots.disponibilidad,
  screenshots.agenda,
] as const;

/** Capturas para los pasos de “Cómo funciona”. */
export const howItWorksScreenshots = [
  screenshots.explorar,
  screenshots.peluqueria,
  screenshots.reservar,
] as const;
