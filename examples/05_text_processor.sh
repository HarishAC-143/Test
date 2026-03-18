#!/usr/bin/env bash
# =============================================================================
# Text/CSV Processor
#
# Provides utilities for processing text and CSV files: column extraction,
# filtering, aggregation, sorting, deduplication, and format conversion.
#
# Usage: ./05_text_processor.sh COMMAND FILE [OPTIONS]
# =============================================================================
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"

usage() {
    cat << EOF
Text/CSV Processor - Manipulate structured text files

Usage: $SCRIPT_NAME COMMAND FILE [OPTIONS]

Commands:
    columns FILE              List column headers (first row)
    extract FILE COL1,COL2    Extract specific columns (by number or name)
    filter FILE COL OP VALUE  Filter rows (OP: eq, ne, gt, lt, ge, le, contains, regex)
    stats FILE COL            Show statistics for a numeric column
    sort FILE COL [asc|desc]  Sort by a column
    unique FILE COL           Show unique values in a column
    count FILE COL            Count occurrences of each unique value
    convert FILE FORMAT       Convert to another format (json, markdown, html)
    merge FILE1 FILE2 COL     Merge two CSV files on a common column
    sample FILE N             Show N random rows

Options:
    -d, --delimiter CHAR     Field delimiter (default: ,)
    -H, --no-header          File has no header row
    -o, --output FILE        Write output to file
    -h, --help               Show this help

Examples:
    $SCRIPT_NAME columns data.csv
    $SCRIPT_NAME extract data.csv 1,3,5
    $SCRIPT_NAME filter data.csv 3 gt 100
    $SCRIPT_NAME stats data.csv 2
    $SCRIPT_NAME convert data.csv json
EOF
}

die() {
    echo "Error: $*" >&2
    exit 1
}

validate_file() {
    [[ -f "$1" ]] || die "File not found: $1"
}

cmd_columns() {
    local file="$1"
    local delim="$2"

    validate_file "$file"
    echo "Columns in '$file':"
    echo ""

    local header
    header=$(head -1 "$file")
    local i=1

    IFS="$delim" read -ra cols <<< "$header"
    for col in "${cols[@]}"; do
        col=$(echo "$col" | tr -d '\r' | xargs)
        printf "  %3d: %s\n" "$i" "$col"
        (( i++ ))
    done

    echo ""
    echo "Total: $(( i - 1 )) columns, $(( $(wc -l < "$file") - 1 )) data rows"
}

cmd_extract() {
    local file="$1"
    local columns="$2"
    local delim="$3"
    local has_header="$4"

    validate_file "$file"

    local header
    header=$(head -1 "$file")
    IFS="$delim" read -ra header_cols <<< "$header"

    # Resolve column names to numbers
    local col_nums=""
    IFS=',' read -ra requested <<< "$columns"
    for col in "${requested[@]}"; do
        if [[ "$col" =~ ^[0-9]+$ ]]; then
            col_nums+="${col},"
        else
            local found=false
            for i in "${!header_cols[@]}"; do
                local hcol
                hcol=$(echo "${header_cols[$i]}" | tr -d '\r' | xargs)
                if [[ "${hcol,,}" == "${col,,}" ]]; then
                    col_nums+="$(( i + 1 )),"
                    found=true
                    break
                fi
            done
            $found || die "Column not found: $col"
        fi
    done
    col_nums="${col_nums%,}"

    cut -d"$delim" -f"$col_nums" "$file"
}

cmd_filter() {
    local file="$1"
    local col="$2"
    local op="$3"
    local value="$4"
    local delim="$5"

    validate_file "$file"

    # Print header
    head -1 "$file"

    tail -n +2 "$file" | while IFS= read -r line; do
        local field
        field=$(echo "$line" | cut -d"$delim" -f"$col" | tr -d '\r' | xargs)

        local match=false
        case "$op" in
            eq)       [[ "$field" == "$value" ]] && match=true ;;
            ne)       [[ "$field" != "$value" ]] && match=true ;;
            gt)       (( $(echo "$field > $value" | bc -l 2>/dev/null) )) && match=true ;;
            lt)       (( $(echo "$field < $value" | bc -l 2>/dev/null) )) && match=true ;;
            ge)       (( $(echo "$field >= $value" | bc -l 2>/dev/null) )) && match=true ;;
            le)       (( $(echo "$field <= $value" | bc -l 2>/dev/null) )) && match=true ;;
            contains) [[ "$field" == *"$value"* ]] && match=true ;;
            regex)    [[ "$field" =~ $value ]] && match=true ;;
            *)        die "Unknown operator: $op" ;;
        esac

        $match && echo "$line"
    done
}

