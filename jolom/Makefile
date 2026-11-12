DEV_PROJECT = $(shell node -p "require('fs').existsSync('.firebaserc') ? JSON.parse(require('fs').readFileSync('.firebaserc')).projects?.dev ?? '' : ''")
PROD_PROJECT = $(shell node -p "require('fs').existsSync('.firebaserc') ? JSON.parse(require('fs').readFileSync('.firebaserc')).projects?.prod ?? '' : ''")
SITE_URL ?= https://jolom.example

SHELL := /bin/bash

help:
	@echo "Desarrollo:"
	@echo "  make run-dev                 Ejecutar com.example.jolom"
	@echo "  make build-android-dev       Generar APK de desarrollo"
	@echo "  make build-ios-dev           Compilar iOS de desarrollo"
	@echo ""
	@echo "Producción:"
	@echo "  make run-prod                Ejecutar com.example.jolom.prod"
	@echo "  make build-android-prod      Generar AAB firmado para Google Play"
	@echo "  make build-ios-prod          Generar IPA de producción"
	@echo ""
	@echo "Firebase SDK (configuración inicial o rotación):"
	@echo "  make flutterfire-dev         Configurar Firebase dev"
	@echo "  make flutterfire-prod        Configurar Firebase prod"
	@echo "  make firebase-dev ANDROID_CONFIG=/ruta/google-services.json IOS_CONFIG=/ruta/GoogleService-Info.plist"
	@echo "  make firebase-prod ANDROID_CONFIG=/ruta/google-services.json IOS_CONFIG=/ruta/GoogleService-Info.plist"
	@echo "  make maps-dev                Guardar claves Maps locales de desarrollo"
	@echo "  make maps-prod               Guardar claves Maps locales de producción"
	@echo ""
	@echo "Despliegues Firebase:"
	@echo "  make deploy-function-dev FUNCTION=nombre | deploy-function-prod FUNCTION=nombre"
	@echo "  make deploy-functions-dev | deploy-functions-prod"
	@echo "  make deploy-rules-dev     | deploy-rules-prod"
	@echo "  make deploy-all-dev       | deploy-all-prod"

flutterfire-dev:
	@test -n "$(DEV_PROJECT)" && test "$(DEV_PROJECT)" != TU_PROYECTO_DEV || (echo "Configura el alias dev en .firebaserc."; exit 1)
	@flutterfire configure --yes --project="$(DEV_PROJECT)" --platforms=android,ios --android-package-name=com.example.jolom --android-out=android/app/src/dev/google-services.json --ios-bundle-id=com.example.jolom --ios-build-config=Release-dev --ios-out=ios/config/dev/GoogleService-Info.plist --out=lib/firebase_options_dev.dart
	@./scripts/configure-firebase.sh dev

flutterfire-prod:
	@test -n "$(PROD_PROJECT)" && test "$(PROD_PROJECT)" != TU_PROYECTO_PROD || (echo "Configura el alias prod en .firebaserc."; exit 1)
	@flutterfire configure --yes --project="$(PROD_PROJECT)" --platforms=android,ios --android-package-name=com.example.jolom.prod --android-out=android/app/src/prod/google-services.json --ios-bundle-id=com.example.jolom.prod --ios-build-config=Release-prod --ios-out=ios/config/prod/GoogleService-Info.plist --out=lib/firebase_options_prod.dart
	@./scripts/configure-firebase.sh prod

firebase-dev:
	@./scripts/configure-firebase.sh dev "$(ANDROID_CONFIG)" "$(IOS_CONFIG)"

firebase-prod:
	@./scripts/configure-firebase.sh prod "$(ANDROID_CONFIG)" "$(IOS_CONFIG)"

maps-dev:
	@./scripts/configure-maps.sh dev

maps-prod:
	@./scripts/configure-maps.sh prod

run-dev:
	@./scripts/check-environment.sh dev android
	@flutter run --flavor dev --dart-define=APP_ENV=dev --dart-define=APP_ID=com.example.jolom --dart-define=JOLOM_SITE_URL="$(SITE_URL)"

run-prod:
	@./scripts/check-environment.sh prod android
	@flutter run --flavor prod --dart-define=APP_ENV=prod --dart-define=APP_ID=com.example.jolom.prod --dart-define=JOLOM_SITE_URL="$(SITE_URL)"

build-android-dev:
	@./scripts/check-environment.sh dev android
	@flutter build apk --flavor dev --debug --dart-define=APP_ENV=dev --dart-define=APP_ID=com.example.jolom --dart-define=JOLOM_SITE_URL="$(SITE_URL)"

build-android-prod:
	@./scripts/check-environment.sh prod android --signing
	@flutter build appbundle --flavor prod --release --dart-define=APP_ENV=prod --dart-define=APP_ID=com.example.jolom.prod --dart-define=JOLOM_SITE_URL="$(SITE_URL)"

build-ios-dev:
	@./scripts/check-environment.sh dev ios
	@flutter build ios --simulator --flavor dev --debug --dart-define=APP_ENV=dev --dart-define=APP_ID=com.example.jolom --dart-define=JOLOM_SITE_URL="$(SITE_URL)"

build-ios-prod:
	@./scripts/check-environment.sh prod ios
	@flutter build ipa --flavor prod --release --dart-define=APP_ENV=prod --dart-define=APP_ID=com.example.jolom.prod --dart-define=JOLOM_SITE_URL="$(SITE_URL)"

deploy-functions-dev:
	@./scripts/firebase-deploy.sh dev functions

deploy-functions-prod:
	@./scripts/firebase-deploy.sh prod functions

deploy-function-dev:
	@./scripts/firebase-deploy.sh dev function "$(FUNCTION)"

deploy-function-prod:
	@./scripts/firebase-deploy.sh prod function "$(FUNCTION)"

deploy-rules-dev:
	@./scripts/firebase-deploy.sh dev rules

deploy-rules-prod:
	@./scripts/firebase-deploy.sh prod rules

deploy-all-dev:
	@./scripts/firebase-deploy.sh dev all

deploy-all-prod:
	@./scripts/firebase-deploy.sh prod all
