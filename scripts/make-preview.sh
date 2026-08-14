#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  scripts/make-preview.sh \
    --board FILE \
    --stones DIR \
    --stone-scale NUMBER \
    --output FILE \
    [--size PIXELS] \
    [--quality 0-100]

Renders the repository's representative 19x19 position as a square WebP.
Defaults: --size 1800 and --quality 92.

Use --black-scale and --white-scale instead of --stone-scale when the colors
need different scales.
EOF
}

fail() {
  printf 'make-preview: %s\n' "$1" >&2
  exit 1
}

require_value() {
  [ "$#" -ge 2 ] || fail "missing value for $1"
}

validate_scale() {
  label=$1
  value=$2
  awk -v value="$value" 'BEGIN {
    valid = value ~ /^([0-9]+([.][0-9]*)?|[.][0-9]+)$/ && value > 0
    exit !valid
  }' || fail "$label must be a positive number"
}

BOARD_INPUT=
STONES_INPUT=
OUTPUT=
BLACK_SCALE=
WHITE_SCALE=
SIZE=1800
QUALITY=92

while [ "$#" -gt 0 ]; do
  case "$1" in
    --board)
      require_value "$@"
      BOARD_INPUT=$2
      shift 2
      ;;
    --stones)
      require_value "$@"
      STONES_INPUT=$2
      shift 2
      ;;
    --stone-scale)
      require_value "$@"
      BLACK_SCALE=$2
      WHITE_SCALE=$2
      shift 2
      ;;
    --black-scale)
      require_value "$@"
      BLACK_SCALE=$2
      shift 2
      ;;
    --white-scale)
      require_value "$@"
      WHITE_SCALE=$2
      shift 2
      ;;
    --output)
      require_value "$@"
      OUTPUT=$2
      shift 2
      ;;
    --size)
      require_value "$@"
      SIZE=$2
      shift 2
      ;;
    --quality)
      require_value "$@"
      QUALITY=$2
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

[ -n "$BOARD_INPUT" ] || fail "--board is required"
[ -n "$STONES_INPUT" ] || fail "--stones is required"
[ -n "$OUTPUT" ] || fail "--output is required"
[ -n "$BLACK_SCALE" ] || fail "--stone-scale or --black-scale is required"
[ -n "$WHITE_SCALE" ] || fail "--stone-scale or --white-scale is required"

case "$SIZE" in
  ''|*[!0-9]*) fail "--size must be a positive integer" ;;
esac
[ "$SIZE" -gt 0 ] || fail "--size must be a positive integer"

case "$QUALITY" in
  ''|*[!0-9]*) fail "--quality must be an integer from 0 to 100" ;;
esac
[ "$QUALITY" -le 100 ] || fail "--quality must be an integer from 0 to 100"

validate_scale "black stone scale" "$BLACK_SCALE"
validate_scale "white stone scale" "$WHITE_SCALE"
command -v magick >/dev/null 2>&1 || fail "ImageMagick's magick command is required"

[ -f "$BOARD_INPUT" ] || fail "board image does not exist: $BOARD_INPUT"
STONES_DIR=$(CDPATH= cd -- "$STONES_INPUT" && pwd) || \
  fail "stone directory does not exist: $STONES_INPUT"

set -- "$STONES_DIR"/black-*.png
[ -f "$1" ] || fail "no black-NN.png stones found in $STONES_DIR"
BLACK_COUNT=$#
set -- "$STONES_DIR"/white-*.png
[ -f "$1" ] || fail "no white-NN.png stones found in $STONES_DIR"
WHITE_COUNT=$#

OUTPUT_DIR=$(dirname -- "$OUTPUT")
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(CDPATH= cd -- "$OUTPUT_DIR" && pwd)
OUTPUT="$OUTPUT_DIR/${OUTPUT##*/}"
case "$OUTPUT" in
  *.webp) ;;
  *) fail "output filename must end in .webp" ;;
esac

TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/goban-decals-preview.XXXXXX")
TEMP_OUTPUT="$TEMP_DIR/preview.webp"
cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

