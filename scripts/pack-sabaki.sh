#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  scripts/pack-sabaki.sh \
    --sabaki DIR \
    --boards DIR \
    --stones DIR \
    [--output FILE]

Packages one Sabaki theme from independently located theme files, boards, and
stones. The default output is dist/<package.json name>.asar.
EOF
}

fail() {
  printf 'pack-sabaki: %s\n' "$1" >&2
  exit 1
}

require_value() {
  [ "$#" -ge 2 ] || fail "missing value for $1"
}

SABAKI_INPUT=
BOARDS_INPUT=
STONES_INPUT=
OUTPUT=

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sabaki)
      require_value "$@"
      SABAKI_INPUT=$2
      shift 2
      ;;
    --boards)
      require_value "$@"
      BOARDS_INPUT=$2
      shift 2
      ;;
    --stones)
      require_value "$@"
      STONES_INPUT=$2
      shift 2
      ;;
    --output)
      require_value "$@"
      OUTPUT=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[ -n "$SABAKI_INPUT" ] || fail "--sabaki is required"
[ -n "$BOARDS_INPUT" ] || fail "--boards is required"
[ -n "$STONES_INPUT" ] || fail "--stones is required"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
SABAKI_DIR=$(CDPATH= cd -- "$SABAKI_INPUT" && pwd) || \
  fail "Sabaki directory does not exist: $SABAKI_INPUT"
BOARDS_DIR=$(CDPATH= cd -- "$BOARDS_INPUT" && pwd) || \
  fail "board directory does not exist: $BOARDS_INPUT"
STONES_DIR=$(CDPATH= cd -- "$STONES_INPUT" && pwd) || \
  fail "stone directory does not exist: $STONES_INPUT"
PACKAGE_FILE="$SABAKI_DIR/package.json"

[ -f "$PACKAGE_FILE" ] || fail "missing package metadata: $PACKAGE_FILE"
[ -f "$REPOSITORY_DIR/LICENSE.md" ] || fail "missing repository LICENSE.md"
[ -f "$REPOSITORY_DIR/LICENSES/CC-BY-NC-4.0.txt" ] || \
  fail "missing CC-BY-NC-4.0 license text"
command -v node >/dev/null 2>&1 || fail "Node.js is required to read package.json"

PACKAGE_NAME=$(node -e '
  const fs = require("fs");
  const value = JSON.parse(fs.readFileSync(process.argv[1], "utf8")).name;
  if (typeof value !== "string") process.exit(1);
  process.stdout.write(value);
' "$PACKAGE_FILE") || fail "package.json must contain a string name"

PACKAGE_MAIN=$(node -e '
  const fs = require("fs");
  const value = JSON.parse(fs.readFileSync(process.argv[1], "utf8")).main;
  if (typeof value !== "string") process.exit(1);
  process.stdout.write(value);
' "$PACKAGE_FILE") || fail "package.json must contain a string main entry"

case "$PACKAGE_NAME" in
  ''|*[!a-z0-9-]*) fail "package name must contain only lowercase letters, numbers, and hyphens" ;;
esac

[ "$PACKAGE_MAIN" = "${PACKAGE_MAIN##*/}" ] || \
  fail "package main must name a CSS file in the Sabaki directory"
[ -f "$SABAKI_DIR/$PACKAGE_MAIN" ] || fail "package main does not exist: $PACKAGE_MAIN"

if [ -z "$OUTPUT" ]; then
  OUTPUT="$REPOSITORY_DIR/dist/$PACKAGE_NAME.asar"
fi

mkdir -p "$(dirname -- "$OUTPUT")"
OUTPUT_DIR=$(CDPATH= cd -- "$(dirname -- "$OUTPUT")" && pwd)
OUTPUT="$OUTPUT_DIR/${OUTPUT##*/}"
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/goban-decals-sabaki.XXXXXX")
ARCHIVE_DIR=$(mktemp -d "$OUTPUT_DIR/.sabaki-pack.XXXXXX")
TEMP_ARCHIVE="$ARCHIVE_DIR/${OUTPUT##*/}"

cleanup() {
  rm -rf "$STAGING_DIR" "$ARCHIVE_DIR"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$STAGING_DIR/LICENSES" "$STAGING_DIR/stones"
cp "$PACKAGE_FILE" "$STAGING_DIR/package.json"

CSS_COUNT=0
for css_file in "$SABAKI_DIR/"*.css; do
  [ -f "$css_file" ] || continue
  cp "$css_file" "$STAGING_DIR/"
  CSS_COUNT=$((CSS_COUNT + 1))
done
[ "$CSS_COUNT" -gt 0 ] || fail "no CSS files found in $SABAKI_DIR"

copy_images() {
  source_dir=$1
  destination_dir=$2
  copied=0

  for extension in png jpg jpeg webp; do
    for image_file in "$source_dir"/*."$extension"; do
      [ -f "$image_file" ] || continue
      cp "$image_file" "$destination_dir/"
      copied=$((copied + 1))
    done
  done

  [ "$copied" -gt 0 ] || fail "no supported images found in $source_dir"
}

copy_images "$BOARDS_DIR" "$STAGING_DIR"
copy_images "$STONES_DIR" "$STAGING_DIR/stones"
cp "$REPOSITORY_DIR/LICENSE.md" "$STAGING_DIR/LICENSE.md"
cp "$REPOSITORY_DIR/LICENSES/CC-BY-NC-4.0.txt" "$STAGING_DIR/LICENSES/"

if command -v asar >/dev/null 2>&1; then
  asar pack "$STAGING_DIR" "$TEMP_ARCHIVE"
else
  printf '%s\n' 'asar is not installed; invoking @electron/asar@4.2.1 with npx.' >&2
  npm_config_fetch_retries=0 \
    npm_config_fetch_timeout=10000 \
    npx --yes --prefer-offline @electron/asar@4.2.1 pack "$STAGING_DIR" "$TEMP_ARCHIVE"
fi

mv -f "$TEMP_ARCHIVE" "$OUTPUT"
printf '%s\n' "$OUTPUT"
