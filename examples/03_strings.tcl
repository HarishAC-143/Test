#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 03: String Operations
# =============================================================================

set str "Hello, Tcl World!"

puts "=== Basic String Info ==="
puts "String: '$str'"
puts "Length: [string length $str]"

puts "\n=== Indexing ==="
puts "First character: [string index $str 0]"
puts "Fifth character: [string index $str 4]"
puts "Last character: [string index $str end]"
puts "Second to last: [string index $str end-1]"

puts "\n=== Substring (range) ==="
puts "Range 0-4: [string range $str 0 4]"
puts "Range 7-9: [string range $str 7 9]"
puts "Range 7-end: [string range $str 7 end]"

puts "\n=== Case Conversion ==="
puts "Uppercase: [string toupper $str]"
puts "Lowercase: [string tolower $str]"
puts "Titlecase: [string totitle "hello world"]"

puts "\n=== Searching ==="
puts "First 'l': [string first "l" $str]"
puts "Last 'l': [string last "l" $str]"
puts "Find 'Tcl': [string first "Tcl" $str]"
puts "Find 'Python': [string first "Python" $str]"

puts "\n=== Comparison ==="
puts "equal 'abc' 'abc': [string equal "abc" "abc"]"
puts "equal 'abc' 'ABC': [string equal "abc" "ABC"]"
puts "equal -nocase 'abc' 'ABC': [string equal -nocase "abc" "ABC"]"
puts "compare 'abc' 'def': [string compare "abc" "def"]"
puts "compare 'def' 'abc': [string compare "def" "abc"]"
puts "compare 'abc' 'abc': [string compare "abc" "abc"]"

puts "\n=== Pattern Matching (glob) ==="
puts "match 'Hello*' '$str': [string match "Hello*" $str]"
puts "match '*World*' '$str': [string match "*World*" $str]"
puts "match '*Python*' '$str': [string match "*Python*" $str]"
puts "match '?ello*' '$str': [string match "?ello*" $str]"

puts "\n=== Trimming ==="
puts "trim '  hello  ': '[string trim "  hello  "]'"
puts "trimleft '  hello  ': '[string trimleft "  hello  "]'"
puts "trimright '  hello  ': '[string trimright "  hello  "]'"
puts "trim 'xxxhelloxx' 'x': '[string trim "xxxhelloxx" "x"]'"

puts "\n=== Replacing ==="
puts "Replace range 7-9: [string replace $str 7 9 "Beautiful"]"

puts "\n=== Mapping ==="
puts "Map vowels to *: [string map {a * e * i * o * u *} "hello world"]"
puts "HTML escape: [string map {& &amp; < &lt; > &gt; \" &quot;} {He said "x < y & z > w"}]"

puts "\n=== Repeat and Reverse ==="
puts "Repeat 'ab' 5: [string repeat "ab" 5]"
puts "Reverse 'hello': [string reverse "hello"]"
puts "Reverse 'racecar': [string reverse "racecar"]"

puts "\n=== Type Checking ==="
puts "Is '42' integer? [string is integer "42"]"
puts "Is '3.14' double? [string is double "3.14"]"
puts "Is 'hello' alpha? [string is alpha "hello"]"
puts "Is 'hello123' alnum? [string is alnum "hello123"]"
puts "Is '   ' space? [string is space "   "]"
puts "Is 'ABC' upper? [string is upper "ABC"]"
puts "Is 'abc' lower? [string is lower "abc"]"