# Coordinates are zero-based intersections in the representative 19x19 game.
PLACEMENTS='B:13:0
B:8:1 B:12:1 W:13:1 W:14:1 W:15:1
W:2:2 W:3:2 B:4:2 W:5:2 W:6:2 B:9:2 B:12:2 B:13:2 W:14:2
W:2:3 W:4:3 B:5:3 W:6:3 B:12:3 W:13:3 B:14:3 B:15:3 B:16:3
W:3:4 B:4:4 B:6:4 B:12:4 W:13:4 B:14:4
B:3:5 B:4:5 B:5:5 W:7:5 B:9:5 W:10:5 W:12:5 W:13:5 B:15:5 B:16:5
B:9:6 B:10:6
W:8:7 W:9:7 W:10:7 B:11:7 W:12:7
W:1:8 B:2:8 W:3:8 B:12:8 W:13:8 B:15:8
W:2:9 B:3:9 B:12:9 B:13:9 B:14:9
W:3:10 W:12:10 W:13:10
W:10:11
B:11:12 W:13:12
B:15:14
W:3:15 B:10:15 W:14:15 W:15:15 B:16:15
B:5:16 W:7:16 B:15:16 B:17:16
B:16:17'

# Board artwork reserves 1.5 grid spacings on each edge for coordinates. Preview
# images omit coordinates, so crop that technical margin to 0.6 spacings.
SOURCE_BOARD_UNITS=21
PREVIEW_BOARD_UNITS=19.2
PREVIEW_MARGIN=0.6
BOARD_SIZE=$(awk -v size="$SIZE" -v source="$SOURCE_BOARD_UNITS" \
  -v preview="$PREVIEW_BOARD_UNITS" \
  'BEGIN { printf "%.0f", size * source / preview }')
BLACK_SIZE=$(awk -v size="$SIZE" -v scale="$BLACK_SCALE" \
  -v preview="$PREVIEW_BOARD_UNITS" \
  'BEGIN { printf "%.0f", size / preview * scale }')
WHITE_SIZE=$(awk -v size="$SIZE" -v scale="$WHITE_SCALE" \
  -v preview="$PREVIEW_BOARD_UNITS" \
  'BEGIN { printf "%.0f", size / preview * scale }')
[ "$BLACK_SIZE" -gt 0 ] || fail "black stone scale is too small for the output size"
[ "$WHITE_SIZE" -gt 0 ] || fail "white stone scale is too small for the output size"

black_index=1
white_index=1
set -- magick "$BOARD_INPUT" -filter Lanczos \
  -resize "${BOARD_SIZE}x${BOARD_SIZE}!" -gravity center -extent "${SIZE}x${SIZE}" \
  +gravity

for placement in $PLACEMENTS; do
  color=${placement%%:*}
  remainder=${placement#*:}
  column=${remainder%%:*}
  row=${remainder#*:}

  if [ "$color" = B ]; then
    prefix=black
    index=$black_index
    count=$BLACK_COUNT
    stone_size=$BLACK_SIZE
    black_index=$((black_index + 1))
  else
    prefix=white
    index=$white_index
    count=$WHITE_COUNT
    stone_size=$WHITE_SIZE
    white_index=$((white_index + 1))
  fi

  variant=$(( (index - 1) % count + 1 ))
  stone=$(printf '%s/%s-%02d.png' "$STONES_DIR" "$prefix" "$variant")
  [ -f "$stone" ] || fail "stone variants must be contiguous: missing $stone"

  coordinates=$(awk \
    -v size="$SIZE" -v preview="$PREVIEW_BOARD_UNITS" \
    -v margin="$PREVIEW_MARGIN" -v column="$column" -v row="$row" \
    -v stone="$stone_size" \
    'BEGIN {
      x = (column + margin) * size / preview - stone / 2
      y = (row + margin) * size / preview - stone / 2
      printf "%.0f %.0f", x, y
    }')
  x=${coordinates%% *}
  y=${coordinates##* }

  set -- "$@" \
    \( "$stone" -filter Lanczos -resize "${stone_size}x${stone_size}!" \) \
    -geometry "+$x+$y" -composite
done

"$@" -strip -colorspace sRGB -quality "$QUALITY" \
  -define webp:method=6 "$TEMP_OUTPUT"
mv -f "$TEMP_OUTPUT" "$OUTPUT"
printf '%s\n' "$OUTPUT"
