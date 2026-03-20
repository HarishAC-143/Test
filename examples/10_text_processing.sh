#!/bin/bash
# Text processing with grep, sed, and awk

DEMO_DIR=$(mktemp -d)
trap 'rm -rf "$DEMO_DIR"' EXIT

cat > "$DEMO_DIR/access.log" << 'EOF'
2026-03-20 08:15:23 INFO  User alice logged in from 192.168.1.10
2026-03-20 08:16:45 ERROR Database connection timeout
2026-03-20 08:17:02 WARN  Disk usage at 85%
2026-03-20 08:18:30 INFO  User bob logged in from 10.0.0.5
2026-03-20 08:19:11 ERROR Failed to read config file
2026-03-20 08:20:05 INFO  Request processed in 234ms
2026-03-20 08:21:15 WARN  Memory usage high: 92%
2026-03-20 08:22:00 INFO  User charlie logged in from 172.16.0.3
2026-03-20 08:23:33 ERROR Connection refused: port 5432
2026-03-20 08:24:10 INFO  Cache invalidated, 150 entries removed
EOF

echo "=== grep Examples ==="
echo ""
echo "--- Lines containing 'ERROR' ---"
grep "ERROR" "$DEMO_DIR/access.log"

echo ""
echo "--- Case-insensitive search for 'user' ---"
grep -i "user" "$DEMO_DIR/access.log"

echo ""
echo "--- Count of each log level ---"
for level in INFO WARN ERROR; do
    count=$(grep -c "$level" "$DEMO_DIR/access.log")
    echo "  $level: $count"
done

echo ""
echo "--- Lines NOT matching INFO ---"
grep -v "INFO" "$DEMO_DIR/access.log"

echo ""
echo "--- Extended regex: extract IP addresses ---"
grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$DEMO_DIR/access.log"

echo ""
echo "=== sed Examples ==="
echo ""
echo "--- Replace ERROR with [CRITICAL] ---"
sed 's/ERROR/[CRITICAL]/g' "$DEMO_DIR/access.log" | grep CRITICAL

echo ""
echo "--- Delete lines containing WARN ---"
sed '/WARN/d' "$DEMO_DIR/access.log" | wc -l
echo "lines remaining (from original 10)"

echo ""
echo "--- Extract just timestamps ---"
sed -n 's/^\([0-9-]* [0-9:]*\).*/\1/p' "$DEMO_DIR/access.log" | head -5

echo ""
echo "--- Add line numbers ---"
sed '=' "$DEMO_DIR/access.log" | sed 'N;s/\n/\t/' | head -5

echo ""
echo "=== awk Examples ==="
echo ""
echo "--- Print date, level, and message ---"
awk '{printf "%-12s %-7s %s\n", $1, $3, substr($0, index($0,$4))}' \
    "$DEMO_DIR/access.log" | head -5

echo ""
echo "--- Count log levels with awk ---"
awk '{count[$3]++} END {for (level in count) printf "  %-8s: %d\n", level, count[level]}' \
    "$DEMO_DIR/access.log"

echo ""
echo "--- Filter ERROR lines and format ---"
awk '$3 == "ERROR" {print NR": "$0}' "$DEMO_DIR/access.log"

echo ""
echo "=== Practical: Employee Salary Report ==="
cat > "$DEMO_DIR/employees.csv" << 'EOF'
Name,Department,Salary
Alice,Engineering,95000
Bob,Marketing,72000
Charlie,Engineering,105000
Diana,Sales,68000
Eve,Engineering,98000
Frank,Marketing,75000
Grace,Sales,71000
Henry,Engineering,112000
EOF

echo "--- Department Salary Summary ---"
awk -F',' '
NR > 1 {
    dept_sum[$2] += $3
    dept_count[$2]++
    total += $3
    if ($3 > max_sal) { max_sal = $3; max_name = $1 }
}
END {
    printf "\n  %-15s %8s %8s %10s\n", "Department", "Count", "Avg", "Total"
    printf "  %s\n", "───────────────────────────────────────────"
    for (d in dept_sum) {
        printf "  %-15s %8d %8d %10d\n", d, dept_count[d], dept_sum[d]/dept_count[d], dept_sum[d]
    }
    printf "\n  Overall total: $%d\n", total
    printf "  Highest paid: %s ($%d)\n", max_name, max_sal
}' "$DEMO_DIR/employees.csv"
