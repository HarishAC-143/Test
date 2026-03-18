#!/usr/bin/env bash
# =============================================================================
# File Organizer
#
# Organizes files in a directory by type (extension), date, or size.
# Supports dry-run mode, undo via log, and customizable rules.
#
# Usage: ./08_file_organizer.sh DIRECTORY [OPTIONS]
# =============================================================================
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly UNDO_LOG="/tmp/file_organizer_undo.log"

# Category mapping: extension -> directory name
declare -A CATEGORIES=(
    # Documents
    [pdf]="Documents"  [doc]="Documents"  [docx]="Documents"
    [txt]="Documents"  [rtf]="Documents"  [odt]="Documents"
    [xls]="Documents"  [xlsx]="Documents" [csv]="Documents"
    [ppt]="Documents"  [pptx]="Documents" [md]="Documents"

    # Images
    [jpg]="Images"  [jpeg]="Images"  [png]="Images"
    [gif]="Images"  [bmp]="Images"   [svg]="Images"
    [webp]="Images" [ico]="Images"   [tiff]="Images"

    # Videos
    [mp4]="Videos"  [avi]="Videos"  [mkv]="Videos"
    [mov]="Videos"  [wmv]="Videos"  [flv]="Videos"
    [webm]="Videos" [m4v]="Videos"

    # Audio
    [mp3]="Audio"  [wav]="Audio"  [flac]="Audio"
    [aac]="Audio"  [ogg]="Audio"  [wma]="Audio"
    [m4a]="Audio"

    # Archives
    [zip]="Archives"  [tar]="Archives"  [gz]="Archives"
    [bz2]="Archives"  [xz]="Archives"   [7z]="Archives"
    [rar]="Archives"  [tgz]="Archives"

    # Code
    [sh]="Code"    [bash]="Code"  [py]="Code"
    [js]="Code"    [ts]="Code"    [java]="Code"
    [c]="Code"     [cpp]="Code"   [h]="Code"
    [rb]="Code"    [go]="Code"    [rs]="Code"
    [php]="Code"   [html]="Code"  [css]="Code"
    [json]="Code"  [xml]="Code"   [yaml]="Code"
    [yml]="Code"   [toml]="Code"  [sql]="Code"

    # Executables
    [exe]="Executables"  [msi]="Executables"  [deb]="Executables"
    [rpm]="Executables"  [dmg]="Executables"  [AppImage]="Executables"

    # Fonts
    [ttf]="Fonts"  [otf]="Fonts"  [woff]="Fonts"  [woff2]="Fonts"
)

usage() {
    cat << EOF
File Organizer - Sort files into categorized directories

Usage: $SCRIPT_NAME DIRECTORY [OPTIONS]

Modes:
    --by-type           Organize by file type/extension (default)
    --by-date           Organize by modification date (YYYY/MM)
    --by-size           Organize by file size (Small/Medium/Large/Huge)

Options:
    --dry-run           Preview changes without moving files
    --recursive         Include files in subdirectories
    --undo              Undo the last organization operation
    --min-size SIZE     Skip files smaller than SIZE (e.g., 1K, 1M)
    --exclude PATTERN   Exclude files matching pattern (can be repeated)
    --verbose           Show detailed output
    -h, --help          Show this help

Size Categories (--by-size):
    Small:   < 1 MB
    Medium:  1 MB - 100 MB
    Large:   100 MB - 1 GB
    Huge:    > 1 GB

Examples:
    $SCRIPT_NAME ~/Downloads --by-type --dry-run
    $SCRIPT_NAME ~/Desktop --by-date --verbose
    $SCRIPT_NAME ~/Documents --by-size --min-size 1K
    $SCRIPT_NAME --undo
EOF
}

die() {
    echo "Error: $*" >&2
    exit 1
}

log_move() {
    local src="$1"
    local dst="$2"
    echo "$src|$dst" >> "$UNDO_LOG"
}

format_size() {
    local size=$1
    if (( size >= 1073741824 )); then
        echo "$(echo "scale=1; $size / 1073741824" | bc) GB"
    elif (( size >= 1048576 )); then
        echo "$(echo "scale=1; $size / 1048576" | bc) MB"
    elif (( size >= 1024 )); then
        echo "$(echo "scale=1; $size / 1024" | bc) KB"
    else
        echo "${size} B"
    fi
}

parse_size() {
    local input="${1^^}"
    local number="${input//[^0-9.]/}"
    local unit="${input//[0-9.]/}"

    case "$unit" in
        K|KB) echo "$(echo "$number * 1024" | bc | cut -d. -f1)" ;;
        M|MB) echo "$(echo "$number * 1048576" | bc | cut -d. -f1)" ;;
        G|GB) echo "$(echo "$number * 1073741824" | bc | cut -d. -f1)" ;;
        *)    echo "$number" ;;
    esac
}

