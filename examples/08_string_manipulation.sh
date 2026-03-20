#!/bin/bash
# String operations: length, substring, search/replace, splitting

echo "=== String Length ==="
str="Hello, Beautiful World!"
echo "String: '$str'"
echo "Length: ${#str}"

echo ""
echo "=== Substring Extraction ==="
echo "Chars 0-4:  '${str:0:5}'"
echo "Chars 7-15: '${str:7:9}'"
echo "From 18:    '${str:18}'"

echo ""
echo "=== Case Conversion (BASH 4+) ==="
echo "Uppercase: '${str^^}'"
echo "Lowercase: '${str,,}'"
echo "First upper: '${str^}'"

echo ""
echo "=== Pattern Removal ==="
path="/home/user/documents/report.tar.gz"
echo "Path: $path"
echo "  Remove front (shortest #):  ${path#*/}"
echo "  Remove front (longest ##):  ${path##*/}"
echo "  Remove back  (shortest %):  ${path%.*}"
echo "  Remove back  (longest %%):  ${path%%.*}"
echo ""
echo "  Basename (##*/): ${path##*/}"
echo "  Dirname  (%/*):  ${path%/*}"
echo "  Extension:       ${path##*.}"
echo "  Without ext:     ${path%.*}"

echo ""
echo "=== Substitution ==="
msg="The cat sat on the mat with another cat"
echo "Original:        '$msg'"
echo "Replace first:   '${msg/cat/dog}'"
echo "Replace all:     '${msg//cat/dog}'"
echo "Replace at start:'${msg/#The/A}'"
echo "Replace at end:  '${msg/%cat/kitten}'"

echo ""
echo "=== String Splitting ==="
csv="Alice,30,Engineer,New York"
echo "CSV line: $csv"
IFS=',' read -ra fields <<< "$csv"
for i in "${!fields[@]}"; do
    echo "  Field $i: ${fields[$i]}"
done

echo ""
echo "=== Regex Matching ==="
email="user@example.com"
if [[ "$email" =~ ^([a-zA-Z0-9._%+-]+)@([a-zA-Z0-9.-]+)\.([a-zA-Z]{2,})$ ]]; then
    echo "Valid email: $email"
    echo "  Username: ${BASH_REMATCH[1]}"
    echo "  Domain:   ${BASH_REMATCH[2]}"
    echo "  TLD:      ${BASH_REMATCH[3]}"
else
    echo "Invalid email format"
fi

echo ""
echo "=== Practical: URL Parser ==="
url="https://www.example.com:8080/api/v2/users?page=1&limit=10"
echo "URL: $url"

protocol="${url%%://*}"
remainder="${url#*://}"
host_port="${remainder%%/*}"
host="${host_port%%:*}"
port="${host_port##*:}"
path_query="/${remainder#*/}"
path="${path_query%%\?*}"
query="${path_query#*\?}"

echo "  Protocol: $protocol"
echo "  Host:     $host"
echo "  Port:     $port"
echo "  Path:     $path"
echo "  Query:    $query"
