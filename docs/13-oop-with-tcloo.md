# 13. Object-Oriented Programming with TclOO

Tcl 8.6 introduced **TclOO**, a built-in object system that supports classes, inheritance, mixins, and metaclasses.

## Defining a Class

```tcl
oo::class create Animal {
    variable name species sound

    constructor {n s {snd "..."}} {
        set name $n
        set species $s
        set sound $snd
    }

    method speak {} {
        puts "$name the $species says: $sound"
    }

    method get_name {} {
        return $name
    }

    method describe {} {
        puts "Name: $name, Species: $species"
    }
}

# Create objects
set dog [Animal new "Rex" "Dog" "Woof!"]
set cat [Animal new "Whiskers" "Cat" "Meow!"]

$dog speak       ;# → Rex the Dog says: Woof!
$cat speak       ;# → Whiskers the Cat says: Meow!
$dog describe    ;# → Name: Rex, Species: Dog
```

## Creating Named Objects

```tcl
# Using 'create' instead of 'new' gives the object a fixed name
Animal create myPet "Buddy" "Dog" "Bark!"
myPet speak     ;# → Buddy the Dog says: Bark!
myPet destroy   ;# Explicitly destroy
```

## Destructors

```tcl
oo::class create Resource {
    variable handle name

    constructor {n} {
        set name $n
        set handle "resource_$n"
        puts "Acquired resource: $handle"
    }

    destructor {
        puts "Released resource: $handle"
    }

    method use {} {
        puts "Using $handle"
    }
}

set r [Resource new "database"]   ;# → Acquired resource: resource_database
$r use                             ;# → Using resource_database
$r destroy                         ;# → Released resource: resource_database
```

## Inheritance

```tcl
oo::class create Shape {
    variable color

    constructor {{c "black"}} {
        set color $c
    }

    method get_color {} {
        return $color
    }

    method area {} {
        error "area not implemented for [info object class [self]]"
    }

    method describe {} {
        puts "[info object class [self]]: color=$color, area=[my area]"
    }
}

oo::class create Circle {
    superclass Shape
    variable radius

    constructor {r {color "red"}} {
        next $color
        set radius $r
    }

    method area {} {
        expr {3.14159265358979 * $radius * $radius}
    }

    method perimeter {} {
        expr {2 * 3.14159265358979 * $radius}
    }
}

oo::class create Rectangle {
    superclass Shape
    variable width height

    constructor {w h {color "blue"}} {
        next $color
        set width $w
        set height $h
    }

    method area {} {
        expr {$width * $height}
    }

    method perimeter {} {
        expr {2 * ($width + $height)}
    }
}

set c [Circle new 5]
set r [Rectangle new 4 6]

$c describe   ;# → ::Circle: color=red, area=78.5398...
$r describe   ;# → ::Rectangle: color=blue, area=24

puts "Circle perimeter: [$c perimeter]"
puts "Rectangle perimeter: [$r perimeter]"
```

### Calling Parent Methods with `next`

```tcl
oo::class create Base {
    method greet {} {
        puts "Hello from Base"
    }
}

oo::class create Derived {
    superclass Base

    method greet {} {
        next                         ;# Call parent's greet
        puts "Hello from Derived"
    }
}

[Derived new] greet
# Output:
# Hello from Base
# Hello from Derived
```

## Multiple Inheritance

```tcl
oo::class create Printable {
    method to_string {} {
        return "[info object class [self]] object"
    }

    method print {} {
        puts [my to_string]
    }
}

oo::class create Serializable {
    method serialize {} {
        set data {}
        foreach var [info object vars [self]] {
            set val [my varget $var]
            lappend data $var $val
        }
        return $data
    }
}

oo::class create Document {
    superclass Printable Serializable
    variable title content

    constructor {t c} {
        set title $t
        set content $c
    }

    method to_string {} {
        return "Document: $title"
    }

    method varget {name} {
        variable $name
        return [set $name]
    }
}

set doc [Document new "README" "Hello World"]
$doc print   ;# → Document: README
```

## Mixins

Mixins add functionality to a class or object dynamically:

```tcl
oo::class create Timestamped {
    variable created_at updated_at

    method init_timestamps {} {
        set created_at [clock seconds]
        set updated_at $created_at
    }

    method touch {} {
        set updated_at [clock seconds]
    }

    method get_created {} {
        return [clock format $created_at]
    }

    method get_updated {} {
        return [clock format $updated_at]
    }
}

oo::class create Loggable {
    method log {level msg} {
        set class [info object class [self]]
        puts "\[$level\] $class: $msg"
    }
}

oo::class create User {
    mixin Timestamped Loggable
    variable username email

    constructor {uname mail} {
        set username $uname
        set email $mail
        my init_timestamps
        my log INFO "User '$username' created"
    }

    method update_email {new_email} {
        set email $new_email
        my touch
        my log INFO "Email updated for '$username'"
    }
}

set u [User new "alice" "alice@example.com"]
$u update_email "alice@newdomain.com"
puts "Created: [$u get_created]"
```

### Per-Object Mixins

