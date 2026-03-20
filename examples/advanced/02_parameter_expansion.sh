#!/bin/bash
# Advanced Parameter Expansion — defaults, indirection, patterns, case

echo "=== Default Values ==="
unset myvar
echo "\${myvar:-default}:  ${myvar:-default}"
echo "myvar is still:     '${myvar}'"

echo "\${myvar:=assigned}: ${myvar:=assigned}"
echo "myvar is now:       '${myvar}'"

echo "\${myvar:+replaced}: ${myvar:+replaced}"

unset myvar

echo ""
echo "=== Indirect Expansion ==="
greeting="Hello, World!"
var_name="greeting"
echo "var_name='$var_name'"
echo "\${!var_name} = '${!var_name}'"

echo ""
echo "=== Substring Expansion ==="
str="abcdefghij"
echo "str='$str'"
echo "\${str:3}     = '${str:3}'"
echo "\${str:3:4}   = '${str:3:4}'"
echo "\${str: -3}   = '${str: -3}'"
echo "\${str: -3:2} = '${str: -3:2}'"

echo ""
echo "=== Pattern Removal ==="
path="/usr/local/bin/my_script.sh"
echo "path='$path'"
echo ""
echo "# — shortest prefix match:"
echo "  \${path#*/}  = '${path#*/}'"
echo "## — longest prefix match:"
echo "  \${path##*/} = '${path##*/}'"
echo "% — shortest suffix match:"
echo "  \${path%/*}  = '${path%/*}'"
echo "%% — longest suffix match:"
echo "  \${path%%/*} = '${path%%/*}'"

echo ""
echo "=== Pattern Substitution ==="
str="foo-bar-baz-foo-qux"
echo "str='$str'"
echo "Replace first 'foo': '${str/foo/FOO}'"
echo "Replace all 'foo':   '${str//foo/FOO}'"
echo "Replace at start:    '${str/#foo/FOO}'"
echo "Replace at end:      '${str/%qux/QUX}'"
echo "Delete all '-':      '${str//-/}'"

echo ""
echo "=== Case Modification ==="
lower="hello world"
upper="HELLO WORLD"
mixed="hElLo WoRlD"
echo "Uppercase first: '${lower^}'"
echo "Uppercase all:   '${lower^^}'"
echo "Lowercase first: '${upper,}'"
echo "Lowercase all:   '${upper,,}'"
echo "Mixed to upper:  '${mixed^^}'"
echo "Mixed to lower:  '${mixed,,}'"

echo ""
echo "=== Array Transformations ==="
fruits=(apple banana cherry date)
echo "Original: ${fruits[*]}"
echo "Uppercase first: ${fruits[*]^}"
echo "Uppercase all:   ${fruits[*]^^}"
echo "Replace 'a' with 'A': ${fruits[*]/a/A}"

echo ""
echo "=== Practical: File Extension Operations ==="
files=("report.pdf" "data.csv" "image.png" "backup.tar.gz" "README" "script.sh")
for f in "${files[@]}"; do
    name="${f%.*}"
    ext="${f##*.}"
    [[ "$name" == "$ext" ]] && ext="(none)"
    printf "  %-20s name=%-15s ext=%s\n" "$f" "$name" "$ext"
done

echo ""
echo "=== Practical: URL Parsing ==="
url="https://user:pass@www.example.com:8080/path/to/page?query=value#fragment"
echo "Full URL: $url"
echo "Protocol:  ${url%%://*}"
after_proto="${url#*://}"
user_pass="${after_proto%%@*}"
echo "User:      ${user_pass%%:*}"
echo "Password:  ${user_pass#*:}"
host_rest="${after_proto#*@}"
host_port="${host_rest%%/*}"
echo "Host:      ${host_port%%:*}"
echo "Port:      ${host_port#*:}"
path_query="${host_rest#*/}"
echo "Path:      /${path_query%%\?*}"
query_frag="${path_query#*\?}"
echo "Query:     ${query_frag%%#*}"
echo "Fragment:  ${path_query##*#}"

echo ""
echo "=== Practical: Config Line Parsing ==="
config_lines=(
    "database_host = 192.168.1.100"
    "database_port = 5432"
    "app_name = My Application"
    "debug_mode = true"
)
for line in "${config_lines[@]}"; do
    key="${line%% =*}"
    value="${line##*= }"
    printf "  Key: %-20s Value: %s\n" "'$key'" "'$value'"
done
