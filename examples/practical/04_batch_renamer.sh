#!/bin/bash
# Batch File Renamer — rename files using patterns, regex, sequencing, date stamps
# Usage: ./04_batch_renamer.sh [OPTIONS] directory
#        ./04_batch_renamer.sh --demo

set -euo pipefail

MODE=""
PATTERN=""
REPLACEMENT=""
PREFIX=""
SUFFIX=""
EXTENSION=""
DRY_RUN=true
RECURSIVE=false
TARGET_DIR=""
SEQUENTIAL_NAME=""
DEMO_MODE=false

usage() {
    cat << EOF
Batch File Renamer

Usage: $(basename "$0") [OPTIONS] DIRECTORY
       $(basename "$0") --demo

Modes:
    -r PAT:REP    Search and replace in filenames
    -p PREFIX     Add prefix to all filenames
    -x SUFFIX     Add suffix (before extension)
    -e EXT        Change file extension
    -s NAME       Sequential rename (NAME001, NAME002, ...)
    -l            Convert filenames to lowercase
    -u            Convert filenames to uppercase
    -d            Add date prefix (YYYYMMDD_)

Options:
    --execute     Actually rename (default: dry-run)
    --recursive   Process subdirectories
    --demo        Run demo with sample files
    -h            Show this help

Examples:
    $(basename "$0") -r "IMG:photo" ./pictures
    $(basename "$0") -l --execute ./Documents
    $(basename "$0") --demo
EOF
    exit 0
}

if [[ "${1:-}" == "--demo" ]]; then
    DEMO_MODE=true
    TARGET_DIR=$(mktemp -d)
    trap 'rm -rf "$TARGET_DIR"' EXIT

    touch "$TARGET_DIR/IMG_001.JPG"
    touch "$TARGET_DIR/IMG_002.JPG"
    touch "$TARGET_DIR/IMG_003.JPG"
    touch "$TARGET_DIR/Document File.pdf"
    touch "$TARGET_DIR/MY REPORT.docx"
    touch "$TARGET_DIR/data_export.CSV"
    touch "$TARGET_DIR/Notes.TXT"

    echo "═══════════════════════════════════"
    echo "  BATCH FILE RENAMER — DEMO"
    echo "═══════════════════════════════════"
    echo ""
    echo "Created sample files:"
    ls -1 "$TARGET_DIR"
    echo ""

    echo "━━━ Demo 1: Lowercase filenames (dry-run) ━━━"
    "$0" -l "$TARGET_DIR"
    echo ""

    echo "━━━ Demo 2: Replace 'IMG' with 'photo' (dry-run) ━━━"
    "$0" -r "IMG:photo" "$TARGET_DIR"
    echo ""

    echo "━━━ Demo 3: Add date prefix (dry-run) ━━━"
    "$0" -d "$TARGET_DIR"
    echo ""

    echo "━━━ Demo 4: Sequential rename (dry-run) ━━━"
    "$0" -s "vacation_" "$TARGET_DIR"
    echo ""

    echo "━━━ Demo 5: Lowercase (execute!) ━━━"
    "$0" -l --execute "$TARGET_DIR"
    echo ""

    echo "Final files:"
    ls -1 "$TARGET_DIR"

    exit 0
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r)
            MODE="replace"
            IFS=: read -r PATTERN REPLACEMENT <<< "$2"
            shift 2
            ;;
        -p) MODE="prefix"; PREFIX="$2"; shift 2 ;;
        -x) MODE="suffix"; SUFFIX="$2"; shift 2 ;;
        -e) MODE="extension"; EXTENSION="$2"; shift 2 ;;
        -s) MODE="sequential"; SEQUENTIAL_NAME="$2"; shift 2 ;;
        -l) MODE="lowercase"; shift ;;
        -u) MODE="uppercase"; shift ;;
        -d) MODE="date"; shift ;;
        --execute) DRY_RUN=false; shift ;;
        --recursive) RECURSIVE=true; shift ;;
        -h|--help) usage ;;
        *)
            if [[ -z "$TARGET_DIR" ]]; then
                TARGET_DIR="$1"
            fi
            shift
            ;;
    esac
done

[[ -z "$MODE" ]]       && { echo "Error: no rename mode specified" >&2; usage; }
[[ -z "$TARGET_DIR" ]] && { echo "Error: directory required" >&2; usage; }
[[ -d "$TARGET_DIR" ]] || { echo "Error: '$TARGET_DIR' is not a directory" >&2; exit 1; }

if $DRY_RUN; then
    echo "[DRY RUN] No files will be renamed. Use --execute to apply."
    echo ""
fi

renamed=0
skipped=0
errors=0
counter=1

process_file() {
    local filepath="$1"
    local dir
    dir=$(dirname "$filepath")
    local filename
    filename=$(basename "$filepath")
    local name="${filename%.*}"
    local ext="${filename##*.}"

    [[ "$name" == "$ext" ]] && ext=""
    [[ -n "$ext" ]] && ext=".$ext"

    local new_name="$filename"

    case "$MODE" in
        replace)
            new_name="${filename//$PATTERN/$REPLACEMENT}"
            ;;
        prefix)
            new_name="${PREFIX}${filename}"
            ;;
        suffix)
            new_name="${name}${SUFFIX}${ext}"
            ;;
        extension)
            new_name="${name}.${EXTENSION}"
            ;;
        sequential)
            new_name=$(printf "%s%03d%s" "$SEQUENTIAL_NAME" "$counter" "$ext")
            ((counter++))
            ;;
        lowercase)
            new_name="${filename,,}"
            ;;
        uppercase)
            new_name="${filename^^}"
            ;;
        date)
            local date_prefix
            date_prefix=$(date +%Y%m%d)
            new_name="${date_prefix}_${filename}"
            ;;
    esac

    if [[ "$new_name" == "$filename" ]]; then
        ((skipped++)) || true
        return
    fi

    local new_path="${dir}/${new_name}"

    if [[ -e "$new_path" && "$new_path" != "$filepath" ]]; then
        echo "  SKIP (exists): $filename -> $new_name"
        ((skipped++)) || true
        return
    fi

    if $DRY_RUN; then
        echo "  WOULD RENAME: $filename -> $new_name"
    else
        if mv "$filepath" "$new_path"; then
            echo "  RENAMED: $filename -> $new_name"
            ((renamed++)) || true
        else
            echo "  ERROR:   $filename" >&2
            ((errors++)) || true
        fi
    fi
}

if $RECURSIVE; then
    while IFS= read -r file; do
        process_file "$file"
    done < <(find "$TARGET_DIR" -type f | sort)
else
    for file in "$TARGET_DIR"/*; do
        [[ -f "$file" ]] || continue
        process_file "$file"
    done
fi

echo ""
echo "━━━ Summary ━━━"
echo "  Renamed: $renamed"
echo "  Skipped: $skipped"
echo "  Errors:  $errors"
if $DRY_RUN; then
    echo "  (Dry run — no files were changed)"
fi
