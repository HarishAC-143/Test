#!/usr/bin/env tclsh
#
# Lightweight JSON Parser and Generator
# Converts JSON strings to Tcl dicts/lists and back.

namespace eval json {

    proc parse {jsonText} {
        set idx 0
        set result [parse_value $jsonText idx]
        skip_whitespace $jsonText idx
        if {$idx < [string length $jsonText]} {
            error "Unexpected content after JSON value at position $idx"
        }
        return $result
    }

    proc parse_value {json idxVar} {
        upvar 1 $idxVar idx
        skip_whitespace $json idx

        if {$idx >= [string length $json]} {
            error "Unexpected end of JSON"
        }

        set char [string index $json $idx]
        switch $char {
            "\{" { return [parse_object $json idx] }
            "\[" { return [parse_array $json idx] }
            "\"" { return [parse_string $json idx] }
            "t" - "f" { return [parse_boolean $json idx] }
            "n" { return [parse_null $json idx] }
            default {
                if {$char eq "-" || [string is digit $char]} {
                    return [parse_number $json idx]
                }
                error "Unexpected character '$char' at position $idx"
            }
        }
    }

    proc parse_object {json idxVar} {
        upvar 1 $idxVar idx
        incr idx
        skip_whitespace $json idx

        set result [dict create]

        if {[string index $json $idx] eq "\}"} {
            incr idx
            return $result
        }

        while {1} {
            skip_whitespace $json idx
            if {[string index $json $idx] ne "\""} {
                error "Expected string key at position $idx"
            }
            set key [parse_string $json idx]

            skip_whitespace $json idx
            if {[string index $json $idx] ne ":"} {
                error "Expected ':' at position $idx"
            }
            incr idx

            set value [parse_value $json idx]
            dict set result $key $value

            skip_whitespace $json idx
            set char [string index $json $idx]
            if {$char eq "\}"} {
                incr idx
                return $result
            } elseif {$char eq ","} {
                incr idx
            } else {
                error "Expected ',' or '\}' at position $idx"
            }
        }
    }

    proc parse_array {json idxVar} {
        upvar 1 $idxVar idx
        incr idx
        skip_whitespace $json idx

        set result {}

        if {[string index $json $idx] eq "\]"} {
            incr idx
            return $result
        }

        while {1} {
            lappend result [parse_value $json idx]

            skip_whitespace $json idx
            set char [string index $json $idx]
            if {$char eq "\]"} {
                incr idx
                return $result
            } elseif {$char eq ","} {
                incr idx
            } else {
                error "Expected ',' or '\]' at position $idx"
            }
        }
    }

    proc parse_string {json idxVar} {
        upvar 1 $idxVar idx
        incr idx
        set result ""

        while {$idx < [string length $json]} {
            set char [string index $json $idx]
            if {$char eq "\""} {
                incr idx
                return $result
            } elseif {$char eq "\\"} {
                incr idx
                set escape [string index $json $idx]
                switch $escape {
                    "\"" { append result "\"" }
                    "\\" { append result "\\" }
                    "/" { append result "/" }
                    "b" { append result "\b" }
                    "f" { append result "\f" }
                    "n" { append result "\n" }
                    "r" { append result "\r" }
                    "t" { append result "\t" }
                    "u" {
                        set hex [string range $json [expr {$idx+1}] [expr {$idx+4}]]
                        append result [format %c 0x$hex]
                        incr idx 4
                    }
                    default {
                        error "Invalid escape sequence '\\$escape' at position $idx"
                    }
                }
            } else {
                append result $char
            }
            incr idx
        }
        error "Unterminated string"
    }

    proc parse_number {json idxVar} {
        upvar 1 $idxVar idx
        set start $idx

        if {[string index $json $idx] eq "-"} { incr idx }

        while {$idx < [string length $json] && [string is digit [string index $json $idx]]} {
            incr idx
        }

        if {$idx < [string length $json] && [string index $json $idx] eq "."} {
            incr idx
            while {$idx < [string length $json] && [string is digit [string index $json $idx]]} {
                incr idx
            }
        }

        if {$idx < [string length $json] && [string tolower [string index $json $idx]] eq "e"} {
            incr idx
            if {[string index $json $idx] in {+ -}} { incr idx }
            while {$idx < [string length $json] && [string is digit [string index $json $idx]]} {
                incr idx
            }
        }

        set num_str [string range $json $start $idx-1]
        if {[string first "." $num_str] >= 0 || [string first "e" [string tolower $num_str]] >= 0} {
            return [expr {double($num_str)}]
        }
        return [expr {int($num_str)}]
    }

    proc parse_boolean {json idxVar} {
        upvar 1 $idxVar idx
        if {[string range $json $idx $idx+3] eq "true"} {
            incr idx 4
            return true
        } elseif {[string range $json $idx $idx+4] eq "false"} {
            incr idx 5
            return false
        }
        error "Invalid boolean at position $idx"
    }

