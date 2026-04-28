#!/usr/bin/env bash
# Render envsubst .tpl files from $1 into $2.
# Required env: BRANCH ENVIRONMENT NAMESPACE BASE_DOMAIN
# Optional: HOST_PREFIX (empty for main), IMAGE_TAG (defaults to "latest")
set -euo pipefail

TEMPLATE_DIR="${1:?template dir required}"
OUT_DIR="${2:?output dir required}"

: "${BRANCH:?}"
: "${ENVIRONMENT:?}"
: "${NAMESPACE:?}"
: "${BASE_DOMAIN:?}"
: "${AWS_ACCESS_KEY_ID:?}"
: "${AWS_SECRET_ACCESS_KEY:?}"
HOST_PREFIX="${HOST_PREFIX-}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN-}"

export BRANCH ENVIRONMENT NAMESPACE HOST_PREFIX BASE_DOMAIN IMAGE_TAG
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
export APP1_HOST="app1${HOST_PREFIX}.${BASE_DOMAIN}"
export APP2_HOST="app2${HOST_PREFIX}.${BASE_DOMAIN}"
export APP3_HOST="app3${HOST_PREFIX}.${BASE_DOMAIN}"

mkdir -p "$OUT_DIR"
# Wipe before re-rendering so deletions in templates propagate.
find "$OUT_DIR" -mindepth 1 -delete

while IFS= read -r -d '' tpl; do
  rel="${tpl#$TEMPLATE_DIR/}"
  out="$OUT_DIR/${rel%.tpl}"
  mkdir -p "$(dirname "$out")"
  envsubst < "$tpl" > "$out"
done < <(find "$TEMPLATE_DIR" -type f -name '*.tpl' -print0)

echo "Rendered $(find "$OUT_DIR" -type f | wc -l) files into $OUT_DIR"
