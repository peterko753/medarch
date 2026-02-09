#!/usr/bin/env bash
#
# medarch
#
# A script to archive media files from a source directory to a destination directory.
# It handles duplicates by appending a counter and can optionally skip files that
# are identical in name and size.
#
# Author: [Your Name/Username]
# License: MIT
#

set -euo pipefail

# -----------------------------------------------------------------------------
# Constants & Defaults
# -----------------------------------------------------------------------------
APP_NAME="medarch"
VERSION="1.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default behavior
SKIP_DUPLICATES=0
DRY_RUN=0
VERBOSE=0

# Supported Extensions
EXTENSIONS=(
  "jpg" "jpeg" "png" "gif" "bmp" "tiff" "webp" "heic"
  "mp3" "flac" "wav" "aac" "ogg" "m4a" "wma"
  "mp4" "mkv" "avi" "mov" "wmv" "flv" "webm" "mpeg" "mpg"
)

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

usage() {
  cat <<EOF
Usage: $APP_NAME [OPTIONS] source_dir destination_dir

Archives media files from source_dir to destination_dir.

Options:
  -s, --skip-duplicates  Skip files if a file with the same name and size exists in destination.
  -n, --dry-run          Show what would be done without actually copying files.
  -v, --verbose          Enable verbose output.
  -h, --help             Show this help message and exit.
  --version              Show version information.

Examples:
  $APP_NAME /path/to/camera /path/to/archive
  $APP_NAME --skip-duplicates ~/Downloads ~/Media
EOF
}

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------

main() {
  local src_dir=""
  local dest_dir=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s|--skip-duplicates)
        SKIP_DUPLICATES=1
        shift
        ;;
      -n|--dry-run)
        DRY_RUN=1
        shift
        ;;
      -v|--verbose)
        VERBOSE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --version)
        echo "$APP_NAME v$VERSION"
        exit 0
        ;;
      -*)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        if [[ -z "$src_dir" ]]; then
          src_dir="$1"
        elif [[ -z "$dest_dir" ]]; then
          dest_dir="$1"
        else
          log_error "Too many arguments provided."
          usage
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate arguments
  if [[ -z "$src_dir" || -z "$dest_dir" ]]; then
    log_error "Missing source or destination directory."
    usage
    exit 1
  fi

  if [[ ! -d "$src_dir" ]]; then
    log_error "Source directory does not exist: $src_dir"
    exit 1
  fi

  # Create destination if it doesn't exist (unless dry run)
  if [[ ! -d "$dest_dir" ]]; then
    if [[ $DRY_RUN -eq 0 ]]; then
      mkdir -p "$dest_dir"
      log_info "Created destination directory: $dest_dir"
    else
      log_info "Would create destination directory: $dest_dir"
    fi
  fi

  # Build find arguments
  local find_args=()
  local first=1
  for ext in "${EXTENSIONS[@]}"; do
    if [[ $first -eq 1 ]]; then
      find_args+=( -iname "*.${ext}" )
      first=0
    else
      find_args+=( -o -iname "*.${ext}" )
    fi
  done
  
  # Full find command construction
  # We use process substitution with a null delimiter to safely handle filenames with spaces/newlines
  # However, for counting, we'll run a separate find command first.
  
  log_info "Scanning for media files in: $src_dir"
  
  local file_list_cmd=(find "$src_dir" -type f \( "${find_args[@]}" \))
  
  # Count total files
  local total_files
  if ! total_files=$("${file_list_cmd[@]}" | wc -l); then
    log_error "Failed to scan source directory."
    exit 1
  fi

  if [[ "$total_files" -eq 0 ]]; then
    log_warn "No media files found in source directory."
    exit 0
  fi

  log_info "Found $total_files files to process."

  local count=0
  local copied=0
  local skipped=0
  
  # Process files
  while IFS= read -r -d '' file; do
    count=$((count + 1))
    
    local base_name
    base_name=$(basename "$file")
    local name="${base_name%.*}"
    local ext="${base_name##*.}"
    local dest_file="$dest_dir/$base_name"

    # Check for duplicates if requested
    if [[ $SKIP_DUPLICATES -eq 1 && -e "$dest_file" ]]; then
      local src_size
      src_size=$(stat -c %s -- "$file")
      local dst_size
      dst_size=$(stat -c %s -- "$dest_file")
      
      if [[ "$src_size" -eq "$dst_size" ]]; then
        skipped=$((skipped + 1))
        if [[ $VERBOSE -eq 1 ]]; then
           log_info "Skipping duplicate: $base_name"
        else
           printf "\rProcessed %d/%d (copied: %d, skipped: %d)" "$count" "$total_files" "$copied" "$skipped"
        fi
        continue
      fi
    fi

    # Handle name collisions
    local counter=1
    while [[ -e "$dest_file" ]]; do
      dest_file="$dest_dir/${name}(${counter}).${ext}"
      counter=$((counter + 1))
    done

    if [[ $DRY_RUN -eq 1 ]]; then
      if [[ $VERBOSE -eq 1 ]]; then
        log_info "Would copy '$file' -> '$dest_file'"
      fi
    else
      if cp -p -- "$file" "$dest_file"; then
        copied=$((copied + 1))
      else
        log_error "Failed to copy '$file'"
      fi
    fi
    
    if [[ $VERBOSE -eq 0 ]]; then
      printf "\rProcessed %d/%d (copied: %d, skipped: %d)" "$count" "$total_files" "$copied" "$skipped"
    fi

  done < <("${file_list_cmd[@]}" -print0)

  if [[ $VERBOSE -eq 0 ]]; then
    echo "" # Newline after progress bar
  fi

  echo "---------------------------------------------------"
  log_success "Operation completed."
  echo "Total found:   $total_files"
  echo "Copied:        $copied"
  echo "Skipped:       $skipped"
}

main "$@"
