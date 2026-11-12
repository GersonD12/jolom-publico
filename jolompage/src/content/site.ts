export const site = {
  name: "Jolom",
  description:
    "Encuentra barberías, peluquerías y salones de belleza en Guatemala. Mira servicios y precios en quetzales, y reserva tu cita en minutos.",
  url: process.env.NEXT_PUBLIC_SITE_URL || "https://jolom.example",
  locale: "es",
  market: "Guatemala",
} as const;

export const nav = [
  { label: "Beneficios", href: "/#beneficios" },
  { label: "Cómo funciona", href: "/#como-funciona" },
  { label: "Para tu negocio", href: "/#para-peluquerias" },
] as const;

export const stores = {
  appStore: {
    label: "App Store",
    href:
      process.env.NEXT_PUBLIC_APP_STORE_URL ||
      "https://apps.apple.com/us/app/jolom/id6795984927",
  },
  googlePlay: {
    label: "Google Play",
    href:
      process.env.NEXT_PUBLIC_GOOGLE_PLAY_URL ||
      "https://play.google.com/store/apps/details?id=com.gersonpm.jolom&pcampaignid=web_share",
  },
} as const;

export const hero = {
  headline: "Barberías, peluquerías y salones cerca de ti",
  subcopy:
    "Explora negocios en Guatemala, mira servicios y precios en quetzales, y agenda en minutos. Sin llamadas ni idas y vueltas.",
} as const;

export const benefits = {
  title: "Todo lo que necesitas para tu próxima cita",
  items: [
    {
      id: "cercanas",
      title: "Negocios cerca de ti",
      description:
        "Descubre barberías, peluquerías y salones publicados cerca de ti. Entra a ver su perfil, fotos y horario.",
    },
    {
      id: "servicios-precios",
      title: "Servicios y precios claros",
      description:
        "Revisa qué ofrecen, cuánto dura cada servicio y el precio en quetzales antes de reservar.",
    },
    {
      id: "reservar",
      title: "Reserva tu cita",
      description:
        "Elige día, hora y envía tu solicitud. Queda pendiente hasta que el negocio la confirme.",
    },
    {
      id: "profesionales",
      title: "Elige al profesional",
      description:
        "Escoge un barbero o estilista del equipo, o deja que te atienda cualquiera disponible.",
    },
  ],
} as const;

export const howItWorks = {
  title: "Cómo funciona",
  steps: [
    {
      id: "encontrar",
      title: "Encuentra un negocio",
      description:
        "Explora el listado o abre un negocio con su código QR para ver su perfil.",
    },
    {
      id: "seleccionar",
      title: "Selecciona un servicio",
      description:
        "Elige el servicio, revisa duración y precio, y decide con qué profesional ir.",
    },
    {
      id: "agendar",
      title: "Agenda tu cita",
      description:
        "Toma un horario libre, reserva y recibe la confirmación cuando el negocio acepte.",
    },
  ],
} as const;

export const screenshotsSection = {
  title: "Así se ve Jolom",
  description:
    "Desde descubrir un negocio hasta confirmar tu cita, todo en la misma app.",
} as const;

export const forSalons = {
  title: "¿Tienes un negocio?",
  description:
    "Hecho para barberías, peluquerías y salones en Guatemala. Crea tu negocio con la misma cuenta y conserva el modo cliente. Publica tu perfil, define servicios y gestiona la agenda de tu equipo.",
  points: [
    "Publica u oculta tu negocio cuando quieras",
    "Agrega servicios con duración y precio en GTQ",
    "Configura horario, almuerzo y ausencias",
    "Confirma o rechaza solicitudes desde la agenda",
    "Invita a tu equipo y comparte tu código QR",
  ],
} as const;

export const finalCta = {
  title: "Encuentra tu próximo estilo con Jolom",
  description:
    "Descarga la app y reserva tu próxima cita en barberías, peluquerías y salones de Guatemala.",
} as const;

const supportEmail = process.env.NEXT_PUBLIC_SUPPORT_EMAIL;

export const footerNav = {
  legal: [
    { label: "Política de privacidad", href: "/privacidad" },
    { label: "Términos y condiciones", href: "/terminos" },
  ],
  support: supportEmail
    ? [{ label: "Soporte", href: `mailto:${supportEmail}` }]
    : [],
} as const;