```tcl
oo::class create Debuggable {
    method debug_info {} {
        puts "Object: [self]"
        puts "Class: [info object class [self]]"
        puts "Methods: [info object methods [self] -all]"
    }
}

set u1 [User new "bob" "bob@example.com"]
oo::objdefine $u1 mixin Debuggable

$u1 debug_info   ;# Only u1 has this method
```

## Class Methods (Static Methods)

```tcl
oo::class create Counter {
    variable value
    self variable instance_count

    constructor {} {
        set value 0
        Counter variable instance_count
        incr instance_count
    }

    method incr {} {
        ::incr value
    }

    method get {} {
        return $value
    }

    self method count {} {
        my variable instance_count
        return $instance_count
    }

    self method reset_all {} {
        my variable instance_count
        set instance_count 0
    }
}

# Initialize class variable
oo::define Counter self variable instance_count
Counter variable instance_count
set Counter::instance_count 0

Counter new
Counter new
Counter new
```

## Forwarding Methods

Forward a method call to another command or object:

```tcl
oo::class create ListWrapper {
    variable data

    constructor {args} {
        set data $args
    }

    forward length  llength
    forward sort    lsort

    method get {} { return $data }

    method length {} {
        llength $data
    }

    method add {item} {
        lappend data $item
    }

    method at {index} {
        lindex $data $index
    }
}
```

## Object Introspection

```tcl
oo::class create Example {
    variable x y
    constructor {} { set x 1; set y 2 }
    method foo {} {}
    method bar {} {}
}

set obj [Example new]

# Query object information
info object class $obj          ;# → ::Example
info object methods $obj        ;# → {} (direct methods only)
info object methods $obj -all   ;# → foo bar destroy (inherited too)
info object vars $obj           ;# → x y
info object isa object $obj     ;# → 1
info object isa class Example   ;# → 1

# Query class information
info class instances Example    ;# → list of objects
info class methods Example      ;# → foo bar
info class superclasses Example ;# → ::oo::object
info class variables Example    ;# → x y
```

## Design Pattern: Observer

```tcl
oo::class create Observable {
    variable observers

    constructor {} {
        set observers {}
    }

    method subscribe {event callback} {
        dict lappend observers $event $callback
    }

    method notify {event args} {
        if {[dict exists $observers $event]} {
            foreach cb [dict get $observers $event] {
                {*}$cb $event {*}$args
            }
        }
    }
}

oo::class create TemperatureSensor {
    superclass Observable
    variable temp

    constructor {} {
        next
        set temp 20.0
    }

    method set_temperature {t} {
        set old $temp
        set temp $t
        if {$temp != $old} {
            my notify temperature_changed $old $temp
        }
    }

    method get_temperature {} {
        return $temp
    }
}

proc on_temp_change {event old new} {
    puts "Temperature changed: $old → $new"
    if {$new > 30} {
        puts "WARNING: High temperature!"
    }
}

set sensor [TemperatureSensor new]
$sensor subscribe temperature_changed on_temp_change
$sensor set_temperature 25.0   ;# → Temperature changed: 20.0 → 25.0
$sensor set_temperature 35.0   ;# → ... WARNING: High temperature!
```

## Practical Example: Bank Account

```tcl
oo::class create BankAccount {
    variable owner balance transactions

    constructor {owner_name {initial_balance 0}} {
        set owner $owner_name
        set balance $initial_balance
        set transactions {}
        my record "Account opened" $initial_balance
    }

    method deposit {amount} {
        if {$amount <= 0} {
            throw {BANK INVALID_AMOUNT} "Deposit amount must be positive"
        }
        set balance [expr {$balance + $amount}]
        my record "Deposit" $amount
        return $balance
    }

    method withdraw {amount} {
        if {$amount <= 0} {
            throw {BANK INVALID_AMOUNT} "Withdrawal amount must be positive"
        }
        if {$amount > $balance} {
            throw {BANK INSUFFICIENT_FUNDS} \
                "Insufficient funds (balance: $balance, requested: $amount)"
        }
        set balance [expr {$balance - $amount}]
        my record "Withdrawal" -$amount
        return $balance
    }

    method get_balance {} {
        return $balance
    }

    method statement {} {
        puts "=== Account Statement: $owner ==="
        puts [format "%-20s %10s %10s" "Description" "Amount" "Balance"]
        puts [string repeat "-" 42]
        set running 0
        foreach tx $transactions {
            lassign $tx desc amount timestamp
            set running [expr {$running + $amount}]
            puts [format "%-20s %10.2f %10.2f" $desc $amount $running]
        }
        puts [string repeat "-" 42]
        puts [format "%-20s %10s %10.2f" "Current Balance" "" $balance]
    }

    method record {description amount} {
        lappend transactions [list $description $amount [clock seconds]]
    }
}

set acct [BankAccount new "Alice" 1000]
$acct deposit 500
$acct withdraw 200
$acct deposit 1000
$acct withdraw 750
$acct statement
```

---

**Previous:** [Namespaces & Packages](12-namespaces-and-packages.md) | **Next:** [Event-Driven Programming](14-event-driven-programming.md)
