#!/usr/bin/env tclsh
#
# 07_oop.tcl — Demonstrates Object-Oriented Programming with TclOO
#

puts "=============================="
puts " Object-Oriented Programming"
puts "=============================="
puts ""

# --- Basic Class ---
puts "--- Basic Class ---"

oo::class create BankAccount {
    variable owner balance transactions

    constructor {owner_name {initial_balance 0}} {
        set owner $owner_name
        set balance $initial_balance
        set transactions [list]
        my log_transaction "Account opened" $initial_balance
    }

    method deposit {amount} {
        if {$amount <= 0} {
            error "Deposit amount must be positive"
        }
        set balance [expr {$balance + $amount}]
        my log_transaction "Deposit" $amount
        return $balance
    }

    method withdraw {amount} {
        if {$amount <= 0} {
            error "Withdrawal amount must be positive"
        }
        if {$amount > $balance} {
            error "Insufficient funds (balance: \$[format "%.2f" $balance])"
        }
        set balance [expr {$balance - $amount}]
        my log_transaction "Withdrawal" -$amount
        return $balance
    }

    method get_balance {} {
        return $balance
    }

    method get_owner {} {
        return $owner
    }

    method statement {} {
        puts [string repeat "=" 50]
        puts "Account Statement for $owner"
        puts [string repeat "-" 50]
        foreach txn $transactions {
            puts [format "  %-25s  %10s" \
                [dict get $txn description] \
                [dict get $txn amount]]
        }
        puts [string repeat "-" 50]
        puts [format "  %-25s  %10s" "Current Balance:" "\$[format "%.2f" $balance]"]
        puts [string repeat "=" 50]
    }

    method log_transaction {desc amount} {
        lappend transactions [dict create \
            description $desc \
            amount "\$[format "%.2f" $amount]" \
            time [clock format [clock seconds] -format "%H:%M:%S"] \
        ]
    }
}

set acct [BankAccount new "Alice" 1000.00]
$acct deposit 500.00
$acct deposit 250.00
$acct withdraw 120.00
$acct withdraw 80.50
$acct statement
puts ""

# --- Inheritance ---
puts "--- Inheritance ---"

oo::class create SavingsAccount {
    superclass BankAccount
    variable interest_rate

    constructor {owner_name initial_balance rate} {
        next $owner_name $initial_balance
        set interest_rate $rate
    }

    method apply_interest {} {
        set bal [my get_balance]
        set interest [expr {$bal * $interest_rate}]
        my deposit $interest
        puts "Applied [format "%.1f%%" [expr {$interest_rate * 100}]] interest: \$[format "%.2f" $interest]"
    }

    method get_rate {} {
        return $interest_rate
    }
}

set savings [SavingsAccount new "Bob" 5000.00 0.035]
$savings apply_interest
$savings deposit 1000
$savings apply_interest
$savings statement
puts ""

# --- Polymorphism ---
puts "--- Polymorphism ---"

oo::class create Shape {
    variable name

    constructor {shape_name} {
        set name $shape_name
    }

    method area {} {
        error "area not implemented for $name"
    }

    method perimeter {} {
        error "perimeter not implemented for $name"
    }

    method describe {} {
        puts [format "  %-12s  Area: %8.2f  Perimeter: %8.2f" \
            $name [my area] [my perimeter]]
    }
}

oo::class create Circle {
    superclass Shape
    variable radius

    constructor {r} {
        next "Circle(r=$r)"
        set radius $r
    }

    method area {} {
        return [expr {3.14159265 * $radius * $radius}]
    }

    method perimeter {} {
        return [expr {2 * 3.14159265 * $radius}]
    }
}

oo::class create Rectangle {
    superclass Shape
    variable width height

    constructor {w h} {
        next "Rect(${w}x${h})"
        set width $w
        set height $h
    }

    method area {} {
        return [expr {$width * $height}]
    }

    method perimeter {} {
        return [expr {2 * ($width + $height)}]
    }
}

oo::class create Triangle {
    superclass Shape
    variable a b c

    constructor {side_a side_b side_c} {
        next "Tri(${side_a},${side_b},${side_c})"
        set a $side_a
        set b $side_b
        set c $side_c
    }

    method area {} {
        set s [expr {($a + $b + $c) / 2.0}]
        return [expr {sqrt($s * ($s - $a) * ($s - $b) * ($s - $c))}]
    }

    method perimeter {} {
        return [expr {$a + $b + $c}]
    }
}

puts "Shape calculations:"
set shapes [list \
    [Circle new 5] \
    [Rectangle new 4 6] \
    [Rectangle new 10 3] \
    [Triangle new 3 4 5] \
    [Circle new 10] \
]

foreach shape $shapes {
    $shape describe
}
puts ""

# --- Class with Static-like Methods ---
puts "--- Namespace Ensemble (Static Pattern) ---"

oo::class create IDGenerator {
    variable prefix counter

    constructor {{pfx "ID"}} {
        set prefix $pfx
        set counter 0
    }

    method next {} {
        incr counter
        return [format "%s-%04d" $prefix $counter]
    }

    method current {} {
        return [format "%s-%04d" $prefix $counter]
    }

    method reset {} {
        set counter 0
    }
}

set gen [IDGenerator new "EMP"]
puts "Generated IDs:"
for {set i 0} {$i < 5} {incr i} {
    puts "  [$gen next]"
}
puts ""

# --- Linked List Implementation ---
puts "--- Linked List (OOP Data Structure) ---"

oo::class create LinkedList {
    variable head size

    constructor {} {
        set head [list]
        set size 0
    }

    method push {value} {
        set head [list $value $head]
        incr size
    }

    method pop {} {
        if {$size == 0} {
            error "List is empty"
        }
        set value [lindex $head 0]
        set head [lindex $head 1]
        incr size -1
        return $value
    }

    method peek {} {
        if {$size == 0} {
            error "List is empty"
        }
        return [lindex $head 0]
    }

    method length {} {
        return $size
    }

    method to_list {} {
        set result [list]
        set current $head
        while {[llength $current] > 0} {
            lappend result [lindex $current 0]
            set current [lindex $current 1]
        }
        return $result
    }

    method display {} {
        set items [my to_list]
        if {[llength $items] == 0} {
            puts "  (empty)"
        } else {
            puts "  [join $items " -> "] -> nil"
        }
    }
}

set ll [LinkedList new]
foreach val [list 10 20 30 40 50] {
    $ll push $val
}
puts "List contents:"
$ll display
puts "Length: [$ll length]"
puts "Pop: [$ll pop]"
puts "Pop: [$ll pop]"
puts "After popping:"
$ll display
puts ""

# Cleanup
foreach shape $shapes { $shape destroy }
$acct destroy
$savings destroy
$gen destroy
$ll destroy

puts "Done!"
