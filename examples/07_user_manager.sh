#!/usr/bin/env bash
# =============================================================================
# User Account Manager (Menu-Driven)
#
# A menu-driven script for managing user accounts on a Linux system.
# Demonstrates interactive menus, input validation, arrays, and functions.
#
# Note: Actual user creation/deletion requires root privileges.
# Run with: sudo ./07_user_manager.sh
#
# Usage: ./07_user_manager.sh
# =============================================================================
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/tmp/user_manager.log"

log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*" >> "$LOG_FILE"
}

print_banner() {
    cat << 'EOF'
  ╔══════════════════════════════════════════╗
  ║        USER ACCOUNT MANAGER              ║
  ║        ────────────────────              ║
  ║   Manage system user accounts easily     ║
  ╚══════════════════════════════════════════╝
EOF
}

print_menu() {
    echo ""
    echo "  ┌──────────────────────────────────────┐"
    echo "  │  1)  List all users                  │"
    echo "  │  2)  Search for a user               │"
    echo "  │  3)  Show user details               │"
    echo "  │  4)  Add a new user                  │"
    echo "  │  5)  Delete a user                   │"
    echo "  │  6)  Lock/Unlock a user account      │"
    echo "  │  7)  Change user's shell             │"
    echo "  │  8)  List groups                     │"
    echo "  │  9)  Show users by shell             │"
    echo "  │ 10)  System user statistics          │"
    echo "  │  0)  Exit                            │"
    echo "  └──────────────────────────────────────┘"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "  Warning: Some operations require root privileges."
        echo "  Run with: sudo $SCRIPT_NAME"
        echo ""
        return 1
    fi
    return 0
}

pause() {
    echo ""
    read -rp "  Press Enter to continue..."
}

validate_username() {
    local username="$1"
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo "  Error: Invalid username format." >&2
        echo "  Usernames must start with a lowercase letter or underscore," >&2
        echo "  followed by lowercase letters, digits, underscores, or hyphens." >&2
        return 1
    fi
    if (( ${#username} > 32 )); then
        echo "  Error: Username must be 32 characters or less." >&2
        return 1
    fi
    return 0
}

list_users() {
    echo ""
    echo "  ═══ USER LIST ═══"
    echo ""

    local format="  %-20s %-6s %-6s %-25s %s\n"
    printf "$format" "USERNAME" "UID" "GID" "HOME" "SHELL"
    echo "  $(printf -- '-%.0s' {1..80})"

    local count=0
    while IFS=: read -r username _ uid gid _ home shell; do
        # Skip system users (UID < 1000) unless they're root
        if (( uid >= 1000 )) || [[ "$username" == "root" ]]; then
            printf "$format" "$username" "$uid" "$gid" "$home" "$shell"
            (( count++ ))
        fi
    done < /etc/passwd

    echo ""
    echo "  Total users displayed: $count"
    echo "  (System accounts with UID < 1000 are hidden except root)"
}

search_user() {
    echo ""
    read -rp "  Enter search term: " search_term

    if [[ -z "$search_term" ]]; then
        echo "  Error: Search term cannot be empty."
        return
    fi

    echo ""
    echo "  ═══ SEARCH RESULTS for '$search_term' ═══"
    echo ""

    local found=0
    while IFS=: read -r username _ uid gid gecos home shell; do
        if [[ "$username" == *"$search_term"* ]] || [[ "$gecos" == *"$search_term"* ]]; then
            printf "  %-20s (UID: %s, Shell: %s)\n" "$username" "$uid" "$shell"
            (( found++ ))
        fi
    done < /etc/passwd

    if (( found == 0 )); then
        echo "  No users matching '$search_term' found."
    else
        echo ""
        echo "  Found $found matching user(s)."
    fi
}

show_user_details() {
    echo ""
    read -rp "  Enter username: " username

    if ! id "$username" &>/dev/null; then
        echo "  Error: User '$username' not found."
        return
    fi

    echo ""
    echo "  ═══ USER DETAILS: $username ═══"
    echo ""

    local user_line
    user_line=$(grep "^${username}:" /etc/passwd)
    IFS=: read -r _ _ uid gid gecos home shell <<< "$user_line"

    echo "  Username:    $username"
    echo "  UID:         $uid"
    echo "  GID:         $gid"
    echo "  Full Name:   ${gecos:-N/A}"
    echo "  Home Dir:    $home"
    echo "  Shell:       $shell"
    echo "  Groups:      $(id -nG "$username" 2>/dev/null)"

    # Account status
    if command -v passwd &>/dev/null; then
        local status
        status=$(passwd -S "$username" 2>/dev/null | awk '{print $2}') || true
        case "$status" in
            P|PS) echo "  Status:      Active (password set)" ;;
            L|LK) echo "  Status:      Locked" ;;
            N|NP) echo "  Status:      No password" ;;
            *)    echo "  Status:      Unknown ($status)" ;;
        esac
    fi

    # Last login
    if command -v lastlog &>/dev/null; then
        local last_login
        last_login=$(lastlog -u "$username" 2>/dev/null | tail -1)
        echo "  Last Login:  $last_login"
    fi

    # Home directory info
    if [[ -d "$home" ]]; then
        local dir_size
        dir_size=$(du -sh "$home" 2>/dev/null | cut -f1 || echo "N/A")
        echo "  Home Size:   $dir_size"
        echo "  Home Exists: Yes"
    else
        echo "  Home Exists: No"
    fi
}

