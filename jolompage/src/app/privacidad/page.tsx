import type { Metadata } from "next";
import { LegalPage } from "@/components/legal/legal-page";

export const metadata: Metadata = {
  title: "Política de privacidad",
  description:
    "Política de privacidad de Jolom sobre datos de usuarios, negocios, citas y uso de la plataforma.",
};

const sections = [
  {
    title: "1. Información que podemos recopilar",
    body: [
      "Podemos recopilar datos de cuenta como nombre, correo, teléfono, foto, estado de cuenta y tokens de notificación; datos de negocio como nombre, descripción, contacto, dirección, ciudad, ubicación, fotos, servicios, precios, horarios, equipo y disponibilidad; datos de citas como cliente, profesional, servicio, fecha, estado e historial; reportes, mensajes operativos, preferencias y datos técnicos de uso.",
      "También podemos recibir información técnica del dispositivo, sistema operativo, registros de errores, identificadores necesarios para notificaciones y métricas de interacción con la app.",
    ],
  },
  {
    title: "2. Para qué usamos los datos",
    body: [
      "Usamos la información para crear y administrar cuentas, publicar negocios, mostrar servicios, gestionar citas, disponibilidad y agenda, enviar notificaciones, atender soporte, procesar reportes, prevenir abuso, proteger la seguridad, depurar errores, mejorar funciones y medir el rendimiento de Jolom.",
      "Podemos usar información agregada, anonimizadas o seudonimizadas a nuestra discreción para estadísticas, análisis, investigación, desarrollo de producto y decisiones operativas, sin intentar identificar personalmente a usuarios cuando esos datos hayan sido anonimizados.",
    ],
  },
  {
    title: "3. Visibilidad y terceros",
    body: [
      "La información publicada por negocios puede ser visible para usuarios de Jolom, incluyendo fotos, servicios, precios, horarios, ubicación aproximada o datos de contacto. Las citas pueden ser visibles para las partes involucradas y para miembros autorizados del negocio.",
      "Podemos compartir datos con proveedores técnicos necesarios para operar Jolom, como servicios de autenticación, base de datos, almacenamiento, notificaciones, hosting, analítica, seguridad y soporte. Estos proveedores procesan información para permitir el funcionamiento de la plataforma.",
    ],
  },
  {
    title: "4. Conservación y eliminación",
    body: [
      "Conservamos información mientras sea necesaria para operar Jolom, cumplir obligaciones, resolver disputas, prevenir fraude o abuso, mantener seguridad, respaldar auditorías y generar estadísticas. Al eliminar una cuenta, podemos borrar datos personales o convertir referencias históricas en identificadores anónimos cuando sea necesario preservar integridad operativa.",
      "Algunos datos pueden permanecer en respaldos, registros técnicos o métricas agregadas durante un tiempo razonable, o conservarse cuando exista una obligación legal, reclamo pendiente, riesgo de seguridad o interés legítimo.",
    ],
  },
  {
    title: "5. Tus responsabilidades y derechos",
    body: [
      "Debes mantener tus datos actualizados y evitar publicar información de terceros sin permiso. Si administras un negocio, eres responsable de contar con autorización para publicar fotos, nombres, contactos, ubicación, precios, servicios y datos del equipo.",
      "Puedes solicitar acceso, corrección o eliminación de datos escribiendo a soporte@jolom.app. Atenderemos las solicitudes conforme a la ley aplicable y a las necesidades legítimas de seguridad, auditoría y operación.",
    ],
  },
  {
    title: "6. Seguridad",
    body: [
      "Aplicamos medidas razonables para proteger la información, pero ningún sistema es completamente seguro. No garantizamos que la app, la red, los dispositivos, proveedores externos o bases de datos estén libres de accesos no autorizados, fallas, pérdida de información o interrupciones.",
    ],
  },
  {
    title: "7. Cambios y contacto",
    body: [
      "Podemos actualizar esta política para reflejar cambios legales, técnicos u operativos. La versión vigente será la publicada en este sitio o dentro de la app.",
      "Para consultas de privacidad puedes escribir a soporte@jolom.app.",
    ],
  },
] as const;

export default function PrivacyPage() {
  return (
    <LegalPage
      title="Política de privacidad"
      updatedAt="28 de julio de 2026"
      intro="Esta política explica cómo Jolom puede recopilar, usar, conservar y proteger datos de usuarios, negocios, profesionales y citas dentro de la plataforma."
      sections={sections}
    />
  );
}