get_size_category() {
    local size=$1
    if (( size < 1048576 )); then
        echo "Small_under_1MB"
    elif (( size < 104857600 )); then
        echo "Medium_1MB-100MB"
    elif (( size < 1073741824 )); then
        echo "Large_100MB-1GB"
    else
        echo "Huge_over_1GB"
    fi
}

get_date_category() {
    local file="$1"
    local mod_date
    mod_date=$(stat -c '%Y' "$file" 2>/dev/null || stat -f '%m' "$file" 2>/dev/null)
    date -d "@$mod_date" '+%Y/%m' 2>/dev/null || date -r "$mod_date" '+%Y/%m' 2>/dev/null
}

get_type_category() {
    local file="$1"
    local ext="${file##*.}"
    ext="${ext,,}"

    if [[ -n "${CATEGORIES[$ext]+x}" ]]; then
        echo "${CATEGORIES[$ext]}"
    else
        echo "Other"
    fi
}

move_file() {
    local src="$1"
    local dest_dir="$2"
    local dry_run="$3"
    local verbose="$4"

    local filename
    filename=$(basename "$src")
    local dest="${dest_dir}/${filename}"

    # Handle name conflicts
    if [[ -e "$dest" ]]; then
        local base="${filename%.*}"
        local ext="${filename##*.}"
        local counter=1
        if [[ "$base" == "$ext" ]]; then
            # No extension
            while [[ -e "${dest_dir}/${base}_${counter}" ]]; do
                (( counter++ ))
            done
            dest="${dest_dir}/${base}_${counter}"
        else
            while [[ -e "${dest_dir}/${base}_${counter}.${ext}" ]]; do
                (( counter++ ))
            done
            dest="${dest_dir}/${base}_${counter}.${ext}"
        fi
    fi

    if $dry_run; then
        if $verbose; then
            local size
            size=$(stat -c '%s' "$src" 2>/dev/null || stat -f '%z' "$src" 2>/dev/null)
            printf "  [DRY RUN] %s -> %s (%s)\n" "$filename" "$dest_dir/" "$(format_size "$size")"
        else
            printf "  [DRY RUN] %s -> %s/\n" "$filename" "$dest_dir"
        fi
    else
        mkdir -p "$dest_dir"
        mv "$src" "$dest"
        log_move "$dest" "$src"
        if $verbose; then
            printf "  Moved: %s -> %s/\n" "$filename" "$dest_dir"
        fi
    fi
}

organize_by_type() {
    local dir="$1"
    local dry_run="$2"
    local recursive="$3"
    local verbose="$4"
    local min_size="$5"
    shift 5
    local excludes=("$@")

    echo ""
    echo "Organizing by FILE TYPE: $dir"
    echo "──────────────────────────────────────────"

    local find_args=("$dir")
    if ! $recursive; then
        find_args+=("-maxdepth" "1")
    fi
    find_args+=("-type" "f")

    local moved=0 skipped=0
    declare -A category_counts

    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file")

        # Skip hidden files
        [[ "$filename" == .* ]] && { (( skipped++ )); continue; }

        # Check excludes
        local excluded=false
        for pattern in "${excludes[@]}"; do
            if [[ "$filename" == $pattern ]]; then
                excluded=true
                break
            fi
        done
        $excluded && { (( skipped++ )); continue; }

        # Check minimum size
        if (( min_size > 0 )); then
            local fsize
            fsize=$(stat -c '%s' "$file" 2>/dev/null || stat -f '%z' "$file" 2>/dev/null || echo 0)
            (( fsize < min_size )) && { (( skipped++ )); continue; }
        fi

        local category
        category=$(get_type_category "$file")
        local dest_dir="${dir}/${category}"

        # Don't move files already in their target directory
        if [[ "$(dirname "$file")" == "$dest_dir" ]]; then
            continue
        fi

        move_file "$file" "$dest_dir" "$dry_run" "$verbose"
        (( moved++ ))
        category_counts["$category"]=$(( ${category_counts["$category"]:-0} + 1 ))
    done < <(find "${find_args[@]}" -print0 2>/dev/null)

    echo ""
    echo "Summary:"
    for cat in $(echo "${!category_counts[@]}" | tr ' ' '\n' | sort); do
        printf "  %-15s %d files\n" "$cat:" "${category_counts[$cat]}"
    done
    echo "  ─────────────────────"
    echo "  Moved:   $moved files"
    echo "  Skipped: $skipped files"
}

