#!/bin/bash
# Pipelines and Redirection — stdout, stderr, pipes, tee, here strings

echo "=== Output Redirection ==="
echo "Hello, File!" > /tmp/redir_test.txt
echo "Appended line" >> /tmp/redir_test.txt
echo "Contents of /tmp/redir_test.txt:"
cat /tmp/redir_test.txt

echo ""
echo "=== Error Redirection ==="
ls /etc/passwd /nonexistent_file 2>/dev/null
echo "(stderr was discarded for the command above)"

ls /etc/passwd /nonexistent_file > /tmp/redir_out.txt 2> /tmp/redir_err.txt
echo "stdout: $(cat /tmp/redir_out.txt)"
echo "stderr: $(cat /tmp/redir_err.txt)"

echo ""
echo "=== Redirect Both stdout and stderr ==="
ls /etc/passwd /nonexistent 2>&1 | head -2
echo "(Both stdout and stderr piped to head)"

echo ""
echo "=== Discard Output ==="
ls /nonexistent 2>/dev/null
echo "stderr discarded (exit code: $?)"
ls /etc/passwd > /dev/null 2>&1
echo "all output discarded (exit code: $?)"

echo ""
echo "=== Pipes ==="
echo "First 5 users from /etc/passwd:"
cut -d: -f1 /etc/passwd | sort | head -5 | while read -r user; do
    echo "  - $user"
done

echo ""
echo "=== Pipe with wc ==="
echo "Lines in /etc/passwd: $(wc -l < /etc/passwd)"
echo "Words in this sentence: $(echo "how many words are here" | wc -w)"

echo ""
echo "=== tee — Write to File and stdout ==="
echo "Logged message" | tee /tmp/redir_log.txt | tr '[:lower:]' '[:upper:]'
echo "  (Original in file: $(cat /tmp/redir_log.txt))"

echo ""
echo "=== Here String ==="
result=$(grep "hello" <<< "hello world" | wc -l)
echo "grep found 'hello': $result match(es)"

echo ""
echo "=== Input Redirection ==="
line_count=$(wc -l < /etc/passwd)
echo "/etc/passwd has $line_count lines"

echo ""
echo "=== Process Substitution Preview ==="
paste <(seq 1 5) <(seq 6 10)

echo ""
echo "=== Practical: Pipeline for Data Processing ==="
echo "Top 5 largest directories in /etc:"
du -sh /etc/*/ 2>/dev/null | sort -rh | head -5 | while read -r size dir; do
    printf "  %-8s %s\n" "$size" "$dir"
done

# Cleanup
rm -f /tmp/redir_test.txt /tmp/redir_out.txt /tmp/redir_err.txt /tmp/redir_log.txt