cmd_stats() {
    local file="$1"
    local col="$2"
    local delim="$3"

    validate_file "$file"

    local col_name
    col_name=$(head -1 "$file" | cut -d"$delim" -f"$col" | tr -d '\r' | xargs)

    echo "Statistics for column $col ($col_name):"
    echo "  ─────────────────────────────────"

    tail -n +2 "$file" | cut -d"$delim" -f"$col" | tr -d '\r' | awk '
    {
        val = $1 + 0
        sum += val
        sumsq += val * val
        count++
        if (count == 1 || val < min) min = val
        if (count == 1 || val > max) max = val
        values[count] = val
    }
    END {
        if (count == 0) { print "  No data"; exit }

        mean = sum / count
        variance = (sumsq / count) - (mean * mean)
        if (variance < 0) variance = 0
        stddev = sqrt(variance)

        # Sort for median
        for (i = 1; i <= count; i++)
            for (j = i + 1; j <= count; j++)
                if (values[i] > values[j]) {
                    tmp = values[i]; values[i] = values[j]; values[j] = tmp
                }

        if (count % 2 == 0)
            median = (values[count/2] + values[count/2+1]) / 2
        else
            median = values[(count+1)/2]

        printf "  Count:    %d\n", count
        printf "  Min:      %.4f\n", min
        printf "  Max:      %.4f\n", max
        printf "  Sum:      %.4f\n", sum
        printf "  Mean:     %.4f\n", mean
        printf "  Median:   %.4f\n", median
        printf "  Std Dev:  %.4f\n", stddev
        printf "  Range:    %.4f\n", max - min
    }'
}

cmd_sort() {
    local file="$1"
    local col="$2"
    local order="${3:-asc}"
    local delim="$4"

    validate_file "$file"

    head -1 "$file"

    local sort_flag="-k${col},${col}"
    if [[ "$order" == "desc" ]]; then
        sort_flag="-k${col},${col}r"
    fi

    # Try numeric sort first, fall back to lexicographic
    tail -n +2 "$file" | sort -t"$delim" "$sort_flag" -n 2>/dev/null \
        || tail -n +2 "$file" | sort -t"$delim" "$sort_flag"
}

cmd_unique() {
    local file="$1"
    local col="$2"
    local delim="$3"

    validate_file "$file"

    local col_name
    col_name=$(head -1 "$file" | cut -d"$delim" -f"$col" | tr -d '\r' | xargs)

    echo "Unique values in column $col ($col_name):"
    echo "  ─────────────────────────────────"

    tail -n +2 "$file" \
        | cut -d"$delim" -f"$col" \
        | tr -d '\r' \
        | sort -u \
        | while IFS= read -r val; do
            echo "  $val"
        done

    local unique_count
    unique_count=$(tail -n +2 "$file" | cut -d"$delim" -f"$col" | tr -d '\r' | sort -u | wc -l)
    echo ""
    echo "Total unique values: $unique_count"
}

cmd_count() {
    local file="$1"
    local col="$2"
    local delim="$3"

    validate_file "$file"

    local col_name
    col_name=$(head -1 "$file" | cut -d"$delim" -f"$col" | tr -d '\r' | xargs)

    echo "Value counts for column $col ($col_name):"
    echo "  ─────────────────────────────────"
    printf "  %6s  %s\n" "COUNT" "VALUE"

    tail -n +2 "$file" \
        | cut -d"$delim" -f"$col" \
        | tr -d '\r' \
        | sort \
        | uniq -c \
        | sort -rn \
        | while read -r count value; do
            printf "  %6d  %s\n" "$count" "$value"
        done
}

