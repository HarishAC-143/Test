#!/bin/bash
# Process Substitution — <() and >(), comparison with pipes

echo "=== Basic Process Substitution <() ==="
echo "Comparing output of two commands:"
diff <(echo -e "apple\nbanana\ncherry") <(echo -e "apple\nblueberry\ncherry") || true
echo "(Differences shown above)"

echo ""
echo "=== Reading from Process Substitution ==="
echo "First 5 processes:"
while IFS= read -r line; do
    echo "  $line"
done < <(ps aux | head -6 | tail -5)

echo ""
echo "=== Variable Scope: Pipe vs Process Substitution ==="

echo "--- Using pipe (subshell — variables lost) ---"
count=0
echo -e "a\nb\nc" | while read -r line; do
    ((count++))
done
echo "  count after pipe: $count (expected: 0 — subshell!)"

echo "--- Using process substitution (no subshell) ---"
count=0
while read -r line; do
    ((count++))
done < <(echo -e "a\nb\nc")
echo "  count after proc sub: $count (expected: 3 — preserved!)"

echo ""
echo "=== Compare Sorted vs Unsorted ==="
tmpfile=$(mktemp)
echo -e "cherry\napple\nbanana\ndate\nelderberry" > "$tmpfile"
echo "Original file vs sorted:"
diff "$tmpfile" <(sort "$tmpfile") || true
rm "$tmpfile"

echo ""
echo "=== Merge Sorted Streams ==="
echo "Merging two sorted sequences:"
paste <(seq 1 5) <(seq 6 10) <(seq 11 15) | column -t

echo ""
echo "=== Output Process Substitution >() ==="
tmpout1=$(mktemp)
tmpout2=$(mktemp)
echo "Hello World from Bash" | tee >(wc -w > "$tmpout1") >(tr '[:lower:]' '[:upper:]' > "$tmpout2") > /dev/null
sleep 0.2
echo "Word count: $(cat "$tmpout1")"
echo "Uppercase:  $(cat "$tmpout2")"
rm -f "$tmpout1" "$tmpout2"

echo ""
echo "=== Practical: Compare Directory Contents ==="
dir1=$(mktemp -d)
dir2=$(mktemp -d)
touch "$dir1"/{a,b,c,d}.txt
touch "$dir2"/{b,c,d,e}.txt

echo "Files only in dir1, only in dir2, or in both:"
comm <(ls "$dir1" | sort) <(ls "$dir2" | sort) | while IFS=$'\t' read -r only1 only2 both; do
    [[ -n "$only1" ]] && echo "  Only in dir1: $only1"
    [[ -n "$only2" ]] && echo "  Only in dir2: $only2"
    [[ -n "$both" ]]  && echo "  In both:      $both"
done

rm -rf "$dir1" "$dir2"

echo ""
echo "=== Practical: Log Processing with Multiple Outputs ==="
generate_log() {
    echo "2026-03-20 10:00:00 INFO  Application started"
    echo "2026-03-20 10:00:01 DEBUG Loading config"
    echo "2026-03-20 10:00:02 WARN  Config file missing, using defaults"
    echo "2026-03-20 10:00:03 ERROR Database connection failed"
    echo "2026-03-20 10:00:04 INFO  Retrying connection"
    echo "2026-03-20 10:00:05 INFO  Connected successfully"
}

echo "Processing log entries:"
errors_file=$(mktemp)
warnings_file=$(mktemp)

generate_log | tee >(grep "ERROR" > "$errors_file") >(grep "WARN" > "$warnings_file") > /dev/null
sleep 0.2

echo "  Errors found:"
while IFS= read -r line; do echo "    $line"; done < "$errors_file"
echo "  Warnings found:"
while IFS= read -r line; do echo "    $line"; done < "$warnings_file"

rm -f "$errors_file" "$warnings_file"
