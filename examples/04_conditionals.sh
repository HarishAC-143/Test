#!/bin/bash
# Conditional statements: if/elif/else, case, and ternary patterns

echo "=== if / elif / else ==="
number=42

if (( number > 0 )); then
    echo "$number is positive"
elif (( number < 0 )); then
    echo "$number is negative"
else
    echo "$number is zero"
fi

echo ""
echo "=== Nested if — Age Classifier ==="
age=25

if (( age >= 0 )); then
    if (( age < 13 )); then
        category="Child"
    elif (( age < 20 )); then
        category="Teenager"
    elif (( age < 65 )); then
        category="Adult"
    else
        category="Senior"
    fi
    echo "Age $age → $category"
else
    echo "Invalid age"
fi

echo ""
echo "=== case Statement — File Type Detector ==="
for filename in "photo.jpg" "report.pdf" "script.sh" "data.csv" "archive.tar.gz" "readme.md"; do
    case "$filename" in
        *.tar.gz | *.tgz)   filetype="Compressed archive" ;;
        *.jpg | *.png | *.gif) filetype="Image file" ;;
        *.pdf)               filetype="PDF document" ;;
        *.sh)                filetype="Shell script" ;;
        *.csv)               filetype="CSV data file" ;;
        *.md)                filetype="Markdown document" ;;
        *)                   filetype="Unknown type" ;;
    esac
    printf "  %-20s → %s\n" "$filename" "$filetype"
done

echo ""
echo "=== Ternary-style with && and || ==="
score=85
[[ $score -ge 60 ]] && result="PASS" || result="FAIL"
echo "Score $score → $result"

echo ""
echo "=== case with Regex-like Patterns ==="
input="user@example.com"
case "$input" in
    *@*.*)  echo "'$input' looks like an email" ;;
    http*) echo "'$input' looks like a URL" ;;
    /*)    echo "'$input' looks like a path" ;;
    *)     echo "'$input' type unknown" ;;
esac
