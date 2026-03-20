#!/bin/bash
# Security Best Practices — quoting, validation, safe patterns

echo "=== 1. Always Quote Variables ==="
file="my file with spaces.txt"
echo "Quoted correctly: \"$file\""

echo ""
echo "=== 2. Use [[ ]] Instead of [ ] ==="
name=""
if [[ -z "$name" ]]; then
    echo "Empty string detected safely with [[ ]]"
fi

echo ""
echo "=== 3. Validate and Sanitize Input ==="
sanitize_filename() {
    local input="$1"
    local clean="${input//[^a-zA-Z0-9._-]/}"
    echo "$clean"
}

sanitize_path() {
    local input="$1"
    local clean="${input//\.\./}"
    clean="${clean//[^a-zA-Z0-9./_-]/}"
    echo "$clean"
}

echo "Filename sanitization:"
for input in "normal.txt" "file;rm -rf /" "../../../etc/passwd" "hello world.txt"; do
    echo "  '$input' -> '$(sanitize_filename "$input")'"
done

echo ""
echo "Path sanitization:"
for input in "/var/log/app.log" "../../etc/shadow" "/tmp/file;echo hacked"; do
    echo "  '$input' -> '$(sanitize_path "$input")'"
done

echo ""
echo "=== 4. Strict Mode ==="
echo "Recommended for production scripts:"
echo '  set -euo pipefail'
echo '  IFS=$'"'"'\n\t'"'"
(
    set -euo pipefail
    echo "  Running in strict mode..."
    true
    echo "  Strict mode works!"
)

echo ""
echo "=== 5. Never Use eval with Untrusted Input ==="
echo "DANGEROUS: eval \"\$user_input\""
echo "SAFE: Use parameter expansion, case statements, or whitelisting"

safe_dispatch() {
    local action="$1"
    case "$action" in
        list)   echo "  Listing items..." ;;
        count)  echo "  Counting items..." ;;
        help)   echo "  Showing help..." ;;
        *)      echo "  Unknown action: $action" >&2; return 1 ;;
    esac
}

for action in "list" "count" "; rm -rf /"; do
    safe_dispatch "$action"
done

echo ""
echo "=== 6. Safe Temporary Files ==="
tmpfile=$(mktemp)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpfile" "$tmpdir"' EXIT

echo "Temp file: $tmpfile (permissions: $(stat -c '%a' "$tmpfile" 2>/dev/null || stat -f '%Lp' "$tmpfile" 2>/dev/null))"
echo "Temp dir:  $tmpdir"

echo ""
echo "=== 7. Restrict PATH ==="
echo "Current PATH entries:"
IFS=: read -ra path_entries <<< "$PATH"
for entry in "${path_entries[@]:0:5}"; do
    echo "  $entry"
done
echo "  ... (${#path_entries[@]} total)"

echo "For secure scripts, set PATH explicitly:"
echo '  export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"'

echo ""
echo "=== 8. Check Commands Exist ==="
require_cmd() {
    if ! command -v "$1" &>/dev/null; then
        echo "  MISSING: $1" >&2
        return 1
    fi
    echo "  FOUND: $1 ($(command -v "$1"))"
    return 0
}

for cmd in bash ls grep nonexistent_cmd; do
    require_cmd "$cmd"
done

echo ""
echo "=== 9. Use -- to End Option Parsing ==="
echo "Prevents filenames starting with - from being treated as options:"
echo '  grep -- "-pattern" file'
echo '  rm -- "-dangerous-filename"'

echo ""
echo "=== 10. Secure File Permissions ==="
original_umask=$(umask)
umask 077
secret_file=$(mktemp)
echo "sensitive data" > "$secret_file"
echo "File created with umask 077:"
ls -la "$secret_file"
umask "$original_umask"

echo ""
echo "=== 11. Avoid Race Conditions ==="
echo "Use atomic operations where possible:"
echo "  - mkdir for locking (atomic)"
echo "  - mktemp for safe temp files"
echo "  - mv for atomic file replacement"
echo "  - flock for file locking"

echo ""
echo "=== 12. Integer Validation ==="
is_integer() {
    local val="$1"
    if [[ "$val" =~ ^-?[0-9]+$ ]]; then
        echo "  '$val' is a valid integer"
        return 0
    else
        echo "  '$val' is NOT a valid integer"
        return 1
    fi
}

for val in "42" "-7" "3.14" "abc" "12abc" ""; do
    is_integer "$val"
done

echo ""
echo "=== Security Checklist ==="
cat << 'EOF'
  [ ] Quote all variable expansions: "$var"
  [ ] Use [[ ]] for conditionals
  [ ] Validate all external input
  [ ] Use set -euo pipefail
  [ ] Never eval untrusted data
  [ ] Use mktemp for temp files
  [ ] Restrict PATH in sensitive scripts
  [ ] Verify required commands exist
  [ ] Use -- to separate options from arguments
  [ ] Set appropriate file permissions (umask)
  [ ] Avoid race conditions (atomic operations)
  [ ] Use ShellCheck for static analysis
EOF
