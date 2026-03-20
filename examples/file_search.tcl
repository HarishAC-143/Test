#!/usr/bin/env tclsh
#
# Recursive File Search Tool
# Search for files by name pattern, content, size, and modification date.

namespace eval filesearch {

    proc find {dir args} {
        array set opts {
            -name    "*"
            -content ""
            -minsize -1
            -maxsize -1
            -newer   0
            -type    "all"
            -maxdepth -1
        }
        array set opts $args

        set results {}
        search_recursive $dir opts results 0
        return $results
    }

    proc search_recursive {dir optsName resultsName depth} {
        upvar 1 $optsName opts $resultsName results

        if {$opts(-maxdepth) >= 0 && $depth > $opts(-maxdepth)} return

        if {[catch {glob -nocomplain -directory $dir -types hidden *} entries]} {
            return
        }
        if {[catch {glob -nocomplain -directory $dir *} visible]} {
            return
        }
        set entries [lsort -unique [concat $entries $visible]]

        foreach entry $entries {
            set tail [file tail $entry]
            if {$tail eq "." || $tail eq ".."} continue

            if {[file isdirectory $entry]} {
                if {$opts(-type) eq "d" || $opts(-type) eq "all"} {
                    if {[string match $opts(-name) $tail]} {
                        if {[matches_criteria $entry opts]} {
                            lappend results $entry
                        }
                    }
                }
                search_recursive $entry opts results [expr {$depth + 1}]
            } elseif {[file isfile $entry]} {
                if {$opts(-type) eq "f" || $opts(-type) eq "all"} {
                    if {[string match $opts(-name) $tail]} {
                        if {[matches_criteria $entry opts]} {
                            lappend results $entry
                        }
                    }
                }
            }
        }
    }

    proc matches_criteria {path optsName} {
        upvar 1 $optsName opts

        if {$opts(-minsize) >= 0 && [file isfile $path]} {
            if {[file size $path] < $opts(-minsize)} {
                return 0
            }
        }

        if {$opts(-maxsize) >= 0 && [file isfile $path]} {
            if {[file size $path] > $opts(-maxsize)} {
                return 0
            }
        }

        if {$opts(-newer) > 0} {
            if {[file mtime $path] < $opts(-newer)} {
                return 0
            }
        }

        if {$opts(-content) ne "" && [file isfile $path]} {
            if {[catch {
                set f [open $path r]
                set data [read $f]
                close $f
                if {![regexp $opts(-content) $data]} {
                    return 0
                }
            }]} {
                return 0
            }
        }

        return 1
    }

    proc format_size {bytes} {
        if {$bytes < 1024} {
            return "${bytes} B"
        } elseif {$bytes < 1048576} {
            return [format "%.1f KB" [expr {$bytes / 1024.0}]]
        } elseif {$bytes < 1073741824} {
            return [format "%.1f MB" [expr {$bytes / 1048576.0}]]
        } else {
            return [format "%.1f GB" [expr {$bytes / 1073741824.0}]]
        }
    }

    proc print_results {results {verbose 0}} {
        set total_size 0
        set count 0

        foreach path $results {
            incr count
            if {$verbose && [file isfile $path]} {
                set size [file size $path]
                set mtime [clock format [file mtime $path] -format "%Y-%m-%d %H:%M"]
                set perms [file attributes $path]
                incr total_size $size
                puts [format "%-50s %10s  %s" $path [format_size $size] $mtime]
            } else {
                puts $path
                if {[file isfile $path]} {
                    incr total_size [file size $path]
                }
            }
        }

        puts "\n--- Found $count items ([format_size $total_size]) ---"
    }

    proc usage {} {
        puts {Usage: tclsh file_search.tcl <directory> [options]

Options:
  -name <pattern>     Glob pattern for file names (default: *)
  -content <regex>    Search file contents with regex
  -minsize <bytes>    Minimum file size
  -maxsize <bytes>    Maximum file size
  -newer <date>       Modified after date (YYYY-MM-DD)
  -type <f|d|all>     File type: f=files, d=dirs, all=both
  -maxdepth <n>       Maximum directory depth
  -verbose            Show size and date details

Examples:
  tclsh file_search.tcl . -name "*.tcl"
  tclsh file_search.tcl /home -name "*.log" -maxsize 1048576
  tclsh file_search.tcl . -content "TODO|FIXME" -name "*.tcl"
  tclsh file_search.tcl . -type d -name "test*"
        }
    }

    proc main {args} {
        if {[llength $args] < 1} {
            usage
            exit 1
        }

        set dir [lindex $args 0]
        if {![file isdirectory $dir]} {
            puts stderr "Error: '$dir' is not a directory"
            exit 1
        }

        set verbose 0
        set find_args {}
        set i 1
        while {$i < [llength $args]} {
            set arg [lindex $args $i]
            switch -- $arg {
                -verbose {
                    set verbose 1
                }
                -newer {
                    incr i
                    set date [lindex $args $i]
                    lappend find_args -newer [clock scan $date -format "%Y-%m-%d"]
                }
                default {
                    lappend find_args $arg
                    if {$arg in {-name -content -minsize -maxsize -type -maxdepth}} {
                        incr i
                        lappend find_args [lindex $args $i]
                    }
                }
            }
            incr i
        }

        set results [find $dir {*}$find_args]
        print_results $results $verbose
    }
}

if {[info script] eq $argv0} {
    filesearch::main {*}$argv
}
