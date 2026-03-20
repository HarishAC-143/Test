#!/bin/bash
# Interactive Task Manager — add, list, complete, delete, search tasks
# Usage: ./05_task_manager.sh [COMMAND] [ARGS]
#        ./05_task_manager.sh --demo

set -euo pipefail

TASK_FILE="${TASK_FILE:-/tmp/bash_tasks_$$.dat}"
VERSION="1.0.0"

init_task_file() {
    if [[ ! -f "$TASK_FILE" ]]; then
        touch "$TASK_FILE"
    fi
}

generate_id() {
    printf '%04x' $((RANDOM))
}

add_task() {
    local title="$1"
    local priority="${2:-medium}"
    local category="${3:-general}"
    local id
    id=$(generate_id)
    local created
    created=$(date '+%Y-%m-%d %H:%M')

    echo "${id}|${title}|${priority}|${category}|pending|${created}" >> "$TASK_FILE"
    echo "Task added: [$id] $title (priority: $priority, category: $category)"
}

list_tasks() {
    local filter="${1:-all}"
    init_task_file

    local count=0
    local tasks=()

    while IFS='|' read -r id title priority category status created; do
        [[ -z "$id" ]] && continue
        if [[ "$filter" == "all" || "$filter" == "$status" ]]; then
            tasks+=("$id|$title|$priority|$category|$status|$created")
            ((count++)) || true
        fi
    done < "$TASK_FILE"

    if (( count == 0 )); then
        echo "No ${filter} tasks found."
        return
    fi

    local reset="\033[0m"

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  TASK LIST ($count tasks, filter: $filter)"
    echo "═══════════════════════════════════════════════════════════"

    for task_line in "${tasks[@]}"; do
        IFS='|' read -r id title priority category status created <<< "$task_line"

        local icon color
        case "$status" in
            pending)     icon="[ ]" ;;
            done)        icon="[x]" ;;
            in_progress) icon="[~]" ;;
            *)           icon="[?]" ;;
        esac

        case "$priority" in
            high)   color="\033[31m" ;;
            medium) color="\033[33m" ;;
            low)    color="\033[32m" ;;
            *)      color="" ;;
        esac

        printf "  %s ${color}[%s] %s${reset}\n" "$icon" "$id" "$title"
        printf "      Priority: %-8s Category: %-10s Created: %s\n" "$priority" "$category" "$created"
    done

    echo "═══════════════════════════════════════════════════════════"
    echo ""
}

complete_task() {
    local task_id="$1"
    local found=false
    local tmpfile
    tmpfile=$(mktemp)

    while IFS='|' read -r id title priority category status created; do
        if [[ "$id" == "$task_id" ]]; then
            echo "${id}|${title}|${priority}|${category}|done|${created}" >> "$tmpfile"
            echo "Task [$id] marked as done: $title"
            found=true
        else
            echo "${id}|${title}|${priority}|${category}|${status}|${created}" >> "$tmpfile"
        fi
    done < "$TASK_FILE"

    mv "$tmpfile" "$TASK_FILE"
    $found || echo "Task '$task_id' not found."
}

delete_task() {
    local task_id="$1"
    local found=false
    local tmpfile
    tmpfile=$(mktemp)

    while IFS='|' read -r id title priority category status created; do
        if [[ "$id" == "$task_id" ]]; then
            echo "Task [$id] deleted: $title"
            found=true
        else
            echo "${id}|${title}|${priority}|${category}|${status}|${created}" >> "$tmpfile"
        fi
    done < "$TASK_FILE"

    mv "$tmpfile" "$TASK_FILE"
    $found || echo "Task '$task_id' not found."
}

search_tasks() {
    local query="${1,,}"
    local found=0

    echo ""
    echo "Search results for '$query':"

    while IFS='|' read -r id title priority category status created; do
        [[ -z "$id" ]] && continue
        local lower_title="${title,,}"
        local lower_category="${category,,}"
        if [[ "$lower_title" == *"$query"* || "$lower_category" == *"$query"* ]]; then
            local icon
            case "$status" in
                done) icon="[x]" ;;
                *)    icon="[ ]" ;;
            esac
            echo "  $icon [$id] $title ($priority, $category)"
            ((found++)) || true
        fi
    done < "$TASK_FILE"

    if (( found == 0 )); then
        echo "  No tasks matching '$query'."
    else
        echo "  ($found result(s))"
    fi
}

