# Jolom

Plataforma de reservas para barberías, peluquerías y salones. Este repositorio reúne la aplicación móvil, el backend Firebase, el panel de moderación y el sitio informativo.

| Carpeta | Contenido |
| --- | --- |
| [jolom](jolom/README.md) | App Flutter para Android e iOS, Cloud Functions, reglas e índices de Firebase. |
| [jolom-dashboard](jolom-dashboard/README.md) | Panel administrativo en Next.js para revisar usuarios, negocios y reportes. |
| [jolompage](jolompage/README.md) | Sitio informativo en Next.js. Puede arrancar sin Firebase. |

El panel anterior también se conserva en [jolom/admin](jolom/admin/README.md).

## Primer arranque

- **Sitio informativo.** Desde `jolompage/`, ejecuta `pnpm install --frozen-lockfile` y `pnpm dev`. Abre <http://localhost:3000>.
- **App y panel.** Crea un proyecto Firebase de desarrollo. Prepara el [backend y la app móvil](jolom/README.md). Luego configura el [panel administrativo](jolom-dashboard/README.md) para el mismo proyecto.

Usa Node.js 22 y pnpm 11 para el sitio, el panel y las Functions. La app móvil requiere un Flutter que incluya Dart 3.10.7 o posterior dentro de la serie 3.x.

## Licencia y créditos

El código original de Jolom se comparte bajo [MIT-0](LICENSE). Puedes usarlo, modificarlo y redistribuirlo. Si quieres mencionar el proyecto original, se agradece un crédito a **Gerson y al proyecto Jolom**. La mención es opcional.

Las dependencias y otros materiales de terceros conservan sus propias licencias.
## Nombre y logotipos

Jolom es un proyecto creado por Gerson. La licencia MIT-0 cubre el
código fuente original. El nombre Jolom, sus logotipos y sus iconos
de marca quedan excluidos de esa licencia.

Puedes mencionar a Jolom al dar crédito al proyecto original.
Si publicas una versión derivada, usa tu propio nombre y logotipos,
salvo que tengas autorización expresa para usar los de Jolom.
