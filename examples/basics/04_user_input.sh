#!/bin/bash
# User Input — read command with various options

echo "=== Basic Input ==="
read -p "Enter your name: " username
echo "Hello, $username!"

echo ""
echo "=== Silent Input ==="
read -sp "Enter a secret password: " password
echo
echo "Password length: ${#password} characters"

echo ""
echo "=== Input with Default Value ==="
read -p "Enter your shell [/bin/bash]: " shell
shell="${shell:-/bin/bash}"
echo "Shell set to: $shell"

echo ""
echo "=== Multiple Values ==="
read -p "Enter first and last name: " first last
echo "First: $first"
echo "Last: $last"

echo ""
echo "=== Timeout Input ==="
if read -t 5 -p "Quick! Enter something (5 sec): " quick_answer; then
    echo "You entered: $quick_answer"
else
    echo
    echo "Time's up!"
fi

echo ""
echo "=== Reading Into an Array ==="
echo "Enter three favorite colors (space-separated):"
read -a colors
echo "Color 1: ${colors[0]:-none}"
echo "Color 2: ${colors[1]:-none}"
echo "Color 3: ${colors[2]:-none}"

echo ""
echo "=== Character-Limited Input ==="
read -n 1 -p "Press any key to continue... " key
echo
echo "You pressed: '$key'"

echo ""
echo "=== Menu Selection ==="
PS3="Choose an option: "
select option in "Option A" "Option B" "Option C" "Quit"; do
    case "$option" in
        "Option A") echo "You chose A" ;;
        "Option B") echo "You chose B" ;;
        "Option C") echo "You chose C" ;;
        "Quit") echo "Goodbye!"; break ;;
        *) echo "Invalid choice" ;;
    esac
done