cmd_convert_json() {
    local file="$1"
    local delim="$2"

    validate_file "$file"

    local header
    header=$(head -1 "$file")
    IFS="$delim" read -ra cols <<< "$header"

    # Clean column names
    local clean_cols=()
    for col in "${cols[@]}"; do
        clean_cols+=("$(echo "$col" | tr -d '\r' | xargs)")
    done

    echo "["
    local first=true
    tail -n +2 "$file" | while IFS= read -r line; do
        IFS="$delim" read -ra values <<< "$line"

        if $first; then
            first=false
        else
            echo ","
        fi

        printf "  {"
        for i in "${!clean_cols[@]}"; do
            local val
            val=$(echo "${values[$i]:-}" | tr -d '\r' | xargs)
            val="${val//\"/\\\"}"
            if [[ $i -gt 0 ]]; then
                printf ", "
            fi
            printf '"%s": "%s"' "${clean_cols[$i]}" "$val"
        done
        printf "}"
    done

    echo ""
    echo "]"
}

cmd_convert_markdown() {
    local file="$1"
    local delim="$2"

    validate_file "$file"

    local header
    header=$(head -1 "$file")
    IFS="$delim" read -ra cols <<< "$header"

    # Header row
    printf "|"
    for col in "${cols[@]}"; do
        printf " %s |" "$(echo "$col" | tr -d '\r' | xargs)"
    done
    echo ""

    # Separator row
    printf "|"
    for _ in "${cols[@]}"; do
        printf " --- |"
    done
    echo ""

    # Data rows
    tail -n +2 "$file" | while IFS= read -r line; do
        IFS="$delim" read -ra values <<< "$line"
        printf "|"
        for val in "${values[@]}"; do
            printf " %s |" "$(echo "$val" | tr -d '\r' | xargs)"
        done
        echo ""
    done
}

cmd_convert() {
    local file="$1"
    local format="$2"
    local delim="$3"

    case "$format" in
        json)     cmd_convert_json "$file" "$delim" ;;
        markdown|md) cmd_convert_markdown "$file" "$delim" ;;
        *)        die "Unsupported format: $format (supported: json, markdown)" ;;
    esac
}

cmd_sample() {
    local file="$1"
    local n="$2"

    validate_file "$file"

    head -1 "$file"
    tail -n +2 "$file" | shuf | head -"$n"
}

main() {
    local delim=","
    local has_header=true
    local output=""

    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    local command="$1"
    shift

    if [[ "$command" == "-h" || "$command" == "--help" ]]; then
        usage
        exit 0
    fi

    # Parse trailing options
    local args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--delimiter) delim="$2"; shift 2 ;;
            -H|--no-header) has_header=false; shift ;;
            -o|--output)    output="$2"; shift 2 ;;
            -h|--help)      usage; exit 0 ;;
            *)              args+=("$1"); shift ;;
        esac
    done

    # Redirect output if specified
    if [[ -n "$output" ]]; then
        exec > "$output"
    fi

    case "$command" in
        columns)  cmd_columns "${args[0]}" "$delim" ;;
        extract)  cmd_extract "${args[0]}" "${args[1]}" "$delim" "$has_header" ;;
        filter)   cmd_filter "${args[0]}" "${args[1]}" "${args[2]}" "${args[3]}" "$delim" ;;
        stats)    cmd_stats "${args[0]}" "${args[1]}" "$delim" ;;
        sort)     cmd_sort "${args[0]}" "${args[1]}" "${args[2]:-asc}" "$delim" ;;
        unique)   cmd_unique "${args[0]}" "${args[1]}" "$delim" ;;
        count)    cmd_count "${args[0]}" "${args[1]}" "$delim" ;;
        convert)  cmd_convert "${args[0]}" "${args[1]}" "$delim" ;;
        sample)   cmd_sample "${args[0]}" "${args[1]:-5}" ;;
        *)        die "Unknown command: $command (use --help for usage)" ;;
    esac
}

main "$@"
