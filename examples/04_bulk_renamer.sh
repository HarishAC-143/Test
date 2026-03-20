#!/usr/bin/env bash
#
# 04_bulk_renamer.sh — Renames files in bulk using search/replace patterns
#
# Usage: ./04_bulk_renamer.sh [OPTIONS] <directory>
#

set -euo pipefail

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <directory>

Rename files in bulk using search/replace patterns.

Options:
    -s, --search PATTERN     Pattern to search for (regex)
    -r, --replace STRING     Replacement string
    -e, --extension EXT      Only process files with this extension
    -d, --dry-run            Preview changes without renaming
    -h, --help               Show this help

Examples:
    $(basename "$0") -s ' ' -r '_' ~/photos
    $(basename "$0") -s 'IMG_' -r 'photo_' -e jpg ~/photos
    $(basename "$0") -d -s '\.jpeg$' -r '.jpg' ~/photos
EOF
    exit "${1:-0}"
}

search=""
replace=""
extension=""
dry_run=false
target_dir=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--search)  search="$2"; shift 2 ;;
        -r|--replace) replace="$2"; shift 2 ;;
        -e|--extension) extension="$2"; shift 2 ;;
        -d|--dry-run) dry_run=true; shift ;;
        -h|--help) usage 0 ;;
        -*) echo "Unknown option: $1" >&2; usage 1 ;;
        *) target_dir="$1"; shift ;;
    esac
done

[[ -z "$search" ]]     && { echo "Error: --search is required" >&2; usage 1; }
[[ -z "$target_dir" ]] && { echo "Error: directory is required" >&2; usage 1; }
[[ -d "$target_dir" ]] || { echo "Error: '$target_dir' is not a directory" >&2; exit 1; }

renamed=0
skipped=0

for filepath in "$target_dir"/*; do
    [[ -f "$filepath" ]] || continue

    filename="$(basename "$filepath")"

    if [[ -n "$extension" && "$filename" != *."$extension" ]]; then
        continue
    fi

    new_name=$(echo "$filename" | sed -E "s/$search/$replace/g")

    if [[ "$new_name" == "$filename" ]]; then
        ((skipped++))
        continue
    fi

    new_path="$target_dir/$new_name"

    if [[ -e "$new_path" ]]; then
        echo "SKIP (target exists): $filename -> $new_name"
        ((skipped++))
        continue
    fi

    if $dry_run; then
        echo "[DRY RUN] $filename -> $new_name"
    else
        mv "$filepath" "$new_path"
        echo "Renamed: $filename -> $new_name"
    fi
    ((renamed++))
done

echo ""
echo "Summary: $renamed renamed, $skipped skipped"
$dry_run && echo "(Dry-run mode — no files were actually changed)"