    proc parse_null {json idxVar} {
        upvar 1 $idxVar idx
        if {[string range $json $idx $idx+3] eq "null"} {
            incr idx 4
            return null
        }
        error "Invalid null at position $idx"
    }

    proc skip_whitespace {json idxVar} {
        upvar 1 $idxVar idx
        while {$idx < [string length $json] && [string index $json $idx] in {" " "\t" "\n" "\r"}} {
            incr idx
        }
    }

    # --- JSON Generation ---

    proc generate {value {type "auto"}} {
        if {$type eq "auto"} {
            set type [detect_type $value]
        }

        switch $type {
            string  { return [gen_string $value] }
            number  { return $value }
            boolean { return [expr {$value ? "true" : "false"}] }
            null    { return "null" }
            object  { return [gen_object $value] }
            array   { return [gen_array $value] }
            default { return [gen_string $value] }
        }
    }

    proc detect_type {value} {
        if {$value eq "null"} { return "null" }
        if {$value in {true false}} { return "boolean" }
        if {[string is integer -strict $value] || [string is double -strict $value]} {
            return "number"
        }
        if {[catch {dict size $value} size] == 0 && $size > 0 && [llength $value] % 2 == 0} {
            return "object"
        }
        if {[string is list $value] && [llength $value] > 1 && [llength $value] % 2 != 0} {
            return "array"
        }
        return "string"
    }

    proc gen_string {value} {
        set result "\""
        set map {
            "\\" "\\\\"
            "\"" "\\\""
            "\n" "\\n"
            "\r" "\\r"
            "\t" "\\t"
            "\b" "\\b"
            "\f" "\\f"
        }
        append result [string map $map $value]
        append result "\""
        return $result
    }

    proc gen_object {dict_value} {
        set parts {}
        dict for {key value} $dict_value {
            set json_key [gen_string $key]
            set json_val [generate $value]
            lappend parts "$json_key: $json_val"
        }
        return "\{[join $parts ", "]\}"
    }

    proc gen_array {list_value} {
        set parts {}
        foreach item $list_value {
            lappend parts [generate $item]
        }
        return "\[[join $parts ", "]\]"
    }

    proc pretty {jsonText {indent "  "}} {
        set parsed [parse $jsonText]
        return [pretty_format $parsed $indent 0]
    }

    proc pretty_format {value indent level} {
        set type [detect_type $value]
        set pad [string repeat $indent $level]
        set pad_inner [string repeat $indent [expr {$level + 1}]]

        switch $type {
            object {
                if {[dict size $value] == 0} { return "\{\}" }
                set parts {}
                dict for {key val} $value {
                    set json_key [gen_string $key]
                    set json_val [pretty_format $val $indent [expr {$level + 1}]]
                    lappend parts "$pad_inner$json_key: $json_val"
                }
                return "\{\n[join $parts ",\n"]\n$pad\}"
            }
            array {
                if {[llength $value] == 0} { return "\[\]" }
                set parts {}
                foreach item $value {
                    set json_val [pretty_format $item $indent [expr {$level + 1}]]
                    lappend parts "$pad_inner$json_val"
                }
                return "\[\n[join $parts ",\n"]\n$pad\]"
            }
            default {
                return [generate $value $type]
            }
        }
    }
}

proc demo {} {
    puts "=== JSON Parser Demo ===\n"

    set json_text {
        {
            "name": "Alice Johnson",
            "age": 30,
            "active": true,
            "email": null,
            "scores": [95, 87, 92, 88],
            "address": {
                "street": "123 Main St",
                "city": "Springfield",
                "state": "IL"
            },
            "tags": ["developer", "tcl", "open-source"]
        }
    }

    puts "--- Parsing JSON ---"
    set data [json::parse $json_text]
    puts "Name: [dict get $data name]"
    puts "Age: [dict get $data age]"
    puts "Active: [dict get $data active]"
    puts "City: [dict get $data address city]"
    puts "Scores: [dict get $data scores]"
    puts "Tags: [dict get $data tags]"

    puts "\n--- Generating JSON ---"
    set person [dict create \
        name "Bob Smith" \
        age 25 \
        skills [list "Tcl" "Python" "Go"]]

    puts [json::generate $person object]

    puts "\n--- Pretty Printing ---"
    puts [json::pretty $json_text]

    puts "\n--- Round-trip test ---"
    set original {{"key": "value", "num": 42, "arr": [1, 2, 3], "nested": {"a": true}}}
    set parsed [json::parse $original]
    set regenerated [json::generate $parsed object]
    puts "Original:    $original"
    puts "Round-trip:  $regenerated"
}

if {[info script] eq $argv0} {
    demo
}
