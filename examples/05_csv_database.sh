#!/usr/bin/env bash
#
# 05_csv_database.sh — Interactive CRUD interface for a CSV "database"
#
# Usage: ./05_csv_database.sh [database_file.csv]
#

set -euo pipefail

DB_FILE="${1:-contacts.csv}"

init_db() {
    if [[ ! -f "$DB_FILE" ]]; then
        echo "id,name,email,phone" > "$DB_FILE"
        echo "Database initialized: $DB_FILE"
    fi
}

next_id() {
    if [[ $(wc -l < "$DB_FILE") -le 1 ]]; then
        echo 1
    else
        tail -n +2 "$DB_FILE" | cut -d, -f1 | sort -n | tail -1 | awk '{print $1+1}'
    fi
}

list_records() {
    local count
    count=$(( $(wc -l < "$DB_FILE") - 1 ))
    if (( count <= 0 )); then
        echo "No records found."
        return
    fi
    echo ""
    printf "%-5s %-20s %-30s %-15s\n" "ID" "Name" "Email" "Phone"
    printf "%-5s %-20s %-30s %-15s\n" "---" "----" "-----" "-----"
    tail -n +2 "$DB_FILE" | while IFS=, read -r id name email phone; do
        printf "%-5s %-20s %-30s %-15s\n" "$id" "$name" "$email" "$phone"
    done
    echo ""
    echo "Total: $count record(s)"
}

add_record() {
    read -rp "Name:  " name
    read -rp "Email: " email
    read -rp "Phone: " phone
    local id
    id=$(next_id)
    echo "$id,$name,$email,$phone" >> "$DB_FILE"
    echo "Record added (ID: $id)"
}

search_records() {
    read -rp "Search term: " term
    echo ""
    printf "%-5s %-20s %-30s %-15s\n" "ID" "Name" "Email" "Phone"
    printf "%-5s %-20s %-30s %-15s\n" "---" "----" "-----" "-----"
    grep -i "$term" "$DB_FILE" | while IFS=, read -r id name email phone; do
        printf "%-5s %-20s %-30s %-15s\n" "$id" "$name" "$email" "$phone"
    done
}

delete_record() {
    read -rp "Enter ID to delete: " del_id
    if grep -q "^${del_id}," "$DB_FILE"; then
        local tmpfile
        tmpfile=$(mktemp)
        head -1 "$DB_FILE" > "$tmpfile"
        tail -n +2 "$DB_FILE" | grep -v "^${del_id}," >> "$tmpfile"
        mv "$tmpfile" "$DB_FILE"
        echo "Record $del_id deleted."
    else
        echo "Record not found."
    fi
}

init_db

PS3="Choose an action: "
select action in "List" "Add" "Search" "Delete" "Quit"; do
    case "$action" in
        List)   list_records ;;
        Add)    add_record ;;
        Search) search_records ;;
        Delete) delete_record ;;
        Quit)   echo "Goodbye!"; break ;;
        *)      echo "Invalid choice" ;;
    esac
done
