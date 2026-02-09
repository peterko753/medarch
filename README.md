# MedArch

MedArch is a robust Bash script designed to archive media files from a source directory to a destination directory. It intelligently handles file organization and duplication, making it an essential tool for photographers, videographers, and data hoarders.

## Features

- **Smart Archiving**: Recursively scans for common image and video formats.
- **Directory Structure**: Preserves the source directory structure by default.
- **Duplicate Handling**: 
  - Automatically renames colliding filenames (e.g., `image.jpg` -> `image(1).jpg`).
  - Optionally skips files if content is identical (same name and size).
- **Safe**: Non-destructive operations (copies by default).
- **Portable**: Written in pure Bash, compatible with most Linux/Unix systems.

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/medarch.git
   ```
2. Make the script executable:
   ```bash
   cd medarch
   chmod +x medarch.sh
   ```
3. (Optional) Install system-wide:
   ```bash
   sudo cp medarch.sh /usr/local/bin/medarch
   ```

## Usage

```bash
./medarch.sh [OPTIONS] <source_dir> <destination_dir>
```

### Options

| Flag | Description |
|------|-------------|
| `-f`, `--flatten` | Flatten directory structure (copy all files to root of the destination). |
| `-s`, `--skip-duplicates` | Skip copying if a file with the same name and size exists in the destination. |
| `-e`, `--exclude-type` | Exclude specific media type from archiving (photo, video, sound). |
| `-m`, `--min-size` | Only archive files larger than specified size (e.g., 10M, 500k). |
| `-M`, `--max-size` | Only archive files smaller than specified size (e.g., 1G). |
| `-n`, `--dry-run` | Simulate the operation without copying any files. |
| `-v`, `--verbose` | Enable detailed output for debugging or monitoring. |
| `-h`, `--help` | Display help message. |

### Examples

**Basic Archive (Structure Preserved):**
Copy all media from SD card to local storage, keeping folder hierarchy.
```bash
./medarch.sh /media/sdcard/DCIM ~/Pictures/2023-Trip
```

**Flat Archive:**
Copy all files into a single directory, ignoring original folders.
```bash
./medarch.sh --flatten /media/sdcard/DCIM ~/Pictures/All-In-One
```

**Exclude Specific Media Types:**
Archive only photos, skipping all video files.
```bash
./medarch.sh --exclude-type video ~/Camera ~/Photos
```

**Filter by Size:**
Archive only large video files (larger than 100MB).
```bash
./medarch.sh --min-size 100M ~/Videos/Raw ~/Archive/Videos
```

**Sync-like Behavior:**
Copy new files only, skipping ones that are already archived.
```bash
./medarch.sh --skip-duplicates ~/Downloads/Images /mnt/backup/images
```

**Dry Run:**
See what would happen without moving any data.
```bash
./medarch.sh --dry-run /source /destination
```

## Supported Formats

MedArch supports a wide range of media extensions, including but not limited to:
- **Images**: jpg, jpeg, png, gif, bmp, tiff, webp, heic
- **Audio**: mp3, flac, wav, aac, ogg
- **Video**: mp4, mkv, avi, mov, wmv, flv, webm

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
