#!/bin/bash
# String Manipulation — length, substring, search, replace, case

str="Hello, Beautiful World!"

echo "=== String Length ==="
echo "String: '$str'"
echo "Length: ${#str}"

echo ""
echo "=== Substrings ==="
echo "From index 7, length 9: '${str:7:9}'"
echo "From index 7 to end:    '${str:7}'"
echo "Last 6 chars:           '${str: -6}'"

echo ""
echo "=== Search and Replace ==="
echo "Original:      '$str'"
echo "Replace first 'o':  '${str/o/0}'"
echo "Replace all 'o':    '${str//o/0}'"
echo "Delete 'Beautiful ': '${str/Beautiful /}'"

echo ""
echo "=== Prefix Removal ==="
filepath="/home/user/documents/report.tar.gz"
echo "Path:             '$filepath'"
echo "Remove shortest #*/: '${filepath#*/}'"
echo "Remove longest ##*/: '${filepath##*/}'"

echo ""
echo "=== Suffix Removal ==="
echo "Remove shortest %.*: '${filepath%.*}'"
echo "Remove longest %%.*: '${filepath%%.*}'"

echo ""
echo "=== Practical: File Path Parsing ==="
full_path="/var/log/nginx/access.log"
echo "Full path:  $full_path"
echo "Directory:  ${full_path%/*}"
echo "Filename:   ${full_path##*/}"
filename="${full_path##*/}"
echo "Name only:  ${filename%.*}"
echo "Extension:  ${filename##*.}"

echo ""
echo "=== Case Conversion (Bash 4+) ==="
text="hello world"
echo "Original:         '$text'"
echo "First char upper: '${text^}'"
echo "All upper:        '${text^^}'"
upper="HELLO WORLD"
echo "First char lower: '${upper,}'"
echo "All lower:        '${upper,,}'"

echo ""
echo "=== String Concatenation ==="
first="Hello"
second="World"
result="${first}, ${second}!"
echo "$result"
result+=" How are you?"
echo "$result"

echo ""
echo "=== Pattern Matching ==="
filename="backup_2026-03-20.tar.gz"
if [[ "$filename" == *.tar.gz ]]; then
    echo "'$filename' is a gzipped tarball"
fi
if [[ "$filename" == backup_* ]]; then
    echo "'$filename' is a backup file"
fi
if [[ "$filename" != *.zip ]]; then
    echo "'$filename' is not a zip file"
fi

echo ""
echo "=== Practical: String Validation ==="
validate_username() {
    local name="$1"
    if [[ ${#name} -lt 3 ]]; then
        echo "'$name': too short (min 3 chars)"
    elif [[ ${#name} -gt 20 ]]; then
        echo "'$name': too long (max 20 chars)"
    elif [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "'$name': invalid characters"
    else
        echo "'$name': valid username"
    fi
}

validate_username "alice"
validate_username "ab"
validate_username "user-name"
validate_username "valid_user123"

echo ""
echo "=== Practical: CSV Parsing ==="
csv_line="John,Doe,30,Engineer,New York"
IFS=',' read -r first last age job city <<< "$csv_line"
echo "Name: $first $last"
echo "Age: $age"
echo "Job: $job"
echo "City: $city"
