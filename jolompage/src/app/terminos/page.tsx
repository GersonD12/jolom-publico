import type { Metadata } from "next";
import { LegalPage } from "@/components/legal/legal-page";
import { site } from "@/content/site";

export const metadata: Metadata = {
  title: "Términos y condiciones",
  description:
    "Términos y condiciones de uso de Jolom para clientes, profesionales y negocios.",
};

const sections = [
  {
    title: "1. Aceptación",
    body: [
      "Al acceder o usar Jolom aceptas estos términos y cualquier política publicada en la app o en este sitio. Si no estás de acuerdo, no debes usar el servicio.",
      "Jolom es una plataforma tecnológica para descubrir barberías, peluquerías y salones, publicar negocios, gestionar servicios, horarios, disponibilidad y solicitudes de cita. No prestamos servicios de barbería, peluquería, estética, salud, pagos, transporte ni atención presencial.",
    ],
  },
  {
    title: "2. Usuarios, negocios y contenido",
    body: [
      "Cada usuario es responsable de la exactitud, legalidad y actualización de la información que publica, incluyendo nombre, fotos, precios, horarios, servicios, ubicación, disponibilidad, datos de contacto y cualquier descripción del negocio.",
      "Los negocios, propietarios, barberos, estilistas y demás profesionales actúan por cuenta propia. Jolom no garantiza licencias, permisos, identidad, calidad, seguridad, disponibilidad, resultados, precios, puntualidad ni conducta de usuarios o negocios.",
      "Podemos ocultar, suspender, eliminar o moderar cuentas, negocios, servicios, imágenes, reportes, citas o contenido cuando consideremos que incumplen estos términos, afectan la seguridad del servicio, generan riesgo legal o perjudican la experiencia de otros usuarios.",
    ],
  },
  {
    title: "3. Citas y relaciones entre usuarios",
    body: [
      "Las citas creadas en Jolom son solicitudes o registros operativos entre usuarios y negocios. Una cita puede quedar pendiente hasta que el negocio la confirme. La atención, cancelación, cambios, retrasos, cobros, reembolsos, reclamos y cualquier consecuencia derivada del servicio presencial son responsabilidad exclusiva del cliente y del negocio involucrado.",
      "Jolom puede mostrar recordatorios, notificaciones, disponibilidad, agenda y estadísticas, pero no garantiza que la información esté libre de errores, interrupciones, retrasos o conflictos de horario. Los usuarios deben verificar directamente los detalles importantes antes de presentarse o prestar un servicio.",
    ],
  },
  {
    title: "4. Datos y uso de la información",
    body: [
      "Al usar Jolom autorizas que recolectemos, almacenemos, procesemos, analicemos y usemos la información ingresada o generada en la plataforma para operar, proteger, mejorar, medir y desarrollar Jolom, incluyendo perfiles, negocios, servicios, citas, disponibilidad, imágenes, reportes, notificaciones, datos técnicos y métricas de uso.",
      "Podemos usar datos agregados, anonimizados o seudonimizados a nuestra discreción para análisis, estadísticas, mejora del producto, investigación, reportes internos, prevención de abuso, entrenamiento operativo y toma de decisiones del servicio. Cuando la ley aplicable exija consentimiento específico o permita ejercer derechos sobre datos personales, atenderemos esas solicitudes conforme a la política de privacidad.",
      "No debes subir información que no tengas derecho a usar ni datos sensibles de terceros sin autorización. Eres responsable de obtener los permisos necesarios sobre fotos, nombres, ubicaciones, textos, marcas, precios y datos de contacto que publiques.",
    ],
  },
  {
    title: "5. Propiedad intelectual y licencia",
    body: [
      "Jolom, su marca, diseño, código, interfaces, textos del sitio y elementos propios pertenecen a sus titulares. Estos términos no transfieren derechos de propiedad intelectual sobre Jolom.",
      "Al publicar contenido en Jolom nos otorgas una licencia mundial, no exclusiva, transferible, sublicenciable, libre de regalías y vigente mientras sea necesario para alojar, reproducir, mostrar, adaptar, comprimir, distribuir, moderar, promocionar y usar ese contenido en relación con Jolom y sus canales.",
    ],
  },
  {
    title: "6. Uso prohibido",
    body: [
      "No puedes usar Jolom para cometer fraude, acosar, suplantar identidades, publicar contenido falso, ofensivo, ilegal o engañoso, interferir con el servicio, extraer datos de forma abusiva, vulnerar sistemas, evadir medidas de seguridad o afectar derechos de terceros.",
      "Tampoco puedes usar la plataforma para ofrecer servicios ilegales, peligrosos o que requieran autorizaciones que no posees. Nos reservamos el derecho de restringir el acceso sin previo aviso cuando detectemos riesgos o incumplimientos.",
    ],
  },
  {
    title: "7. Disponibilidad y cambios",
    body: [
      "Jolom se ofrece en el estado en que se encuentre y según disponibilidad. Podemos modificar, pausar, retirar o limitar funciones, pantallas, integraciones, reglas, contenido o disponibilidad del servicio en cualquier momento.",
      "No garantizamos operación continua, compatibilidad con todos los dispositivos, ausencia de errores, conservación indefinida de datos, resultados específicos, incremento de clientes ni ingresos para negocios.",
    ],
  },
  {
    title: "8. Exclusión y limitación de responsabilidad",
    body: [
      "En la máxima medida permitida por la ley, Jolom y su desarrollador no serán responsables por daños, pérdidas, reclamos, lesiones, conflictos, incumplimientos, errores de información, cancelaciones, servicios mal prestados, cobros, disputas, pérdida de datos, lucro cesante, daño reputacional o cualquier consecuencia directa o indirecta derivada del uso de la app o de interacciones entre usuarios y negocios.",
      "La responsabilidad por los servicios presenciales, decisiones comerciales, información publicada, cumplimiento legal, permisos, higiene, seguridad, precios, impuestos, cobros y atención al cliente corresponde exclusivamente a cada negocio, profesional o usuario que participe en la relación.",
    ],
  },
  {
    title: "9. Indemnización",
    body: [
      "Aceptas defender, indemnizar y mantener libre de responsabilidad a Jolom, su desarrollador, colaboradores y proveedores frente a reclamos, pérdidas, costos, sanciones, honorarios o daños derivados de tu uso del servicio, tu contenido, tu negocio, tus citas, tus servicios presenciales, tu incumplimiento de estos términos o la vulneración de derechos de terceros.",
    ],
  },
  {
    title: "10. Terminación",
    body: [
      "Podemos suspender o cerrar cuentas, retirar negocios o limitar funciones cuando exista incumplimiento, abuso, riesgo técnico, riesgo legal, reportes, inactividad o cualquier situación que razonablemente afecte a Jolom o a otros usuarios.",
      "Puedes dejar de usar Jolom en cualquier momento y solicitar la eliminación de cuenta cuando la función esté disponible o escribiendo a soporte. Algunas referencias pueden conservarse si son necesarias para seguridad, auditoría, prevención de abuso, cumplimiento legal, resolución de disputas o estadísticas anonimizadas.",
    ],
  },
  {
    title: "11. Ley aplicable y contacto",
    body: [
      "Estos términos se interpretan conforme a las leyes aplicables de Guatemala, salvo que una norma obligatoria disponga otra cosa. Cualquier disputa deberá intentar resolverse primero de buena fe mediante contacto directo.",
      "Para consultas sobre estos términos puedes escribir a soporte@jolom.app.",
    ],
  },
] as const;

export default function TermsPage() {
  return (
    <LegalPage
      title="Términos y condiciones"
      updatedAt="28 de julio de 2026"
      intro={`Estos términos regulan el uso de ${site.name}. Están redactados para dejar claro que Jolom funciona como plataforma tecnológica y que cada usuario o negocio responde por lo que publica, agenda y presta fuera de la app.`}
      sections={sections}
    />
  );
}
