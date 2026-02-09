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
PRESERVE_STRUCTURE=1
SKIP_DUPLICATES=0
DRY_RUN=0
VERBOSE=0
MIN_SIZE=""
MAX_SIZE=""
INCLUDE_PHOTO=1
INCLUDE_VIDEO=1
INCLUDE_AUDIO=1

# Supported Extensions
EXT_PHOTO=( "jpg" "jpeg" "png" "gif" "bmp" "tiff" "webp" "heic" )
EXT_AUDIO=( "mp3" "flac" "wav" "aac" "ogg" "m4a" "wma" )
EXT_VIDEO=( "mp4" "mkv" "avi" "mov" "wmv" "flv" "webm" "mpeg" "mpg" )

EXTENSIONS=()

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

usage() {
  cat <<EOF
Usage: $APP_NAME [OPTIONS] source_dir destination_dir

Archives media files from source_dir to destination_dir.

Options:
  -f, --flatten          Flatten directory structure (copy all files to root of destination).
  -s, --skip-duplicates  Skip files if a file with the same name and size exists in destination.
  -e, --exclude-type TYPE Exclude specific media type (photo, video, sound). Can be used multiple times.
  -m, --min-size SIZE    Only archive files larger than SIZE. (e.g., 10M, 500k)
  -M, --max-size SIZE    Only archive files smaller than SIZE. (e.g., 1G)
  -n, --dry-run          Show what would be done without actually copying files.
  -v, --verbose          Enable verbose output.
  -h, --help             Show this help message and exit.
  --version              Show version information.

Examples:
  $APP_NAME /path/to/camera /path/to/archive
  $APP_NAME --min-size 1M --skip-duplicates ~/Downloads ~/Media
  $APP_NAME --exclude-type video ~/Source ~/Destination
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
      -f|--flatten)
        PRESERVE_STRUCTURE=0
        shift
        ;;
      -s|--skip-duplicates)
        SKIP_DUPLICATES=1
        shift
        ;;
      -e|--exclude-type)
        if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
          case "$2" in
            photo|image) INCLUDE_PHOTO=0 ;;
            video|movie) INCLUDE_VIDEO=0 ;;
            sound|audio) INCLUDE_AUDIO=0 ;;
            *)
              log_error "Unknown type to exclude: $2. Use 'photo', 'video', or 'sound'."
              exit 1
              ;;
          esac
          shift 2
        else
          log_error "Error: Argument for $1 is missing."
          usage
          exit 1
        fi
        ;;
      -m|--min-size)
        if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
          MIN_SIZE="$2"
          shift 2
        else
          log_error "Error: Argument for $1 is missing."
          usage
          exit 1
        fi
        ;;
      -M|--max-size)
        if [[ -n "${2:-}" && ${2:0:1} != "-" ]]; then
          MAX_SIZE="$2"
          shift 2
        else
          log_error "Error: Argument for $1 is missing."
          usage
          exit 1
        fi
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

  # Build extensions list
  if [[ $INCLUDE_PHOTO -eq 1 ]]; then
    EXTENSIONS+=("${EXT_PHOTO[@]}")
  fi
  if [[ $INCLUDE_VIDEO -eq 1 ]]; then
    EXTENSIONS+=("${EXT_VIDEO[@]}")
  fi
  if [[ $INCLUDE_AUDIO -eq 1 ]]; then
    EXTENSIONS+=("${EXT_AUDIO[@]}")
  fi

  if [[ ${#EXTENSIONS[@]} -eq 0 ]]; then
    log_error "No media types selected. Everything excluded?"
    exit 1
  fi

  # Resolve to absolute paths for reliable processing
  src_dir=$(realpath "$src_dir")
  dest_dir=$(realpath "$dest_dir")

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
  
  # Wrap extensions in parens
  local ext_filter=( \( "${find_args[@]}" \) )
  
  # Add size filters if specified
  # Note: `find` expects size suffixes like k, M, G to be case-sensitive or specific.
  # k = kilobytes, M = megabytes, G = gigabytes.
  # We should probably pass the user input directly if they use correct find syntax, or normalize it.
  # For now, assuming user knows find syntax or follows prompt instructions.
  
  local size_filter=()
  if [[ -n "$MIN_SIZE" ]]; then
     size_filter+=( -size "+$MIN_SIZE" )
  fi
  if [[ -n "$MAX_SIZE" ]]; then
     size_filter+=( -size "-$MAX_SIZE" )
  fi

  log_info "Scanning for media files in: $src_dir"
  if [[ -n "$MIN_SIZE" ]]; then log_info "Filter: Min Size > $MIN_SIZE"; fi
  if [[ -n "$MAX_SIZE" ]]; then log_info "Filter: Max Size < $MAX_SIZE"; fi

  local file_list_cmd=(find "$src_dir" -type f "${ext_filter[@]}" "${size_filter[@]}")
  
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
  local errors=0
  
  # Process files
  while IFS= read -r -d '' file; do
    count=$((count + 1))
    
    local base_name
    base_name=$(basename "$file")
    local name="${base_name%.*}"
    local ext="${base_name##*.}"
    local dest_file=""
    local sub_dir=""

    if [[ $PRESERVE_STRUCTURE -eq 1 ]]; then
      # Calculate relative path from src_dir
      # remove src_dir prefix from file path to get relative path
      # ensuring to remove leading slash if present
      local rel_path="${file#$src_dir/}"
      sub_dir=$(dirname "$rel_path")
      
      # Determine destination directory
      local target_dir="$dest_dir/$sub_dir"
      
      # Create subfolder if needed
      if [[ ! -d "$target_dir" ]]; then
        if [[ $DRY_RUN -eq 0 ]]; then
             mkdir -p "$target_dir"
        elif [[ $VERBOSE -eq 1 ]]; then
             log_info "Would create subdirectory: $target_dir"
        fi
      fi
      dest_file="$target_dir/$base_name"
    else
      dest_file="$dest_dir/$base_name"
    fi

    # Check for duplicates if requested
    if [[ $SKIP_DUPLICATES -eq 1 && -e "$dest_file" ]]; then
      local src_size
      src_size=$(stat -c %s -- "$file" || echo 0)
      local dst_size
      dst_size=$(stat -c %s -- "$dest_file" || echo 0)
      
      if [[ "$src_size" -eq "$dst_size" && "$src_size" -gt 0 ]]; then
        skipped=$((skipped + 1))
        if [[ $VERBOSE -eq 1 ]]; then
           log_info "Skipping duplicate: $base_name"
        else
           printf "\rProcessed %d/%d (copied: %d, skipped: %d, errors: %d)" "$count" "$total_files" "$copied" "$skipped" "$errors"
        fi
        continue
      fi
    fi

    # Handle name collisions
    local counter=1
    # We need to recalculate dir and base in case dest_file changes
    # But dest_file already includes the correct path (flattened or structured)
    
    # Store the original destination path components
    local dest_dir_path
    dest_dir_path=$(dirname "$dest_file")
    
    while [[ -e "$dest_file" ]]; do
      dest_file="$dest_dir_path/${name}(${counter}).${ext}"
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
        errors=$((errors + 1))
      fi
    fi
    
    if [[ $VERBOSE -eq 0 ]]; then
      printf "\rProcessed %d/%d (copied: %d, skipped: %d, errors: %d)" "$count" "$total_files" "$copied" "$skipped" "$errors"
    fi

  done < <("${file_list_cmd[@]}" -print0)

  if [[ $VERBOSE -eq 0 ]]; then
    echo "" # Newline after progress bar
  fi

  echo "---------------------------------------------------"
  log_success "Operation completed."
  echo "Total found:         $total_files"
  echo "Copied:              $copied"
  echo "Skipped (Duplicate): $skipped"
  echo "Errors:              $errors"
}

main "$@"