add_user() {
    if ! check_root; then
        echo "  Root privileges required to add users."
        return
    fi

    echo ""
    echo "  ═══ ADD NEW USER ═══"
    echo ""

    read -rp "  Username: " username
    validate_username "$username" || return

    if id "$username" &>/dev/null; then
        echo "  Error: User '$username' already exists."
        return
    fi

    read -rp "  Full name: " fullname
    read -rp "  Shell [/bin/bash]: " user_shell
    user_shell="${user_shell:-/bin/bash}"

    read -rp "  Create home directory? [Y/n]: " create_home
    create_home="${create_home:-Y}"

    echo ""
    echo "  Creating user with the following settings:"
    echo "    Username:  $username"
    echo "    Full Name: $fullname"
    echo "    Shell:     $user_shell"
    echo "    Home Dir:  $([[ "${create_home^^}" == "Y" ]] && echo "Yes" || echo "No")"
    echo ""

    read -rp "  Proceed? [y/N]: " confirm
    if [[ "${confirm^^}" != "Y" ]]; then
        echo "  Cancelled."
        return
    fi

    local useradd_args=("-s" "$user_shell" "-c" "$fullname")
    if [[ "${create_home^^}" == "Y" ]]; then
        useradd_args+=("-m")
    fi

    if useradd "${useradd_args[@]}" "$username"; then
        echo "  User '$username' created successfully."
        log "User created: $username"

        read -rp "  Set password now? [Y/n]: " set_pwd
        set_pwd="${set_pwd:-Y}"
        if [[ "${set_pwd^^}" == "Y" ]]; then
            passwd "$username"
        fi
    else
        echo "  Error: Failed to create user '$username'."
        log "Failed to create user: $username"
    fi
}

delete_user() {
    if ! check_root; then
        echo "  Root privileges required to delete users."
        return
    fi

    echo ""
    echo "  ═══ DELETE USER ═══"
    echo ""

    read -rp "  Username to delete: " username

    if ! id "$username" &>/dev/null; then
        echo "  Error: User '$username' not found."
        return
    fi

    local uid
    uid=$(id -u "$username")
    if (( uid == 0 )); then
        echo "  Error: Cannot delete root user!"
        return
    fi

    echo ""
    echo "  WARNING: You are about to delete user '$username'"

    read -rp "  Remove home directory too? [y/N]: " remove_home
    read -rp "  Type 'DELETE' to confirm: " confirm

    if [[ "$confirm" != "DELETE" ]]; then
        echo "  Cancelled."
        return
    fi

    local userdel_args=()
    if [[ "${remove_home^^}" == "Y" ]]; then
        userdel_args+=("-r")
    fi

    if userdel "${userdel_args[@]}" "$username" 2>/dev/null; then
        echo "  User '$username' deleted successfully."
        log "User deleted: $username (home removed: ${remove_home:-N})"
    else
        echo "  Error: Failed to delete user '$username'."
        log "Failed to delete user: $username"
    fi
}

lock_unlock_user() {
    if ! check_root; then
        echo "  Root privileges required."
        return
    fi

    echo ""
    read -rp "  Enter username: " username

    if ! id "$username" &>/dev/null; then
        echo "  Error: User '$username' not found."
        return
    fi

    local status
    status=$(passwd -S "$username" 2>/dev/null | awk '{print $2}') || true

    echo ""
    case "$status" in
        L|LK)
            echo "  Account '$username' is currently LOCKED."
            read -rp "  Unlock it? [Y/n]: " confirm
            if [[ "${confirm^^}" != "N" ]]; then
                usermod -U "$username" && echo "  Account unlocked." || echo "  Failed to unlock."
                log "User unlocked: $username"
            fi
            ;;
        P|PS)
            echo "  Account '$username' is currently ACTIVE."
            read -rp "  Lock it? [Y/n]: " confirm
            if [[ "${confirm^^}" != "N" ]]; then
                usermod -L "$username" && echo "  Account locked." || echo "  Failed to lock."
                log "User locked: $username"
            fi
            ;;
        *)
            echo "  Account status: $status"
            ;;
    esac
}

