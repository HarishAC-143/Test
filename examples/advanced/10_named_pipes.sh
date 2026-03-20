#!/bin/bash
# Named Pipes (FIFOs) — inter-process communication

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "=== Creating a Named Pipe ==="
FIFO="$tmpdir/my_fifo"
mkfifo "$FIFO"
ls -la "$FIFO"
echo "Named pipe created (type 'p')"

echo ""
echo "=== Basic Read/Write ==="
echo "Sending message through named pipe..."

echo "Hello from writer!" > "$FIFO" &
writer_pid=$!

message=$(< "$FIFO")
wait "$writer_pid"
echo "Received: '$message'"

echo ""
echo "=== Multiple Messages ==="
FIFO2="$tmpdir/multi_fifo"
mkfifo "$FIFO2"

(
    for i in {1..5}; do
        echo "Message $i"
    done
) > "$FIFO2" &

echo "Reading multiple messages:"
while IFS= read -r line; do
    echo "  Received: $line"
done < "$FIFO2"
wait

echo ""
echo "=== Producer-Consumer Pattern ==="
FIFO3="$tmpdir/producer_consumer"
mkfifo "$FIFO3"

producer() {
    local pipe="$1"
    for item in "task_alpha" "task_beta" "task_gamma" "task_delta" "task_epsilon"; do
        echo "$item"
        sleep 0.1
    done > "$pipe"
}

consumer() {
    local pipe="$1"
    while IFS= read -r item; do
        echo "  Processing: $item"
    done < "$pipe"
}

producer "$FIFO3" &
consumer "$FIFO3"
wait

echo ""
echo "=== Bidirectional Communication ==="
FIFO_REQ="$tmpdir/request"
FIFO_RES="$tmpdir/response"
mkfifo "$FIFO_REQ" "$FIFO_RES"

server() {
    while IFS= read -r request; do
        [[ "$request" == "QUIT" ]] && break
        local result
        case "$request" in
            UPPER:*)  result=$(echo "${request#UPPER:}" | tr '[:lower:]' '[:upper:]') ;;
            LOWER:*)  result=$(echo "${request#LOWER:}" | tr '[:upper:]' '[:lower:]') ;;
            LEN:*)    result="${#request}"; ((result -= 4)) ;;
            *)        result="ERROR: unknown command" ;;
        esac
        echo "$result"
    done < "$FIFO_REQ" > "$FIFO_RES"
}

server &
server_pid=$!

echo "Client sending requests to server:"
for cmd in "UPPER:hello world" "LOWER:BASH SCRIPTING" "LEN:hello"; do
    echo "$cmd" > "$FIFO_REQ"
    read -r response < "$FIFO_RES"
    echo "  Request: '$cmd' -> Response: '$response'"
done

echo "QUIT" > "$FIFO_REQ"
wait "$server_pid" 2>/dev/null
echo "Server stopped."

echo ""
echo "=== Practical: Logging Service ==="
LOG_PIPE="$tmpdir/log_pipe"
LOG_FILE="$tmpdir/app.log"
mkfifo "$LOG_PIPE"

log_service() {
    while IFS= read -r entry; do
        echo "[$(date '+%H:%M:%S')] $entry"
    done < "$LOG_PIPE" >> "$LOG_FILE"
}

log_service &
log_pid=$!

echo "INFO: Service started" > "$LOG_PIPE"
echo "DEBUG: Processing request" > "$LOG_PIPE"
echo "WARN: High memory usage" > "$LOG_PIPE"

exec {LOG_PIPE_FD}>"$LOG_PIPE"
exec {LOG_PIPE_FD}>&-

sleep 0.5
wait "$log_pid" 2>/dev/null

echo "Log file contents:"
cat "$LOG_FILE"
