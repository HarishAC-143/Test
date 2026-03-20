#!/bin/bash
# 10_text_processing.sh -- Practical example: Text processing with sed, awk, and BASH
#
# Demonstrates real-world text processing scenarios combining
# multiple tools and techniques.
#
# Usage: ./10_text_processing.sh

set -euo pipefail

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "========================================="
echo "  Text Processing Examples"
echo "========================================="

# --- CREATE SAMPLE DATA ---
cat > "$WORK_DIR/employees.csv" << 'EOF'
id,name,department,salary,hire_date
1,Alice Johnson,Engineering,95000,2020-03-15
2,Bob Smith,Marketing,72000,2019-07-22
3,Charlie Brown,Engineering,105000,2018-01-10
4,Diana Prince,Sales,68000,2021-11-30
5,Eve Wilson,Engineering,115000,2017-06-05
6,Frank Miller,Marketing,78000,2020-09-18
7,Grace Lee,Sales,71000,2022-02-14
8,Henry Davis,Engineering,98000,2019-04-25
9,Iris Chen,Marketing,82000,2018-12-01
10,Jack Taylor,Sales,65000,2023-01-15
EOF

cat > "$WORK_DIR/access.log" << 'EOF'
2026-03-20 08:15:22 192.168.1.100 GET /index.html 200 1234
2026-03-20 08:15:23 192.168.1.101 GET /style.css 200 5678
2026-03-20 08:16:01 192.168.1.100 POST /api/login 200 256
2026-03-20 08:16:15 10.0.0.50 GET /admin 403 128
2026-03-20 08:17:00 192.168.1.102 GET /index.html 200 1234
2026-03-20 08:17:30 10.0.0.50 GET /admin 403 128
2026-03-20 08:18:00 192.168.1.100 GET /api/data 200 4096
2026-03-20 08:18:45 192.168.1.103 GET /missing 404 64
2026-03-20 08:19:00 192.168.1.100 POST /api/upload 500 32
2026-03-20 08:19:30 192.168.1.101 GET /index.html 200 1234
2026-03-20 08:20:00 10.0.0.50 DELETE /api/users 403 128
2026-03-20 08:20:15 192.168.1.104 GET /about.html 200 2048
EOF

cat > "$WORK_DIR/config.properties" << 'EOF'
# Application Configuration
app.name=MyApplication
app.version=2.5.1
app.debug=false

# Database Settings
db.host=production-db.example.com
db.port=5432
db.name=myapp_prod
db.pool.size=20

# Cache Settings
cache.enabled=true
cache.ttl=3600
cache.max.size=1000

# Feature Flags
feature.dark_mode=true
feature.notifications=false
feature.beta_access=true
EOF

echo "Sample data created."

# --- EXAMPLE 1: CSV ANALYSIS ---
echo ""
echo "==========================================="
echo "  1. CSV Data Analysis (employees.csv)"
echo "==========================================="

echo ""
echo "--- All Employees ---"
printf "%-4s %-18s %-14s %8s  %s\n" "ID" "NAME" "DEPT" "SALARY" "HIRED"
printf "%s\n" "$(printf -- '-%.0s' {1..65})"
tail -n +2 "$WORK_DIR/employees.csv" | while IFS=',' read -r id name dept salary hired; do
    printf "%-4s %-18s %-14s %8s  %s\n" "$id" "$name" "$dept" "$salary" "$hired"
done

echo ""
echo "--- Department Statistics ---"
awk -F',' 'NR>1 {
    dept_count[$3]++
    dept_sum[$3] += $4
    if (!dept_min[$3] || $4 < dept_min[$3]) dept_min[$3] = $4
    if ($4 > dept_max[$3]) dept_max[$3] = $4
}
END {
    printf "%-14s %5s %10s %10s %10s\n", "Department", "Count", "Avg Salary", "Min", "Max"
    printf "%s\n", "-------------------------------------------------------------"
    for (d in dept_count) {
        printf "%-14s %5d %10.0f %10d %10d\n", d, dept_count[d], dept_sum[d]/dept_count[d], dept_min[d], dept_max[d]
    }
}' "$WORK_DIR/employees.csv"

echo ""
echo "--- Top 3 Highest Paid ---"
tail -n +2 "$WORK_DIR/employees.csv" | sort -t',' -k4 -rn | head -3 | \
    while IFS=',' read -r id name dept salary hired; do
        echo "  $name ($dept): \$$salary"
    done

echo ""
echo "--- Engineering Team ---"
awk -F',' '$3 == "Engineering" {printf "  %s - $%s (since %s)\n", $2, $4, $5}' "$WORK_DIR/employees.csv"

# --- EXAMPLE 2: LOG ANALYSIS ---
echo ""
echo "==========================================="
echo "  2. Access Log Analysis (access.log)"
echo "==========================================="

