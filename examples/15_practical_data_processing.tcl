#!/usr/bin/env tclsh
# =============================================================================
# Example 15: Practical - Data Processing Pipeline
# Demonstrates processing structured data: filtering, aggregation, reporting.
# =============================================================================

puts "=== Data Processing Pipeline ===\n"

# --- Generate sample sales data ---
proc generate_sales_data {} {
    set regions {North South East West}
    set products {Widget Gadget Doohickey Thingamajig Whatchamacallit}
    set months {Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec}

    set data [list]
    set id 1

    expr {srand(42)}

    foreach month $months {
        foreach region $regions {
            set num_products [expr {2 + int(rand() * 3)}]
            set selected [lrange [lsort -command {apply {{a b} {
                expr {int(rand() * 3) - 1}
            }}} $products] 0 [expr {$num_products - 1}]]

            foreach product $selected {
                set qty [expr {10 + int(rand() * 90)}]
                set price [expr {5.0 + rand() * 45.0}]
                set revenue [expr {$qty * $price}]

                lappend data [dict create \
                    id       $id \
                    month    $month \
                    region   $region \
                    product  $product \
                    quantity $qty \
                    price    [format "%.2f" $price] \
                    revenue  [format "%.2f" $revenue] \
                ]
                incr id
            }
        }
    }
    return $data
}

# --- Pipeline functions ---

proc pipeline_filter {data key pattern} {
    set result [list]
    foreach record $data {
        if {[string match $pattern [dict get $record $key]]} {
            lappend result $record
        }
    }
    return $result
}

proc pipeline_group_by {data key} {
    set groups [dict create]
    foreach record $data {
        set group_key [dict get $record $key]
        dict lappend groups $group_key $record
    }
    return $groups
}

proc pipeline_aggregate {data value_key {operation "sum"}} {
    set values [list]
    foreach record $data {
        lappend values [dict get $record $value_key]
    }

    switch $operation {
        sum {
            set total 0.0
            foreach v $values { set total [expr {$total + $v}] }
            return $total
        }
        avg {
            set total 0.0
            foreach v $values { set total [expr {$total + $v}] }
            return [expr {$total / [llength $values]}]
        }
        count {
            return [llength $values]
        }
        min {
            set result [lindex $values 0]
            foreach v [lrange $values 1 end] {
                if {$v < $result} { set result $v }
            }
            return $result
        }
        max {
            set result [lindex $values 0]
            foreach v [lrange $values 1 end] {
                if {$v > $result} { set result $v }
            }
            return $result
        }
    }
}

proc pipeline_sort {data key {order "increasing"} {type "-real"}} {
    return [lsort -command [list apply [list {key type a b} {
        set va [dict get $a $key]
        set vb [dict get $b $key]
        if {$type eq "-real"} {
            return [expr {$va < $vb ? -1 : ($va > $vb ? 1 : 0)}]
        } else {
            return [string compare $va $vb]
        }
    }] $key $type] $data]
}

proc print_separator {{char "="} {len 70}} {
    puts [string repeat $char $len]
}

# === Generate Data ===
set sales_data [generate_sales_data]
puts "Generated [llength $sales_data] sales records.\n"

# === Report 1: Revenue by Region ===
print_separator
puts "REPORT 1: Revenue by Region"
print_separator

set by_region [pipeline_group_by $sales_data region]
set region_stats [list]

dict for {region records} $by_region {
    set total_rev [pipeline_aggregate $records revenue sum]
    set total_qty [pipeline_aggregate $records quantity sum]
    set avg_price [pipeline_aggregate $records price avg]
    set num_sales [pipeline_aggregate $records id count]

    lappend region_stats [dict create \
        region $region \
        revenue $total_rev \
        quantity $total_qty \
        avg_price $avg_price \
        sales $num_sales \
    ]
}

set region_stats [lsort -command {apply {{a b} {
    set ra [dict get $a revenue]
    set rb [dict get $b revenue]
    expr {$rb < $ra ? -1 : ($rb > $ra ? 1 : 0)}
}}} $region_stats]

