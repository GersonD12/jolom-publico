# App móvil y backend Firebase

La app tiene dos perfiles. Para empezar basta con configurar `dev`.

| Perfil | ID predeterminado |
| --- | --- |
| `dev` | `com.example.jolom` |
| `prod` | `com.example.jolom.prod` |

## Backend

1. Crea tu proyecto Firebase. Habilita Firestore y Storage. En Authentication, activa Google y los proveedores que quieras usar. Registra las apps Android, iOS o Web que vayas a ejecutar.
2. Desde esta carpeta, copia `.firebaserc.example` a `.firebaserc`. Completa `default` y `dev` con el ID de tu proyecto. Completa `prod` cuando tengas un proyecto de producción.
3. Instala las dependencias. Puedes ejecutar las pruebas o arrancar los emuladores para trabajar con datos locales.

   ```bash
   pnpm --dir functions install --frozen-lockfile
   pnpm --dir functions test
   pnpm --dir functions exec firebase emulators:start --config ../firebase.json --project demo-jolom
   ```

   La app y el dashboard usan el proyecto indicado por su configuración Firebase. Para conectarlos a los emuladores hace falta configurar sus SDK para usar los endpoints locales. Consulta la [documentación de Emulator Suite](https://firebase.google.com/docs/emulator-suite/connect_and_prototype).

4. Si vas a probar con un proyecto Firebase alojado, inicia sesión y despliega las funciones, reglas e índices en tu proyecto de desarrollo. Cloud Functions requiere facturación habilitada.

   ```bash
   pnpm --dir functions exec firebase login
   make deploy-all-dev
   ```

   Si el proyecto requiere configurar el acceso de invocación de alguna callable Gen 2, revisa su servicio en Cloud Run y conserva los controles de autenticación y autorización de Firebase en la función. Consulta la [documentación de invocación de Cloud Run](https://cloud.google.com/run/docs/authenticating/public).

## Android

Necesitas Flutter con Dart 3.10.7 o posterior dentro de la serie 3.x, el SDK de Android y JDK 17.

1. Registra `com.example.jolom` como app Android en tu Firebase de desarrollo. Para Google Sign-In, registra las huellas SHA-1 y SHA-256 de la firma que uses y descarga el `google-services.json` actualizado.
2. Guarda ese archivo en `android/app/src/dev/google-services.json`. Copia `android/maps-dev.properties.example` a `android/maps-dev.properties` y completa la clave de Maps SDK for Android, restringida al paquete y firma de desarrollo.
3. Con un emulador o dispositivo Android disponible, ejecuta:

   ```bash
   flutter pub get
   make run-dev
   ```

## iOS

Necesitas macOS, Xcode y CocoaPods. El proyecto declara iOS 15 como mínimo.

1. Registra el bundle `com.example.jolom` en Firebase. Activa Google Sign-In antes de descargar `GoogleService-Info.plist` para que incluya `REVERSED_CLIENT_ID`.
2. Desde esta carpeta, instala el plist y genera la configuración del URL scheme:

   ```bash
   make firebase-dev IOS_CONFIG=/ruta/a/GoogleService-Info.plist
   ```

3. Copia `ios/Flutter/Maps-dev.xcconfig.example` a `ios/Flutter/Maps-dev.xcconfig` y completa la clave de Maps SDK for iOS, restringida al bundle.
4. Ejecuta:

   ```bash
   flutter pub get
   flutter run --flavor dev --dart-define=APP_ENV=dev
   ```

Para ejecutar en un iPhone, selecciona tu equipo de firma en `ios/Runner.xcworkspace`. Configura APNs y las capacidades de la app en tu cuenta de Apple para probar notificaciones. Consulta las guías de [Firebase para Flutter](https://firebase.google.com/docs/flutter/setup) y [Google Maps para Flutter](https://developers.google.com/maps/flutter-package/config).

## Enlaces y producción

- Pasa `SITE_URL=https://tu-dominio.example` al Makefile o `--dart-define=JOLOM_SITE_URL=https://tu-dominio.example` a Flutter para usar el sitio de tu despliegue. Para abrir enlaces directamente en la app, configura Android App Links y Apple Universal Links con tu dominio, bundle y firma. El host del sitio se configura en la propiedad Gradle `jolomSiteHost` y el ajuste Xcode `JOLOM_SITE_HOST`.
- El acceso por correo requiere configurar los enlaces de Firebase Auth y publicar la página de destino en tu Hosting. Consulta la [guía de acceso por correo](https://firebase.google.com/docs/auth/flutter/email-link-auth).
- Para `prod`, registra las apps con el identificador de producción, instala su configuración Firebase y Maps y configura tu firma. Si cambias los identificadores, actualiza los ajustes nativos, el Makefile y los scripts de validación. El valor de `APP_ID` debe coincidir con el paquete o bundle efectivo.
- Para compilar, usa `make build-android-dev`, `make build-ios-dev`, `make build-android-prod` o `make build-ios-prod`. Para Android de producción, completa `android/key.properties` con la plantilla que se incluye y mantén el keystore en una ruta local segura.