echo ""
echo "--- Request Count by Status Code ---"
awk '{count[$6]++} END {
    printf "  %-6s %s\n", "CODE", "COUNT"
    printf "  %s\n", "------------"
    for (code in count) printf "  %-6s %d\n", code, count[code]
}' "$WORK_DIR/access.log" | sort

echo ""
echo "--- Requests Per IP ---"
awk '{count[$3]++} END {
    for (ip in count) printf "  %-18s %d requests\n", ip, count[ip]
}' "$WORK_DIR/access.log" | sort -t' ' -k2 -rn

echo ""
echo "--- Failed Requests (4xx/5xx) ---"
awk '$6 >= 400 {
    printf "  [%s] %s %s %s -> %s\n", $2, $3, $5, $4, $6
}' "$WORK_DIR/access.log"

echo ""
echo "--- Total Bytes Transferred ---"
total_bytes=$(awk '{sum += $7} END {print sum}' "$WORK_DIR/access.log")
total_kb=$(awk "BEGIN {printf \"%.2f\", $total_bytes / 1024}")
echo "  Total: $total_bytes bytes ($total_kb KB)"

echo ""
echo "--- Unique Visitors ---"
unique_ips=$(awk '{print $3}' "$WORK_DIR/access.log" | sort -u | wc -l)
echo "  $unique_ips unique IP addresses"

# --- EXAMPLE 3: CONFIGURATION PROCESSING ---
echo ""
echo "==========================================="
echo "  3. Config File Processing"
echo "==========================================="

echo ""
echo "--- Parsed Configuration ---"
declare -A config
current_section=""

while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Extract key=value
    if [[ "$line" =~ ^([a-zA-Z0-9._]+)=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        config[$key]="$value"
    fi
done < "$WORK_DIR/config.properties"

echo "Loaded ${#config[@]} configuration entries:"
for key in $(echo "${!config[@]}" | tr ' ' '\n' | sort); do
    printf "  %-30s = %s\n" "$key" "${config[$key]}"
done

echo ""
echo "--- Feature Flags ---"
for key in "${!config[@]}"; do
    if [[ "$key" == feature.* ]]; then
        feature_name="${key#feature.}"
        status="${config[$key]}"
        if [[ "$status" == "true" ]]; then
            printf "  %-20s : ENABLED\n" "$feature_name"
        else
            printf "  %-20s : DISABLED\n" "$feature_name"
        fi
    fi
done

# --- EXAMPLE 4: SED TRANSFORMATIONS ---
echo ""
echo "==========================================="
echo "  4. sed Transformations"
echo "==========================================="

echo ""
echo "--- Convert CSV to pipe-delimited ---"
head -3 "$WORK_DIR/employees.csv" | sed 's/,/ | /g'

echo ""
echo "--- Extract and reformat dates ---"
echo "Original -> Reformatted:"
grep -oP '\d{4}-\d{2}-\d{2}' "$WORK_DIR/employees.csv" | \
    sort -u | while read -r date; do
        reformatted=$(echo "$date" | sed 's/\([0-9]*\)-\([0-9]*\)-\([0-9]*\)/\3\/\2\/\1/')
        echo "  $date -> $reformatted"
    done

echo ""
echo "--- Mask Sensitive Data ---"
echo "Masking IP addresses in log:"
head -3 "$WORK_DIR/access.log" | \
    sed 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/xxx.xxx.xxx.xxx/g'

# --- EXAMPLE 5: MULTI-TOOL PIPELINE ---
echo ""
echo "==========================================="
echo "  5. Multi-Tool Pipelines"
echo "==========================================="

echo ""
echo "--- Generate salary report as HTML table ---"
{
    echo "<table>"
    echo "  <tr><th>Name</th><th>Department</th><th>Salary</th></tr>"
    tail -n +2 "$WORK_DIR/employees.csv" | sort -t',' -k4 -rn | \
        awk -F',' '{printf "  <tr><td>%s</td><td>%s</td><td>$%s</td></tr>\n", $2, $3, $4}'
    echo "</table>"
} | tee "$WORK_DIR/salary_report.html" | head -5
echo "  ... ($(wc -l < "$WORK_DIR/salary_report.html") total lines saved to salary_report.html)"

echo ""
echo "--- Word frequency in this script ---"
echo "Top 10 most common words in access.log:"
tr -cs '[:alpha:]' '\n' < "$WORK_DIR/access.log" | \
    tr '[:upper:]' '[:lower:]' | \
    sort | uniq -c | sort -rn | head -10 | \
    while read -r count word; do
        printf "  %-15s %d\n" "$word" "$count"
    done

echo ""
echo "All text processing examples complete!"
