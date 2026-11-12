# Jolom Dashboard

Panel de moderación para usuarios, negocios, reportes, eliminaciones y auditoría. Usa Node.js 22 y pnpm 11.

## Arranque local

1. Completa el [backend Firebase](../jolom/README.md). Registra una app Web en ese mismo proyecto. Activa el proveedor Google y autoriza `localhost` en Firebase Authentication.
2. Copia la plantilla y completa los seis valores públicos de la app Web que aparecen en Firebase Console.

   ```bash
   cp .env.example .env.development.local
   pnpm install --frozen-lockfile
   pnpm dev --port 3001
   ```

3. Abre <http://localhost:3001>. La cuenta de Firebase Auth necesita el custom claim `role: "admin"`. La acción de moderación usa la callable `applyModerationAction` del mismo proyecto.

## Asignar el rol

Usa una cuenta de servicio autorizada sobre tu proyecto. Guarda su credencial fuera del repositorio y obtén el UID de la cuenta desde Firebase Authentication.

```bash
FIREBASE_PROJECT_ID_DEV=tu-proyecto-dev \
FIREBASE_SERVICE_ACCOUNT_DEV=/ruta/segura/credencial.json \
pnpm set-admin dev TU_UID
```

El script verifica el proyecto de la credencial y conserva los demás claims. Cierra sesión y vuelve a entrar para renovar el token. Para producción usa `prod`, `FIREBASE_PROJECT_ID_PROD` y `FIREBASE_SERVICE_ACCOUNT_PROD`.

Para compilar con tu configuración de producción, completa `.env.production.local` y ejecuta `pnpm build`. Puedes iniciar esa compilación con `pnpm start --port 3001`.
