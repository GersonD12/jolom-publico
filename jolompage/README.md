# Sitio de Jolom

Sitio informativo en Next.js. Usa Node.js 22 y pnpm 11.

```bash
pnpm install --frozen-lockfile
pnpm dev
```

Abre <http://localhost:3000>. Las variables de `.env.example` son opcionales. Copia la plantilla a `.env.local` si quieres configurar el dominio, el correo del pie de página o los enlaces de las tiendas. Los enlaces de tiendas tienen como valores iniciales las fichas públicas de Jolom. Ajusta también las páginas de términos y privacidad para tu despliegue.

El sitio arranca con las capturas desactivadas. Para mostrar capturas propias, coloca las imágenes en `public/images/screenshots/`, usa los nombres de `src/content/screenshots.ts` y activa `NEXT_PUBLIC_SHOW_SCREENSHOTS=true`.

```bash
pnpm build
```

Next.js genera el sitio estático en `out/`. Puedes probarlo con `pnpm preview` o publicar ese directorio en un hosting estático. Si configuras enlaces a tu app instalada, agrega los archivos de asociación de tu dominio en `public/.well-known/` con tus propios identificadores y certificados.

Si publicas fuera de Vercel, configura una reescritura de `/s/<id>` a la página estática `/s` para conservar los enlaces de negocios. La configuración de Vercel ya incluye esta regla.
