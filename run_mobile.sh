#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing .env file at $ENV_FILE"
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

if [[ -z "${GROQ_API_KEY:-}" ]]; then
  echo "GROQ_API_KEY is not set in .env"
  exit 1
fi

cd "$ROOT_DIR/mobile_app"
flutter run \
  --dart-define=GROQ_API_KEY="$GROQ_API_KEY" \
  --dart-define=GROQ_MODEL="${GROQ_MODEL:-llama-3.3-70b-versatile}"
