#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Uso: $0 <dev|prod> <function|functions|rules|all> [nombre_función]" >&2
  exit 64
fi

environment="$1"
scope="$2"
function_name="${3:-}"
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$environment" in
  dev|prod) ;;
  *)
    echo "Entorno inválido: $environment (usa dev o prod)." >&2
    exit 64
    ;;
esac

case "$scope" in
  functions) only="functions" ;;
  function)
    if [[ -z "$function_name" || ! "$function_name" =~ ^[A-Za-z0-9_-]+$ ]]; then
      echo "Para publicar una Function indica un nombre válido, por ejemplo: requestAccountDeletion" >&2
      exit 64
    fi
    only="functions:$function_name"
    ;;
  rules) only="firestore:rules,firestore:indexes,storage" ;;
  all) only="functions,firestore:rules,firestore:indexes,storage" ;;
  *)
    echo "Alcance inválido: $scope (usa function, functions, rules o all)." >&2
    exit 64
    ;;
esac

if [[ "$scope" != "function" && -n "$function_name" ]]; then
  echo "El nombre de Function solo se admite con el alcance 'function'." >&2
  exit 64
fi

deployment_label="$scope"
if [[ "$scope" == "function" ]]; then
  deployment_label="function $function_name"
fi

project_id="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); console.log(c.projects?.[process.argv[2]] ?? '')" "$project_root/.firebaserc" "$environment")"
if [[ -z "$project_id" || "$project_id" == TU_* ]]; then
  echo "Configura el alias '$environment' con el project ID real en .firebaserc." >&2
  exit 1
fi

if [[ "$environment" == "prod" && "${CONFIRM_PROD:-}" != "1" ]]; then
  if [[ ! -t 0 ]]; then
    echo "Producción requiere CONFIRM_PROD=1 en ejecución no interactiva." >&2
    exit 1
  fi
  read -r -p "Se publicará '$deployment_label' en $project_id. Escribe prod para continuar: " answer
  if [[ "$answer" != "prod" ]]; then
    echo "Publicación cancelada."
    exit 1
  fi
fi

if [[ -x "$project_root/functions/node_modules/.bin/firebase" ]]; then
  firebase_cli="$project_root/functions/node_modules/.bin/firebase"
elif command -v firebase >/dev/null 2>&1; then
  firebase_cli="$(command -v firebase)"
else
  echo "No se encontró Firebase CLI. Ejecuta npm install dentro de functions/." >&2
  exit 1
fi

echo "Publicando $deployment_label en $environment ($project_id)..."
"$firebase_cli" deploy --config "$project_root/firebase.json" --project "$project_id" --only "$only"
