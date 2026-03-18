#!/usr/bin/env tclsh
# =============================================================================
# Example 12: Practical - Word Frequency Counter
# A complete utility that analyzes text and produces word frequency reports.
# =============================================================================

puts "=== Word Frequency Counter ===\n"

proc count_words {text} {
    set text [string tolower $text]
    set text [regsub -all {[^a-z0-9\s'-]} $text ""]

    set freq [dict create]
    foreach word [split $text] {
        if {$word eq "" || [string length $word] < 2} continue
        dict incr freq $word
    }
    return $freq
}

proc sort_by_frequency {freq_dict {order "decreasing"}} {
    set pairs [list]
    dict for {word count} $freq_dict {
        lappend pairs [list $word $count]
    }
    return [lsort -index 1 -integer -$order $pairs]
}

proc print_report {sorted_pairs {max_words 0}} {
    set total_words 0
    set unique_words [llength $sorted_pairs]

    foreach pair $sorted_pairs {
        set total_words [expr {$total_words + [lindex $pair 1]}]
    }

    puts "  Total words:  $total_words"
    puts "  Unique words: $unique_words"
    puts ""

    if {$max_words == 0 || $max_words > $unique_words} {
        set max_words $unique_words
    }

    # Find max count for bar chart scaling
    set max_count [lindex [lindex $sorted_pairs 0] 1]
    set bar_width 30

    puts [format "  %-15s %5s  %s" "Word" "Count" "Frequency"]
    puts "  [string repeat - 55]"

    for {set i 0} {$i < $max_words} {incr i} {
        lassign [lindex $sorted_pairs $i] word count
        set bar_len [expr {int(double($count) / $max_count * $bar_width)}]
        if {$bar_len < 1} { set bar_len 1 }
        set bar [string repeat "#" $bar_len]
        set pct [format "%.1f%%" [expr {100.0 * $count / $total_words}]]
        puts [format "  %-15s %5d  %-30s %s" $word $count $bar $pct]
    }
}

# Sample text for analysis
set sample_text {
    The quick brown fox jumps over the lazy dog. The dog barked at the fox,
    but the fox was too quick. The lazy dog went back to sleep. The quick
    brown fox ran through the field and jumped over the fence. The dog
    watched the fox from the porch. The fox was clever and the dog was lazy.
    Every day the fox would visit and every day the dog would bark. The fox
    and the dog eventually became friends. The quick fox taught the lazy dog
    to run, and the lazy dog taught the quick fox to rest.
}

set freq [count_words $sample_text]
set sorted [sort_by_frequency $freq]
print_report $sorted 15

# --- Character frequency ---
puts "\n\n--- Character Frequency ---"

proc char_frequency {text} {
    set text [string tolower $text]
    set freq [dict create]
    foreach char [split $text ""] {
        if {[string is alpha $char]} {
            dict incr freq $char
        }
    }
    return $freq
}

set char_freq [char_frequency $sample_text]
set sorted_chars [sort_by_frequency $char_freq]
set max_char_count [lindex [lindex $sorted_chars 0] 1]

puts [format "  %-5s %5s  %s" "Char" "Count" ""]
puts "  [string repeat - 40]"
foreach pair $sorted_chars {
    lassign $pair char count
    set bar_len [expr {int(double($count) / $max_char_count * 25)}]
    if {$bar_len < 1} { set bar_len 1 }
    puts [format "  %-5s %5d  %s" $char $count [string repeat "|" $bar_len]]
}

# --- Sentence statistics ---
puts "\n\n--- Sentence Statistics ---"

proc analyze_sentences {text} {
    set sentences [split $text ".!?"]
    set stats [list]

    foreach sentence $sentences {
        set sentence [string trim $sentence]
        if {$sentence eq ""} continue
        set words [split $sentence]
        set word_count 0
        foreach w $words {
            if {[string trim $w] ne ""} { incr word_count }
        }
        if {$word_count > 0} {
            lappend stats [list $sentence $word_count]
        }
    }
    return $stats
}

set sentence_stats [analyze_sentences $sample_text]
set total_sentence_words 0
set min_words 999
set max_words 0

foreach stat $sentence_stats {
    lassign $stat _ wc
    set total_sentence_words [expr {$total_sentence_words + $wc}]
    if {$wc < $min_words} { set min_words $wc }
    if {$wc > $max_words} { set max_words $wc }
}

set avg_words [expr {double($total_sentence_words) / [llength $sentence_stats]}]

puts "  Sentence count: [llength $sentence_stats]"
puts [format "  Avg words/sentence: %.1f" $avg_words]
puts "  Shortest sentence: $min_words words"
puts "  Longest sentence: $max_words words"

puts "\nDone."
