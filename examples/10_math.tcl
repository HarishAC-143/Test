#!/usr/bin/env tclsh
# =============================================================================
# TCL Tutorial — Example 10: Math and Expressions
# =============================================================================

puts "=== Arithmetic Operators ==="
puts "10 + 3  = [expr {10 + 3}]"
puts "10 - 3  = [expr {10 - 3}]"
puts "10 * 3  = [expr {10 * 3}]"
puts "10 / 3  = [expr {10 / 3}]   (integer division)"
puts "10.0 / 3 = [expr {10.0 / 3}] (float division)"
puts "10 % 3  = [expr {10 % 3}]   (modulo)"
puts "2 ** 10 = [expr {2 ** 10}]  (exponentiation)"

puts "\n=== Comparison Operators ==="
puts "5 == 5  : [expr {5 == 5}]"
puts "5 != 3  : [expr {5 != 3}]"
puts "5 > 3   : [expr {5 > 3}]"
puts "5 < 3   : [expr {5 < 3}]"
puts "5 >= 5  : [expr {5 >= 5}]"
puts "5 <= 3  : [expr {5 <= 3}]"

puts "\n=== String Comparison in expr ==="
puts {Use eq/ne for string comparison in expr:}
puts "  \"abc\" eq \"abc\" : [expr {"abc" eq "abc"}]"
puts "  \"abc\" ne \"def\" : [expr {"abc" ne "def"}]"

puts "\n=== Logical Operators ==="
puts "1 && 1  : [expr {1 && 1}]"
puts "1 && 0  : [expr {1 && 0}]"
puts "1 || 0  : [expr {1 || 0}]"
puts "0 || 0  : [expr {0 || 0}]"
puts "!0      : [expr {!0}]"
puts "!1      : [expr {!1}]"

puts "\n=== Bitwise Operators ==="
puts "0xFF & 0x0F  : [format 0x%02X [expr {0xFF & 0x0F}]]"
puts "0xF0 | 0x0F  : [format 0x%02X [expr {0xF0 | 0x0F}]]"
puts "0xFF ^ 0x0F  : [format 0x%02X [expr {0xFF ^ 0x0F}]]"
puts "~0x00 (8bit) : [format 0x%02X [expr {(~0x00) & 0xFF}]]"
puts "1 << 4       : [expr {1 << 4}]"
puts "16 >> 2      : [expr {16 >> 2}]"

puts "\n=== Math Functions ==="
puts "abs(-42)     : [expr {abs(-42)}]"
puts "sqrt(144)    : [expr {sqrt(144)}]"
puts "pow(2, 10)   : [expr {pow(2, 10)}]"
puts "round(3.7)   : [expr {round(3.7)}]"
puts "round(3.2)   : [expr {round(3.2)}]"
puts "int(3.99)    : [expr {int(3.99)}]"
puts "ceil(3.2)    : [expr {ceil(3.2)}]"
puts "floor(3.9)   : [expr {floor(3.9)}]"
puts "double(42)   : [expr {double(42)}]"
puts "wide(42)     : [expr {wide(42)}]"

puts "\n=== Trigonometric Functions ==="
set pi [expr {acos(-1)}]
puts "pi           : $pi"
puts "sin(pi/2)    : [expr {sin($pi/2)}]"
puts "cos(0)       : [expr {cos(0)}]"
puts "tan(pi/4)    : [expr {tan($pi/4)}]"
puts "asin(1)      : [expr {asin(1)}]"
puts "acos(0)      : [expr {acos(0)}]"
puts "atan(1)      : [expr {atan(1)}]"
puts "atan2(1,1)   : [expr {atan2(1,1)}]"
puts "hypot(3,4)   : [expr {hypot(3,4)}]"

puts "\n=== Logarithmic Functions ==="
puts "log(e)       : [expr {log(exp(1))}]"
puts "log10(100)   : [expr {log10(100)}]"
puts "log10(1000)  : [expr {log10(1000)}]"
puts "exp(1)       : [expr {exp(1)}]"

puts "\n=== Random Numbers ==="
puts "rand()       : [expr {rand()}]"
puts "rand()       : [expr {rand()}]"
puts "Random 1-6   : [expr {int(rand()*6) + 1}]"
puts "Random 1-100 : [expr {int(rand()*100) + 1}]"

# Seeding the random number generator
expr {srand(42)}
puts "Seeded rand  : [expr {rand()}]"

puts "\n=== Practical: Temperature Conversion ==="
proc celsius_to_fahrenheit {c} {
    return [expr {$c * 9.0 / 5.0 + 32.0}]
}
proc fahrenheit_to_celsius {f} {
    return [expr {($f - 32.0) * 5.0 / 9.0}]
}
foreach temp {0 20 37 100} {
    puts [format "  %5.1f°C = %5.1f°F" $temp [celsius_to_fahrenheit $temp]]
}

puts "\n=== Practical: Distance Between Points ==="
proc distance {x1 y1 x2 y2} {
    expr {sqrt(($x2-$x1)**2 + ($y2-$y1)**2)}
}
puts [format "Distance (0,0)-(3,4) = %.2f" [distance 0 0 3 4]]
puts [format "Distance (1,2)-(4,6) = %.2f" [distance 1 2 4 6]]

puts "\n=== Practical: Quadratic Formula ==="
proc solve_quadratic {a b c} {
    set discriminant [expr {$b*$b - 4*$a*$c}]
    if {$discriminant < 0} {
        return "No real roots (discriminant = $discriminant)"
    }
    set sqrt_d [expr {sqrt($discriminant)}]
    set x1 [expr {(-$b + $sqrt_d) / (2.0 * $a)}]
    set x2 [expr {(-$b - $sqrt_d) / (2.0 * $a)}]
    return [list $x1 $x2]
}
puts "x^2 - 5x + 6 = 0 → roots: [solve_quadratic 1 -5 6]"
puts "x^2 + 4x + 4 = 0 → roots: [solve_quadratic 1 4 4]"
puts "x^2 + 1 = 0 → [solve_quadratic 1 0 1]"