stats() {
    local total=0 pending=0 done_count=0 in_progress=0
    local high=0 medium=0 low=0

    while IFS='|' read -r id title priority category status created; do
        [[ -z "$id" ]] && continue
        ((total++)) || true
        case "$status" in
            pending)     ((pending++)) || true ;;
            done)        ((done_count++)) || true ;;
            in_progress) ((in_progress++)) || true ;;
        esac
        case "$priority" in
            high)   ((high++)) || true ;;
            medium) ((medium++)) || true ;;
            low)    ((low++)) || true ;;
        esac
    done < "$TASK_FILE"

    echo ""
    echo "═══════════════════════════"
    echo "  TASK STATISTICS"
    echo "═══════════════════════════"
    echo "  Total:       $total"
    echo "  Pending:     $pending"
    echo "  In Progress: $in_progress"
    echo "  Completed:   $done_count"
    echo ""
    echo "  High:        $high"
    echo "  Medium:      $medium"
    echo "  Low:         $low"

    if (( total > 0 )); then
        local pct=$(( done_count * 100 / total ))
        echo ""
        echo "  Completion:  ${pct}%"
    fi
    echo "═══════════════════════════"
}

show_help() {
    cat << EOF
Bash Task Manager v${VERSION}

Usage: $(basename "$0") COMMAND [ARGS]

Commands:
    add TITLE [PRIORITY] [CATEGORY]   Add a new task
                                       Priority: high, medium (default), low
    list [STATUS]                      List tasks (all, pending, done)
    done TASK_ID                       Mark a task as completed
    delete TASK_ID                     Delete a task
    search QUERY                       Search tasks
    stats                              Show statistics
    interactive                        Launch interactive mode
    --demo                             Run a demo
    help                               Show this help
EOF
}

interactive_mode() {
    echo "╔═══════════════════════════════════════╗"
    echo "║  Bash Task Manager v${VERSION}           ║"
    echo "║  Type 'help' for commands, 'q' to quit║"
    echo "╚═══════════════════════════════════════╝"
    echo ""

    while true; do
        read -p "tasks> " -ra cmd || break
        [[ ${#cmd[@]} -eq 0 ]] && continue

        case "${cmd[0]}" in
            add)
                if [[ ${#cmd[@]} -lt 2 ]]; then
                    echo "Usage: add \"TITLE\" [PRIORITY] [CATEGORY]"
                else
                    add_task "${cmd[1]}" "${cmd[2]:-medium}" "${cmd[3]:-general}"
                fi
                ;;
            list|ls)    list_tasks "${cmd[1]:-all}" ;;
            done)
                [[ ${#cmd[@]} -lt 2 ]] && { echo "Usage: done TASK_ID"; continue; }
                complete_task "${cmd[1]}"
                ;;
            delete|rm)
                [[ ${#cmd[@]} -lt 2 ]] && { echo "Usage: delete TASK_ID"; continue; }
                delete_task "${cmd[1]}"
                ;;
            search|find)
                [[ ${#cmd[@]} -lt 2 ]] && { echo "Usage: search QUERY"; continue; }
                search_tasks "${cmd[1]}"
                ;;
            stats)      stats ;;
            help|h)     show_help ;;
            quit|exit|q) echo "Goodbye!"; break ;;
            *)          echo "Unknown: ${cmd[0]}. Type 'help'." ;;
        esac
    done
}

run_demo() {
    echo "═══════════════════════════════════"
    echo "  TASK MANAGER — DEMO"
    echo "═══════════════════════════════════"
    echo ""

    TASK_FILE=$(mktemp)
    trap 'rm -f "$TASK_FILE"' EXIT

    echo "Adding tasks..."
    add_task "Write project report" "high" "work"
    add_task "Buy groceries" "medium" "personal"
    add_task "Fix login bug" "high" "work"
    add_task "Read Bash tutorial" "low" "learning"
    add_task "Deploy to staging" "medium" "work"
    add_task "Plan team meeting" "medium" "work"
    echo ""

    echo "Listing all tasks..."
    list_tasks "all"

    echo "Completing first task..."
    local first_id
    first_id=$(head -1 "$TASK_FILE" | cut -d'|' -f1)
    complete_task "$first_id"
    echo ""

    echo "Searching for 'work' tasks..."
    search_tasks "work"
    echo ""

    echo "Statistics..."
    stats

    echo ""
    echo "Listing pending tasks..."
    list_tasks "pending"
}

# Main dispatch
init_task_file

case "${1:-help}" in
    add)
        shift
        add_task "${1:?Error: title required}" "${2:-medium}" "${3:-general}"
        ;;
    list|ls)        list_tasks "${2:-all}" ;;
    done)           complete_task "${2:?Error: task ID required}" ;;
    delete|rm)      delete_task "${2:?Error: task ID required}" ;;
    search|find)    search_tasks "${2:?Error: search query required}" ;;
    stats)          stats ;;
    interactive)    interactive_mode ;;
    --demo)         run_demo ;;
    help|-h|--help) show_help ;;
    *)              echo "Unknown command: $1"; show_help; exit 1 ;;
esac
