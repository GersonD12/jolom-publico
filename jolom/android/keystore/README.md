# Firma Android de producción

Coloca aquí el upload keystore de Google Play, por ejemplo
`jolom-prod-upload.jks`. Los archivos `.jks` y `.keystore` están excluidos de
Git.

Después copia `android/key.properties.example` como `android/key.properties` y
reemplaza los cuatro valores. El comando `make build-android-prod` valida que
la configuración exista y nunca usa la llave debug como respaldo.

Guarda el keystore y sus contraseñas en un gestor seguro. Si Google Play App
Signing está activo, este archivo normalmente es la *upload key*, no la llave
final con la que Google firma la aplicación distribuida.