organize_by_date() {
    local dir="$1"
    local dry_run="$2"
    local recursive="$3"
    local verbose="$4"
    local min_size="$5"
    shift 5
    local excludes=("$@")

    echo ""
    echo "Organizing by DATE: $dir"
    echo "──────────────────────────────────────────"

    local find_args=("$dir")
    if ! $recursive; then
        find_args+=("-maxdepth" "1")
    fi
    find_args+=("-type" "f")

    local moved=0

    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file")

        [[ "$filename" == .* ]] && continue

        local excluded=false
        for pattern in "${excludes[@]}"; do
            [[ "$filename" == $pattern ]] && { excluded=true; break; }
        done
        $excluded && continue

        local date_dir
        date_dir=$(get_date_category "$file")
        local dest_dir="${dir}/${date_dir}"

        [[ "$(dirname "$file")" == "$dest_dir" ]] && continue

        move_file "$file" "$dest_dir" "$dry_run" "$verbose"
        (( moved++ ))
    done < <(find "${find_args[@]}" -print0 2>/dev/null)

    echo ""
    echo "  Moved: $moved files"
}

organize_by_size() {
    local dir="$1"
    local dry_run="$2"
    local recursive="$3"
    local verbose="$4"
    local min_size="$5"
    shift 5
    local excludes=("$@")

    echo ""
    echo "Organizing by SIZE: $dir"
    echo "──────────────────────────────────────────"

    local find_args=("$dir")
    if ! $recursive; then
        find_args+=("-maxdepth" "1")
    fi
    find_args+=("-type" "f")

    local moved=0
    declare -A size_counts

    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file")

        [[ "$filename" == .* ]] && continue

        local excluded=false
        for pattern in "${excludes[@]}"; do
            [[ "$filename" == $pattern ]] && { excluded=true; break; }
        done
        $excluded && continue

        local fsize
        fsize=$(stat -c '%s' "$file" 2>/dev/null || stat -f '%z' "$file" 2>/dev/null || echo 0)

        local size_cat
        size_cat=$(get_size_category "$fsize")
        local dest_dir="${dir}/${size_cat}"

        [[ "$(dirname "$file")" == "$dest_dir" ]] && continue

        move_file "$file" "$dest_dir" "$dry_run" "$verbose"
        (( moved++ ))
        size_counts["$size_cat"]=$(( ${size_counts["$size_cat"]:-0} + 1 ))
    done < <(find "${find_args[@]}" -print0 2>/dev/null)

    echo ""
    echo "Summary:"
    for cat in $(echo "${!size_counts[@]}" | tr ' ' '\n' | sort); do
        printf "  %-25s %d files\n" "$cat:" "${size_counts[$cat]}"
    done
    echo "  Moved: $moved files total"
}

undo_last() {
    if [[ ! -f "$UNDO_LOG" ]]; then
        echo "No undo log found. Nothing to undo."
        return
    fi

    echo "Undoing last organization..."
    echo "──────────────────────────────────────────"

    local count=0
    # Process in reverse order
    tac "$UNDO_LOG" | while IFS='|' read -r current original; do
        if [[ -f "$current" ]]; then
            local orig_dir
            orig_dir=$(dirname "$original")
            mkdir -p "$orig_dir"
            mv "$current" "$original"
            echo "  Restored: $(basename "$current") -> $orig_dir/"
            (( count++ ))
        fi
    done

    rm -f "$UNDO_LOG"
    echo ""
    echo "Undo complete."
}

main() {
    local directory=""
    local mode="type"
    local dry_run=false
    local recursive=false
    local verbose=false
    local min_size=0
    local excludes=()

    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --by-type)      mode="type"; shift ;;
            --by-date)      mode="date"; shift ;;
            --by-size)      mode="size"; shift ;;
            --dry-run)      dry_run=true; shift ;;
            --recursive)    recursive=true; shift ;;
            --undo)         undo_last; exit 0 ;;
            --min-size)     min_size=$(parse_size "$2"); shift 2 ;;
            --exclude)      excludes+=("$2"); shift 2 ;;
            --verbose)      verbose=true; shift ;;
            -h|--help)      usage; exit 0 ;;
            -*)             die "Unknown option: $1" ;;
            *)              directory="$1"; shift ;;
        esac
    done

    [[ -n "$directory" ]] || die "Directory argument is required"
    [[ -d "$directory" ]] || die "Directory not found: $directory"

    # Resolve to absolute path
    directory=$(cd "$directory" && pwd)

    if ! $dry_run; then
        > "$UNDO_LOG"
    fi

    case "$mode" in
        type) organize_by_type "$directory" "$dry_run" "$recursive" "$verbose" "$min_size" "${excludes[@]+"${excludes[@]}"}" ;;
        date) organize_by_date "$directory" "$dry_run" "$recursive" "$verbose" "$min_size" "${excludes[@]+"${excludes[@]}"}" ;;
        size) organize_by_size "$directory" "$dry_run" "$recursive" "$verbose" "$min_size" "${excludes[@]+"${excludes[@]}"}" ;;
    esac
}

main "$@"