change_shell() {
    if ! check_root; then
        echo "  Root privileges required."
        return
    fi

    echo ""
    read -rp "  Enter username: " username

    if ! id "$username" &>/dev/null; then
        echo "  Error: User '$username' not found."
        return
    fi

    local current_shell
    current_shell=$(getent passwd "$username" | cut -d: -f7)
    echo "  Current shell: $current_shell"
    echo ""

    echo "  Available shells:"
    local shells=()
    local i=1
    while IFS= read -r shell; do
        if [[ -x "$shell" ]]; then
            shells+=("$shell")
            printf "    %d) %s\n" "$i" "$shell"
            (( i++ ))
        fi
    done < /etc/shells

    echo ""
    read -rp "  Select shell number (or enter path): " choice

    local new_shell
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#shells[@]} )); then
        new_shell="${shells[$((choice - 1))]}"
    else
        new_shell="$choice"
    fi

    if [[ ! -x "$new_shell" ]]; then
        echo "  Error: '$new_shell' is not a valid executable shell."
        return
    fi

    if chsh -s "$new_shell" "$username" 2>/dev/null; then
        echo "  Shell changed to $new_shell for $username."
        log "Shell changed: $username -> $new_shell"
    else
        echo "  Error: Failed to change shell."
    fi
}

list_groups() {
    echo ""
    echo "  ═══ SYSTEM GROUPS ═══"
    echo ""

    printf "  %-20s %-6s %s\n" "GROUP" "GID" "MEMBERS"
    echo "  $(printf -- '-%.0s' {1..65})"

    while IFS=: read -r group _ gid members; do
        if [[ -n "$members" ]] || (( gid >= 1000 )); then
            printf "  %-20s %-6s %s\n" "$group" "$gid" "${members:-<none>}"
        fi
    done < /etc/group
}

users_by_shell() {
    echo ""
    echo "  ═══ USERS BY SHELL ═══"
    echo ""

    declare -A shell_users
    declare -A shell_counts

    while IFS=: read -r username _ _ _ _ _ shell; do
        shell_users["$shell"]+="$username "
        (( shell_counts["$shell"]=${shell_counts["$shell"]:-0} + 1 ))
    done < /etc/passwd

    for shell in $(echo "${!shell_counts[@]}" | tr ' ' '\n' | sort); do
        printf "  %s (%d users)\n" "$shell" "${shell_counts[$shell]}"
        echo "${shell_users[$shell]}" | tr ' ' '\n' | sort | while read -r user; do
            [[ -n "$user" ]] && echo "    - $user"
        done
        echo ""
    done
}

user_statistics() {
    echo ""
    echo "  ═══ USER STATISTICS ═══"
    echo ""

    local total_users system_users regular_users locked_users
    total_users=$(wc -l < /etc/passwd)
    system_users=$(awk -F: '$3 < 1000 {count++} END {print count}' /etc/passwd)
    regular_users=$(awk -F: '$3 >= 1000 {count++} END {print count}' /etc/passwd)

    echo "  Total accounts:     $total_users"
    echo "  System accounts:    $system_users"
    echo "  Regular accounts:   $regular_users"

    locked_users=0
    if command -v passwd &>/dev/null && [[ $EUID -eq 0 ]]; then
        while IFS=: read -r username _ _ _ _ _ _; do
            local status
            status=$(passwd -S "$username" 2>/dev/null | awk '{print $2}') || true
            [[ "$status" == "L" || "$status" == "LK" ]] && (( locked_users++ ))
        done < /etc/passwd
        echo "  Locked accounts:    $locked_users"
    fi

    echo ""
    echo "  Shell Distribution:"
    awk -F: '{print $7}' /etc/passwd | sort | uniq -c | sort -rn | while read -r count shell; do
        printf "    %-30s %d\n" "$shell" "$count"
    done

    echo ""
    echo "  Recently Created (by UID, highest first):"
    sort -t: -k3 -rn /etc/passwd | head -5 | while IFS=: read -r username _ uid _ _ home _; do
        printf "    %-20s UID: %s  Home: %s\n" "$username" "$uid" "$home"
    done
}

main() {
    print_banner

    while true; do
        print_menu
        read -rp "  Select option: " choice

        case "$choice" in
            1)  list_users ;;
            2)  search_user ;;
            3)  show_user_details ;;
            4)  add_user ;;
            5)  delete_user ;;
            6)  lock_unlock_user ;;
            7)  change_shell ;;
            8)  list_groups ;;
            9)  users_by_shell ;;
            10) user_statistics ;;
            0)
                echo ""
                echo "  Goodbye!"
                log "Session ended"
                exit 0
                ;;
            *)
                echo "  Invalid option. Please try again."
                ;;
        esac

        pause
    done
}

main "$@"
