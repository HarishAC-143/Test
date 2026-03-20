#!/usr/bin/env tclsh
# =============================================================================
# Practical Example: INI-style Configuration Manager
# =============================================================================
# Reads, writes, and manages INI-format configuration files with sections,
# key-value pairs, comments, and type-aware value access.
# Demonstrates: file I/O, regex, dicts, namespaces, error handling.
# =============================================================================

namespace eval ConfigManager {
    variable configs

    proc new {} {
        return [dict create sections [dict create] metadata [dict create \
            filename "" \
            modified false \
            load_time "" \
        ]]
    }

    proc load {filepath} {
        set cfg [new]

        if {![file exists $filepath]} {
            error "Configuration file not found: $filepath"
        }

        dict set cfg metadata filename $filepath
        dict set cfg metadata load_time [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]

        set fd [open $filepath r]
        set current_section "DEFAULT"
        set line_num 0

        while {[gets $fd line] >= 0} {
            incr line_num
            set trimmed [string trim $line]

            if {$trimmed eq "" || [string index $trimmed 0] eq "#" || [string index $trimmed 0] eq ";"} {
                continue
            }

            if {[regexp {^\[([^\]]+)\]$} $trimmed _ section_name]} {
                set current_section [string trim $section_name]
                if {![dict exists [dict get $cfg sections] $current_section]} {
                    dict set cfg sections $current_section [dict create]
                }
                continue
            }

            if {[regexp {^([^=]+)=(.*)$} $trimmed _ key value]} {
                set key [string trim $key]
                set value [string trim $value]

                if {([string index $value 0] eq "\"" && [string index $value end] eq "\"") ||
                    ([string index $value 0] eq "'" && [string index $value end] eq "'")} {
                    set value [string range $value 1 end-1]
                }

                if {![dict exists [dict get $cfg sections] $current_section]} {
                    dict set cfg sections $current_section [dict create]
                }
                dict set cfg sections $current_section $key $value
                continue
            }

            puts stderr "Warning: Ignoring invalid line $line_num: $trimmed"
        }

        close $fd
        return $cfg
    }

    proc save {cfg filepath} {
        set fd [open $filepath w]

        puts $fd "# Configuration file"
        puts $fd "# Generated: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
        puts $fd ""

        set sections [dict get $cfg sections]

        if {[dict exists $sections DEFAULT]} {
            dict for {key value} [dict get $sections DEFAULT] {
                puts $fd "$key = $value"
            }
            puts $fd ""
        }

        dict for {section_name section_data} $sections {
            if {$section_name eq "DEFAULT"} continue
            puts $fd "\[$section_name\]"
            dict for {key value} $section_data {
                if {[string match "* *" $value]} {
                    puts $fd "$key = \"$value\""
                } else {
                    puts $fd "$key = $value"
                }
            }
            puts $fd ""
        }

        close $fd
        dict set cfg metadata modified false
        return $cfg
    }

    proc get {cfg section key {default ""}} {
        set sections [dict get $cfg sections]
        if {[dict exists $sections $section $key]} {
            return [dict get $sections $section $key]
        }
        if {[dict exists $sections DEFAULT $key]} {
            return [dict get $sections DEFAULT $key]
        }
        return $default
    }

    proc get_int {cfg section key {default 0}} {
        set val [get $cfg $section $key ""]
        if {$val eq "" || ![string is integer -strict $val]} {
            return $default
        }
        return $val
    }

    proc get_float {cfg section key {default 0.0}} {
        set val [get $cfg $section $key ""]
        if {$val eq "" || ![string is double -strict $val]} {
            return $default
        }
        return $val
    }

    proc get_bool {cfg section key {default false}} {
        set val [string tolower [get $cfg $section $key ""]]
        if {$val in {1 true yes on}} { return true }
        if {$val in {0 false no off}} { return false }
        return $default
    }

    proc get_list {cfg section key {separator ","}} {
        set val [get $cfg $section $key ""]
        if {$val eq ""} { return {} }
        set result {}
        foreach item [split $val $separator] {
            lappend result [string trim $item]
        }
        return $result
    }

    proc set_val {cfg section key value} {
        if {![dict exists [dict get $cfg sections] $section]} {
            dict set cfg sections $section [dict create]
        }
        dict set cfg sections $section $key $value
        dict set cfg metadata modified true
        return $cfg
    }

    proc remove_key {cfg section key} {
        if {[dict exists [dict get $cfg sections] $section $key]} {
            set section_data [dict get $cfg sections $section]
            dict unset section_data $key
            dict set cfg sections $section $section_data
            dict set cfg metadata modified true
        }
        return $cfg
    }

    proc remove_section {cfg section} {
        if {[dict exists [dict get $cfg sections] $section]} {
            set sections [dict get $cfg sections]
            dict unset sections $section
            dict set cfg sections $sections
            dict set cfg metadata modified true
        }
        return $cfg
    }

    proc sections {cfg} {
        return [dict keys [dict get $cfg sections]]
    }

    proc keys {cfg section} {
        if {[dict exists [dict get $cfg sections] $section]} {
            return [dict keys [dict get $cfg sections $section]]
        }
        return {}
    }

    proc has_section {cfg section} {
        return [dict exists [dict get $cfg sections] $section]
    }

    proc has_key {cfg section key} {
        return [dict exists [dict get $cfg sections] $section $key]
    }

    proc merge {base override} {
        set result $base
        dict for {section section_data} [dict get $override sections] {
            dict for {key value} $section_data {
                set result [set_val $result $section $key $value]
            }
        }
        return $result
    }

    proc dump {cfg} {
        set output ""
        append output "Configuration Dump:\n"
        append output [string repeat "-" 40]
        append output "\n"

        dict for {section section_data} [dict get $cfg sections] {
            append output "\[$section\]\n"
            dict for {key value} $section_data {
                append output [format "  %-20s = %s\n" $key $value]
            }
            append output "\n"
        }
        return $output
    }
}

