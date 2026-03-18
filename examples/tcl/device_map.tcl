# =============================================================================
# device_map.tcl — Device configuration lookup table
# =============================================================================
# Provides a mapping from logical device names to Quartus part numbers
# and associated metadata (family, speed grade, package).
#
# Usage:
#   source device_map.tcl
#   set part_number [get_device_part "cyclone_v_medium"]
#   set family      [get_device_family "cyclone_v_medium"]
# =============================================================================

# ---------------------------------------------------------------------------
# Device database
# Each entry: {part_number family speed_grade package description}
# ---------------------------------------------------------------------------
dict set device_db "cyclone_v_small" {
    part        "5CEBA2F17A7"
    family      "Cyclone V"
    speed       "7"
    package     "FBGA"
    alm_count   9430
    description "Cyclone V E - Small (A2)"
}

dict set device_db "cyclone_v_medium" {
    part        "5CEBA4F23C7"
    family      "Cyclone V"
    speed       "7"
    package     "FBGA"
    alm_count   18480
    description "Cyclone V E - Medium (A4)"
}

dict set device_db "cyclone_v_large" {
    part        "5CEBA9F31C6"
    family      "Cyclone V"
    speed       "6"
    package     "FBGA"
    alm_count   113560
    description "Cyclone V E - Large (A9)"
}

dict set device_db "cyclone10_small" {
    part        "10CL006YE144C8G"
    family      "Cyclone 10 LP"
    speed       "8"
    package     "EQFP"
    alm_count   6272
    description "Cyclone 10 LP - Small (006)"
}

dict set device_db "cyclone10_medium" {
    part        "10CL025YU256I7G"
    family      "Cyclone 10 LP"
    speed       "7"
    package     "UBGA"
    alm_count   25000
    description "Cyclone 10 LP - Medium (025)"
}

dict set device_db "cyclone10_large" {
    part        "10CL120YF780I7G"
    family      "Cyclone 10 LP"
    speed       "7"
    package     "FBGA"
    alm_count   120000
    description "Cyclone 10 LP - Large (120)"
}

dict set device_db "max10_small" {
    part        "10M02SCE144I7G"
    family      "MAX 10"
    speed       "7"
    package     "EQFP"
    alm_count   2304
    description "MAX 10 - Small (02)"
}

dict set device_db "max10_medium" {
    part        "10M16SAE144I7G"
    family      "MAX 10"
    speed       "7"
    package     "EQFP"
    alm_count   16000
    description "MAX 10 - Medium (16)"
}

dict set device_db "max10_large" {
    part        "10M50DAF484C6GES"
    family      "MAX 10"
    speed       "6"
    package     "FBGA"
    alm_count   50000
    description "MAX 10 - Large (50)"
}

dict set device_db "arria10_small" {
    part        "10AX016E3F27I2LG"
    family      "Arria 10"
    speed       "2"
    package     "FBGA"
    alm_count   160000
    description "Arria 10 GX - Small (016)"
}

dict set device_db "stratix10_small" {
    part        "1SG040HN2F43I2VG"
    family      "Stratix 10"
    speed       "2"
    package     "FBGA"
    alm_count   400000
    description "Stratix 10 GX - Small (040)"
}

# ---------------------------------------------------------------------------
# Accessor functions
# ---------------------------------------------------------------------------

proc get_device_part {device_name} {
    global device_db
    if {[dict exists $device_db $device_name]} {
        return [dict get $device_db $device_name part]
    }
    puts "ERROR: Unknown device '$device_name'"
    puts "Available devices: [dict keys $device_db]"
    return ""
}

proc get_device_family {device_name} {
    global device_db
    if {[dict exists $device_db $device_name]} {
        return [dict get $device_db $device_name family]
    }
    return ""
}

proc get_device_info {device_name} {
    global device_db
    if {[dict exists $device_db $device_name]} {
        return [dict get $device_db $device_name]
    }
    return ""
}

proc list_all_devices {} {
    global device_db
    puts "Available devices:"
    puts [format "  %-25s %-20s %-15s %s" "Name" "Part" "Family" "Description"]
    puts "  -------------------------------------------------------------------------"
    dict for {name info} $device_db {
        puts [format "  %-25s %-20s %-15s %s" \
            $name \
            [dict get $info part] \
            [dict get $info family] \
            [dict get $info description]]
    }
}

proc get_devices_by_family {family_name} {
    global device_db
    set matching [list]
    dict for {name info} $device_db {
        if {[dict get $info family] eq $family_name} {
            lappend matching $name
        }
    }
    return $matching
}
