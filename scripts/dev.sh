#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB="$ROOT/../virtual-binder-web"
MOBILE="$ROOT/../virtual-binder-mobile"

for command in docker node npm; do
  command -v "$command" >/dev/null || {
    echo "Falta el comando: $command" >&2
    exit 1
  }
done

for project in "$WEB" "$MOBILE"; do
  test -f "$project/package.json" || {
    echo "No se encontró $project/package.json" >&2
    exit 1
  }
done

cd "$ROOT"
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

docker compose up --build -d api db

pids=()
cleanup() {
  trap - EXIT INT TERM
  for pid in "${pids[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
  docker compose stop api db >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

export NEXT_PUBLIC_API_URL="${NEXT_PUBLIC_API_URL:-http://localhost:8000}"
export EXPO_PUBLIC_API_URL="${EXPO_PUBLIC_API_URL:-http://10.0.2.2:8000}"

cd "$WEB"
npm run dev -- --hostname 0.0.0.0 &
pids+=("$!")

cd "$MOBILE"
npm start -- --host lan &
pids+=("$!")

printf '\nVirtual Binder está disponible:\n'
printf '  Web:    http://localhost:3000\n'
printf '  API:    http://localhost:8000/docs\n'
printf '  Expo:   escanea el código QR con Expo Go\n'
printf '  DB:     postgresql://virtual_binder@localhost:5432/virtual_binder\n'
printf '\nPresiona Ctrl+C para detener todos los servicios.\n\n'

wait -n "${pids[@]}"
