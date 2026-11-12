# Jolom Admin

Panel anterior de moderación en Next.js. El panel principal está en [jolom-dashboard](../../jolom-dashboard/README.md).

Desde esta carpeta, con Node.js 22:

```bash
cp .env.example .env.local
npm ci
npm run dev -- --port 3002
```

Completa `.env.local` con la configuración pública de tu app Firebase Web. Abre <http://localhost:3002> y entra con una cuenta que tenga el claim `role: "admin"`. El panel requiere la Cloud Function `applyModerationAction` desplegada en ese mismo proyecto.
