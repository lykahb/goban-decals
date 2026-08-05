#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
THEME_DIR="$SCRIPT_DIR/sabaki"
ASSET_DIR="$SCRIPT_DIR/assets"
OUTPUT=${1:-"$REPOSITORY_DIR/dist/sand-and-pebbles.asar"}
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/sand-and-pebbles.XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT HUP INT TERM

mkdir -p "$STAGING_DIR/LICENSES" "$STAGING_DIR/stones" "$(dirname -- "$OUTPUT")"
cp "$THEME_DIR/package.json" "$THEME_DIR/styles.css" \
  "$THEME_DIR/stone-variants.css" "$STAGING_DIR/"
cp "$ASSET_DIR/boards/"*.jpg "$STAGING_DIR/"
cp "$ASSET_DIR/stones/"*.png "$STAGING_DIR/stones/"
cp "$REPOSITORY_DIR/LICENSE.md" "$STAGING_DIR/LICENSE.md"
cp "$REPOSITORY_DIR/LICENSES/CC-BY-NC-4.0.txt" "$STAGING_DIR/LICENSES/"

if command -v asar >/dev/null 2>&1; then
  asar pack "$STAGING_DIR" "$OUTPUT"
else
  printf '%s\n' 'asar is not installed; invoking @electron/asar@4.2.1 with npx.' >&2
  npm_config_fetch_retries=0 \
    npm_config_fetch_timeout=10000 \
    npx --yes --prefer-offline @electron/asar@4.2.1 pack "$STAGING_DIR" "$OUTPUT"
fi

printf '%s\n' "$OUTPUT"
