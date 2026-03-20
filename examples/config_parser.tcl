#!/usr/bin/env tclsh
#
# INI-Style Configuration File Parser
# Read, write, and manipulate INI configuration files.

namespace eval ini {

    proc parse {filename} {
        set config [dict create]
        set section ""

        set f [open $filename r]
        try {
            set line_num 0
            while {[gets $f line] >= 0} {
                incr line_num
                set line [string trim $line]

                if {$line eq "" || [string index $line 0] eq "#" || [string index $line 0] eq ";"} {
                    continue
                }

                if {[regexp {^\[([^\]]+)\]$} $line -> sec]} {
                    set section [string trim $sec]
                    if {![dict exists $config $section]} {
                        dict set config $section [dict create]
                    }
                    continue
                }

                if {[regexp {^([^=]+)=(.*)$} $line -> key value]} {
                    set key [string trim $key]
                    set value [string trim $value]

                    set value [strip_quotes $value]

                    if {$section ne ""} {
                        dict set config $section $key $value
                    } else {
                        dict set config "" $key $value
                    }
                    continue
                }

                puts stderr "Warning: Ignoring invalid line $line_num: $line"
            }
        } finally {
            close $f
        }

        return $config
    }

    proc strip_quotes {value} {
        if {([string index $value 0] eq "\"" && [string index $value end] eq "\"") ||
            ([string index $value 0] eq "'" && [string index $value end] eq "'")} {
            return [string range $value 1 end-1]
        }
        return $value
    }

    proc write {filename config} {
        set f [open $filename w]
        try {
            puts $f "# Configuration file"
            puts $f "# Generated: [clock format [clock seconds]]"
            puts $f ""

            if {[dict exists $config ""]} {
                dict for {key value} [dict get $config ""] {
                    puts $f "$key = [quote_if_needed $value]"
                }
                puts $f ""
            }

            dict for {section data} $config {
                if {$section eq ""} continue
                puts $f "\[$section\]"
                dict for {key value} $data {
                    puts $f "$key = [quote_if_needed $value]"
                }
                puts $f ""
            }
        } finally {
            close $f
        }
    }

    proc quote_if_needed {value} {
        if {[regexp {\s} $value] || [string first "#" $value] >= 0 ||
            [string first ";" $value] >= 0} {
            return "\"$value\""
        }
        return $value
    }

    proc get {config section key {default ""}} {
        if {[dict exists $config $section $key]} {
            return [dict get $config $section $key]
        }
        return $default
    }

    proc set_value {configVar section key value} {
        upvar 1 $configVar config
        dict set config $section $key $value
    }

    proc remove_key {configVar section key} {
        upvar 1 $configVar config
        if {[dict exists $config $section $key]} {
            set sdata [dict get $config $section]
            dict unset sdata $key
            dict set config $section $sdata
        }
    }

    proc remove_section {configVar section} {
        upvar 1 $configVar config
        dict unset config $section
    }

    proc sections {config} {
        set result {}
        dict for {sec _} $config {
            if {$sec ne ""} {
                lappend result $sec
            }
        }
        return $result
    }

    proc keys {config section} {
        if {[dict exists $config $section]} {
            return [dict keys [dict get $config $section]]
        }
        return {}
    }

    proc merge {base override} {
        set result $base
        dict for {section data} $override {
            if {[dict exists $result $section]} {
                set sdata [dict get $result $section]
                dict for {key value} $data {
                    dict set sdata $key $value
                }
                dict set result $section $sdata
            } else {
                dict set result $section $data
            }
        }
        return $result
    }

    proc to_string {config} {
        set result ""
        dict for {section data} $config {
            if {$section ne ""} {
                append result "\[$section\]\n"
            }
            dict for {key value} $data {
                append result "$key = $value\n"
            }
            append result "\n"
        }
        return $result
    }
}

proc demo {} {
    puts "=== INI Config Parser Demo ===\n"

    set sample_file "/tmp/demo_config.ini"
    set f [open $sample_file w]
    puts $f {# Application Configuration

[server]
host = 0.0.0.0
port = 8080
workers = 4
debug = false

[database]
driver = postgresql
host = localhost
port = 5432
name = myapp
user = admin
password = "secret password"

[logging]
level = info
file = /var/log/app.log
max_size = 10485760
rotate = true

[cache]
enabled = true
ttl = 3600
backend = redis
redis_url = redis://localhost:6379}
    close $f

    set config [ini::parse $sample_file]

    puts "Sections: [ini::sections $config]\n"

    puts "Server Configuration:"
    foreach key [ini::keys $config "server"] {
        puts "  $key = [ini::get $config server $key]"
    }

    puts "\nDatabase host: [ini::get $config database host]"
    puts "Database port: [ini::get $config database port]"
    puts "Missing key with default: [ini::get $config database timeout 30]"

    ini::set_value config "server" "ssl" "true"
    ini::set_value config "server" "ssl_cert" "/etc/ssl/cert.pem"

    puts "\nUpdated configuration:"
    puts [ini::to_string $config]

    set output_file "/tmp/demo_config_updated.ini"
    ini::write $output_file $config
    puts "Written to: $output_file"

    file delete $sample_file $output_file
}

if {[info script] eq $argv0} {
    demo
}
