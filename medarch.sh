#!/usr/bin/env bash
#
# archive_media.sh
#
# Usage:
#   ./archive_media.sh [--skip-duplicates|-s] /path_A /path_B

set -euo pipefail

SKIP_DUPLICATES=0

# Parse optional flag
if [[ $# -eq 3 ]]; then
  case "$1" in
    --skip-duplicates|-s)
      SKIP_DUPLICATES=1
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--skip-duplicates|-s] <source_path_A> <destination_path_B>" >&2
      exit 1
      ;;
  esac
elif [[ $# -ne 2 ]]; then
  echo "Usage: $0 [--skip-duplicates|-s] <source_path_A> <destination_path_B>" >&2
  exit 1
fi

SRC="$1"
DST="$2"

mkdir -p "$DST"

EXTENSIONS=(
  "jpg" "jpeg" "png" "gif" "bmp" "tiff" "webp" "heic"
  "mp3" "flac" "wav" "aac" "ogg" "m4a" "wma"
  "mp4" "mkv" "avi" "mov" "wmv" "flv" "webm" "mpeg" "mpg"
)

# Build find arguments array
find_args=( )
first=1
for ext in "${EXTENSIONS[@]}"; do
  if [[ $first -eq 1 ]]; then
    find_args+=( -iname "*.${ext}" )
    first=0
  else
    find_args+=( -o -iname "*.${ext}" )
  fi
done

# We need to wrap the OR conditions in parentheses for find
# Effectively: find "$SRC" -type f \( ... \) ...
full_find_args=( "$SRC" -type f \( "${find_args[@]}" \) )

# Count files first
# We can just run find and pipe to wc -l. Since we aren't using eval, quoting is handled by the array.
if ! count=$(find "${full_find_args[@]}" -print | wc -l); then
    echo "Error counting files." >&2
    exit 1
fi
TOTAL="$count"

if [[ "$TOTAL" -eq 0 ]]; then
  echo "No multimedia files found in: $SRC"
  exit 0
fi

echo "Found $TOTAL multimedia files to archive."

COUNT=0
COPIED=0
SKIPPED=0

# Use process substitution to avoid subshell variable scope issues
while IFS= read -r -d '' file; do
  COUNT=$((COUNT + 1))

  base_name=$(basename "$file")
  name="${base_name%.*}"
  ext="${base_name##*.}"

  dest_file="$DST/$base_name"

  # If skip-duplicates is enabled and a file with same name and size exists, skip
  if [[ $SKIP_DUPLICATES -eq 1 && -e "$dest_file" ]]; then
    src_size=$(stat -c %s -- "$file")
    dst_size=$(stat -c %s -- "$dest_file")
    if [[ "$src_size" -eq "$dst_size" ]]; then
      SKIPPED=$((SKIPPED + 1))
      printf "\rProcessed %d/%d (copied: %d, skipped: %d)" "$COUNT" "$TOTAL" "$COPIED" "$SKIPPED"
      continue
    fi
  fi

  # Handle duplicate names (this will run even with SKIP_DUPLICATES,
  # but only when either file doesn't exist or size differs)
  counter=1
  while [[ -e "$dest_file" ]]; do
    dest_file="$DST/${name}(${counter}).${ext}"
    ((counter++))
  done

  cp -p -- "$file" "$dest_file"
  COPIED=$((COPIED + 1))

  printf "\rProcessed %d/%d (copied: %d, skipped: %d)" "$COUNT" "$TOTAL" "$COPIED" "$SKIPPED"
done < <(find "${full_find_args[@]}" -print0)

echo
echo "Done."
echo "Total found:   $TOTAL"
echo "Copied:        $COPIED"
echo "Skipped (same name & size): $SKIPPED"

