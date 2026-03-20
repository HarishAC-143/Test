#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 17: Object-Oriented Programming (TclOO)
# =============================================================================

package require TclOO

puts "=== Basic Class Definition ==="
oo::class create Animal {
    variable name species sound

    constructor {n s {snd ""}} {
        set name $n
        set species $s
        set sound $snd
    }

    method speak {} {
        if {$sound ne ""} {
            puts "$name says $sound!"
        } else {
            puts "$name is silent."
        }
    }

    method describe {} {
        puts "$name is a $species"
    }

    method get_name {} {
        return $name
    }

    method get_species {} {
        return $species
    }
}

set dog [Animal new "Rex" "Dog" "Woof"]
set cat [Animal new "Whiskers" "Cat" "Meow"]
set fish [Animal new "Nemo" "Fish"]

$dog speak
$cat speak
$fish speak
$dog describe

puts "\n=== Inheritance ==="
oo::class create Pet {
    superclass Animal
    variable owner vaccinated

    constructor {name species sound owner_name} {
        next $name $species $sound
        set owner $owner_name
        set vaccinated false
    }

    method vaccinate {} {
        set vaccinated true
        puts "[my get_name] has been vaccinated"
    }

    method info {} {
        puts "[my get_name] ([my get_species])"
        puts "  Owner: $owner"
        puts "  Vaccinated: $vaccinated"
    }
}

set buddy [Pet new "Buddy" "Golden Retriever" "Woof" "Alice"]
$buddy speak
$buddy info
$buddy vaccinate
$buddy info

puts "\n=== Multi-level Inheritance ==="
oo::class create ServiceDog {
    superclass Pet
    variable task certified

    constructor {name owner_name task_desc} {
        next $name "Service Dog" "Woof" $owner_name
        set task $task_desc
        set certified false
    }

    method certify {} {
        set certified true
        puts "[my get_name] is now certified for: $task"
    }

    method info {} {
        next
        puts "  Task: $task"
        puts "  Certified: $certified"
    }
}

set helper [ServiceDog new "Max" "Bob" "Guide Dog"]
$helper info
$helper certify

puts "\n=== Class with Methods Operating on State ==="
oo::class create BankAccount {
    variable owner balance transactions

    constructor {owner_name {initial_balance 0}} {
        set owner $owner_name
        set balance $initial_balance
        set transactions {}
        lappend transactions [list "OPEN" $initial_balance $balance \
            [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]]
    }

    method deposit {amount} {
        if {$amount <= 0} {
            error "Deposit amount must be positive"
        }
        set balance [expr {$balance + $amount}]
        lappend transactions [list "DEPOSIT" $amount $balance \
            [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]]
        puts "Deposited \$[format %.2f $amount]. Balance: \$[format %.2f $balance]"
    }

    method withdraw {amount} {
        if {$amount <= 0} {
            error "Withdrawal amount must be positive"
        }
        if {$amount > $balance} {
            error "Insufficient funds (balance: \$[format %.2f $balance])"
        }
        set balance [expr {$balance - $amount}]
        lappend transactions [list "WITHDRAW" $amount $balance \
            [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]]
        puts "Withdrew \$[format %.2f $amount]. Balance: \$[format %.2f $balance]"
    }

    method get_balance {} {
        return $balance
    }

    method statement {} {
        puts "\n--- Account Statement for $owner ---"
        puts [format "%-12s %10s %10s  %-20s" "Type" "Amount" "Balance" "Date"]
        puts [string repeat "-" 56]
        foreach txn $transactions {
            lassign $txn type amount bal date
            puts [format "%-12s %10.2f %10.2f  %-20s" $type $amount $bal $date]
        }
        puts [string repeat "-" 56]
        puts [format "Current Balance: \$%.2f" $balance]
    }
}

set acct [BankAccount new "Alice" 1000.00]
$acct deposit 500.00
$acct deposit 250.50
$acct withdraw 100.00
$acct withdraw 75.25
$acct statement

puts "\n=== Class Variables (shared across instances) ==="
oo::class create Counter {
    variable count id
    self variable total_instances

    constructor {} {
        set count 0
        my variable id
        set total [oo::objdefine [self class] eval {variable total_instances; incr total_instances}]
        set id $total
    }

    method increment {{by 1}} {
        incr count $by
    }

    method get {} {
        return $count
    }

    method whoami {} {
        return "Counter #$id (count=$count)"
    }
}

set c1 [Counter new]
set c2 [Counter new]
$c1 increment 5
$c2 increment 3
puts [$c1 whoami]
puts [$c2 whoami]

puts "\n=== Mixins (Reusable Behaviors) ==="
oo::class create Printable {
    method print {} {
        set cls [info object class [self]]
        set vars [info object vars [self]]
        puts "\[$cls object\]"
        foreach var $vars {
            my variable $var
            puts "  $var = [set $var]"
        }
    }
}

oo::class create Point {
    variable x y
    constructor {px py} {
        set x $px
        set y $py
    }
    method coords {} { return [list $x $y] }
    method distance_to {other} {
        lassign [$other coords] ox oy
        expr {sqrt(($ox-$x)**2 + ($oy-$y)**2)}
    }
}

oo::define Point mixin Printable

set p1 [Point new 3 4]
set p2 [Point new 6 8]
$p1 print
puts "Distance p1->p2: [format %.4f [$p1 distance_to $p2]]"

puts "\n=== Destroying Objects ==="
oo::class create Temp {
    variable name
    constructor {n} {
        set name $n
        puts "Created: $name"
    }
    destructor {
        puts "Destroyed: $name"
    }
}

set t [Temp new "temporary"]
$t destroy

puts "\n=== Forward Methods ==="
oo::class create FileWrapper {
    variable path fd

    constructor {filepath} {
        set path $filepath
    }

    method read_all {} {
        if {![file exists $path]} {
            return ""
        }
        set fd [open $path r]
        set content [read $fd]
        close $fd
        return $content
    }

    method write {content} {
        set fd [open $path w]
        puts -nonewline $fd $content
        close $fd
    }

    method exists {} {
        return [file exists $path]
    }

    method get_path {} {
        return $path
    }
}

set fw [FileWrapper new "/tmp/tcl_oop_test.txt"]
$fw write "Hello from TclOO!\nSecond line."
puts "File exists: [$fw exists]"
puts "Content: [$fw read_all]"
file delete "/tmp/tcl_oop_test.txt"