set grand_total 0.0
puts [format "  %-10s %12s %8s %10s %6s" "Region" "Revenue" "Qty" "Avg Price" "Sales"]
puts "  [string repeat - 52]"
foreach stat $region_stats {
    set rev [dict get $stat revenue]
    set grand_total [expr {$grand_total + $rev}]
    puts [format "  %-10s \$%11.2f %8d \$%9.2f %6d" \
        [dict get $stat region] \
        $rev \
        [expr {int([dict get $stat quantity])}] \
        [dict get $stat avg_price] \
        [expr {int([dict get $stat sales])}]]
}
puts "  [string repeat - 52]"
puts [format "  %-10s \$%11.2f" "TOTAL" $grand_total]

# === Report 2: Top Products by Revenue ===
puts ""
print_separator
puts "REPORT 2: Top Products by Revenue"
print_separator

set by_product [pipeline_group_by $sales_data product]
set product_stats [list]

dict for {product records} $by_product {
    set total_rev [pipeline_aggregate $records revenue sum]
    set total_qty [pipeline_aggregate $records quantity sum]
    lappend product_stats [dict create \
        product $product revenue $total_rev quantity $total_qty]
}

set product_stats [lsort -command {apply {{a b} {
    set ra [dict get $a revenue]
    set rb [dict get $b revenue]
    expr {$rb < $ra ? -1 : ($rb > $ra ? 1 : 0)}
}}} $product_stats]

puts [format "  %-20s %12s %8s %8s" "Product" "Revenue" "Qty" "% Total"]
puts "  [string repeat - 52]"
foreach stat $product_stats {
    set rev [dict get $stat revenue]
    set pct [expr {100.0 * $rev / $grand_total}]
    puts [format "  %-20s \$%11.2f %8d %7.1f%%" \
        [dict get $stat product] \
        $rev \
        [expr {int([dict get $stat quantity])}] \
        $pct]
}

# === Report 3: Monthly Trend ===
puts ""
print_separator
puts "REPORT 3: Monthly Revenue Trend"
print_separator

set months_order {Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec}
set by_month [pipeline_group_by $sales_data month]

set max_monthly 0.0
set monthly_revs [dict create]
foreach month $months_order {
    if {[dict exists $by_month $month]} {
        set rev [pipeline_aggregate [dict get $by_month $month] revenue sum]
    } else {
        set rev 0.0
    }
    dict set monthly_revs $month $rev
    if {$rev > $max_monthly} { set max_monthly $rev }
}

set bar_width 35
foreach month $months_order {
    set rev [dict get $monthly_revs $month]
    set bar_len [expr {int(double($rev) / $max_monthly * $bar_width)}]
    if {$bar_len < 1 && $rev > 0} { set bar_len 1 }
    set bar [string repeat "#" $bar_len]
    puts [format "  %s  \$%10.2f  %s" $month $rev $bar]
}

# === Report 4: Top 10 Individual Sales ===
puts ""
print_separator
puts "REPORT 4: Top 10 Individual Sales"
print_separator

set sorted_sales [lsort -command {apply {{a b} {
    set ra [dict get $a revenue]
    set rb [dict get $b revenue]
    expr {$rb < $ra ? -1 : ($rb > $ra ? 1 : 0)}
}}} $sales_data]

puts [format "  %-4s %-5s %-8s %-18s %5s %8s %10s" \
    "Rank" "Month" "Region" "Product" "Qty" "Price" "Revenue"]
puts "  [string repeat - 65]"

set rank 0
foreach sale [lrange $sorted_sales 0 9] {
    incr rank
    puts [format "  %-4d %-5s %-8s %-18s %5d \$%7s \$%9s" \
        $rank \
        [dict get $sale month] \
        [dict get $sale region] \
        [dict get $sale product] \
        [dict get $sale quantity] \
        [dict get $sale price] \
        [dict get $sale revenue]]
}

puts "\nDone."
