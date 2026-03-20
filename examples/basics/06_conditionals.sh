#!/bin/bash
# Conditional Statements — if/elif/else, test operators, case

echo "=== if / elif / else ==="
read -p "Enter a number: " num

if [[ $num -gt 0 ]]; then
    echo "$num is positive"
elif [[ $num -lt 0 ]]; then
    echo "$num is negative"
else
    echo "$num is zero"
fi

echo ""
echo "=== Integer Comparisons ==="
a=10 b=20
[[ $a -eq $b ]] && echo "$a == $b" || echo "$a != $b"
[[ $a -lt $b ]] && echo "$a < $b"  || echo "$a >= $b"
[[ $a -gt $b ]] && echo "$a > $b"  || echo "$a <= $b"

echo ""
echo "=== String Comparisons ==="
str1="hello"
str2="world"
[[ "$str1" == "$str2" ]] && echo "Strings equal" || echo "Strings differ"
[[ -z "" ]]              && echo "Empty string is -z (zero length)"
[[ -n "$str1" ]]         && echo "'$str1' is -n (non-empty)"

echo ""
echo "=== File Tests ==="
for path in /etc/passwd /tmp /nonexistent ~/.bashrc; do
    printf "  %-20s" "$path"
    if [[ ! -e "$path" ]]; then
        echo "does not exist"
    elif [[ -f "$path" ]]; then
        echo "regular file"
    elif [[ -d "$path" ]]; then
        echo "directory"
    elif [[ -L "$path" ]]; then
        echo "symbolic link"
    fi
done

echo ""
echo "=== Pattern Matching with [[ ]] ==="
filename="report_2026.tar.gz"
if [[ "$filename" == *.tar.gz ]]; then
    echo "'$filename' is a gzipped tarball"
fi
if [[ "$filename" == report* ]]; then
    echo "'$filename' starts with 'report'"
fi

echo ""
echo "=== Regex Matching ==="
email="user@example.com"
if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "'$email' looks like a valid email"
else
    echo "'$email' does not look like a valid email"
fi

echo ""
echo "=== Logical Operators ==="
age=25
has_id=true
if [[ $age -ge 18 && "$has_id" == "true" ]]; then
    echo "Entry permitted (age=$age, has_id=$has_id)"
fi

echo ""
echo "=== case Statement ==="
read -p "Enter a fruit (or 'quit'): " fruit
case "$fruit" in
    apple|Apple)
        echo "An apple a day keeps the doctor away."
        ;;
    banana|Banana)
        echo "Bananas are rich in potassium."
        ;;
    orange|Orange)
        echo "Oranges are full of Vitamin C."
        ;;
    quit)
        echo "Goodbye!"
        ;;
    *)
        echo "Unknown fruit: $fruit"
        ;;
esac

echo ""
echo "=== Nested if ==="
file="/etc/passwd"
if [[ -e "$file" ]]; then
    if [[ -r "$file" ]]; then
        lines=$(wc -l < "$file")
        echo "$file has $lines lines"
    else
        echo "$file exists but is not readable"
    fi
else
    echo "$file does not exist"
fi
