#!/bin/bash
# Quoting and Escaping — double quotes, single quotes, backslash, $'...'

name="World"

echo "=== Double Quotes (expansion happens) ==="
echo "Hello, $name"
echo "Date: $(date +%Y)"
echo "Home: $HOME"

echo ""
echo "=== Single Quotes (everything literal) ==="
echo 'Hello, $name'
echo 'Date: $(date +%Y)'
echo 'Home: $HOME'

echo ""
echo "=== Backslash Escaping ==="
echo "The cost is \$100"
echo "She said \"hello\""
echo "Backslash: \\"
echo "Tab: \t (no expansion in double quotes)"

echo ""
echo "=== ANSI-C Quoting \$'...' ==="
echo $'Tab:\there'
echo $'Newline:\nSecond line'
echo $'Bell: \a'

echo ""
echo '=== $@ vs $* ==='
set -- "arg one" "arg two" "arg three"

echo 'Iterating "$@" (preserves word boundaries):'
for arg in "$@"; do
    echo "  [$arg]"
done

echo 'Iterating "$*" (joins into single string):'
for arg in "$*"; do
    echo "  [$arg]"
done

echo ""
echo "=== Nested Quoting ==="
message="She said 'hello' and \"goodbye\""
echo "$message"

inner='contains $dollar and `backtick`'
echo "Inner: $inner"