# --- Demo ---

set sample_config {# Application Configuration
# Last updated: 2026-03-20

[DEFAULT]
version = 1.0
environment = development

[server]
host = 0.0.0.0
port = 8080
workers = 4
debug = true
allowed_origins = localhost, example.com, api.example.com

[database]
host = localhost
port = 5432
name = myapp_dev
user = app_user
password = secret123
pool_size = 10
timeout = 30.5

[logging]
level = INFO
file = /var/log/myapp/app.log
max_size = 10485760
rotate = true
format = "%(timestamp)s [%(level)s] %(message)s"

[cache]
enabled = true
backend = redis
host = localhost
port = 6379
ttl = 3600
prefix = myapp
}

set tmpfile "/tmp/tcl_config_demo.ini"
set fd [open $tmpfile w]
puts -nonewline $fd $sample_config
close $fd

puts "=== Loading Configuration ==="
set cfg [ConfigManager::load $tmpfile]

puts "Sections: [ConfigManager::sections $cfg]"

puts "\n=== Reading Values ==="
puts "Server host: [ConfigManager::get $cfg server host]"
puts "Server port: [ConfigManager::get_int $cfg server port]"
puts "Debug mode: [ConfigManager::get_bool $cfg server debug]"
puts "DB timeout: [ConfigManager::get_float $cfg database timeout]"
puts "Allowed origins: [ConfigManager::get_list $cfg server allowed_origins]"
puts "Default version: [ConfigManager::get $cfg server version]"
puts "Missing key: '[ConfigManager::get $cfg server missing "fallback_value"]'"

puts "\n=== Modifying Configuration ==="
set cfg [ConfigManager::set_val $cfg server port "9090"]
set cfg [ConfigManager::set_val $cfg server ssl "true"]
set cfg [ConfigManager::set_val $cfg newSection key1 "value1"]
set cfg [ConfigManager::set_val $cfg newSection key2 "value2"]

puts "Updated port: [ConfigManager::get $cfg server port]"
puts "New SSL setting: [ConfigManager::get $cfg server ssl]"
puts "Has 'newSection': [ConfigManager::has_section $cfg newSection]"

puts "\n=== Removing Keys/Sections ==="
set cfg [ConfigManager::remove_key $cfg server ssl]
puts "Has 'server.ssl' after remove: [ConfigManager::has_key $cfg server ssl]"

puts "\n=== Saving Configuration ==="
set outfile "/tmp/tcl_config_output.ini"
set cfg [ConfigManager::save $cfg $outfile]
puts "Saved to: $outfile"

puts "\n=== Configuration Dump ==="
puts [ConfigManager::dump $cfg]

puts "=== Merging Configurations ==="
set prod_overrides [ConfigManager::new]
set prod_overrides [ConfigManager::set_val $prod_overrides DEFAULT environment "production"]
set prod_overrides [ConfigManager::set_val $prod_overrides server debug "false"]
set prod_overrides [ConfigManager::set_val $prod_overrides server workers "16"]
set prod_overrides [ConfigManager::set_val $prod_overrides database name "myapp_prod"]
set prod_overrides [ConfigManager::set_val $prod_overrides database pool_size "50"]

set prod_cfg [ConfigManager::merge $cfg $prod_overrides]
puts "Production config:"
puts "  Environment: [ConfigManager::get $prod_cfg DEFAULT environment]"
puts "  Debug: [ConfigManager::get_bool $prod_cfg server debug]"
puts "  Workers: [ConfigManager::get_int $prod_cfg server workers]"
puts "  DB Name: [ConfigManager::get $prod_cfg database name]"
puts "  Pool Size: [ConfigManager::get_int $prod_cfg database pool_size]"

file delete $tmpfile $outfile
