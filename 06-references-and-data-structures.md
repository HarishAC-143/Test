# Chapter 6: References and Data Structures

References are the mechanism Perl uses to create complex, nested data structures. A reference is a scalar value that "points to" another value (scalar, array, hash, subroutine, or filehandle).

## Creating References

### References to Existing Variables

Use the backslash operator `\` to create a reference:

```perl
#!/usr/bin/perl
use strict;
use warnings;

# Scalar reference
my $name = "Alice";
my $name_ref = \$name;

# Array reference
my @colors = ("red", "green", "blue");
my $colors_ref = \@colors;

# Hash reference
my %person = (name => "Bob", age => 25);
my $person_ref = \%person;

# Subroutine reference
sub greet { print "Hello!\n" }
my $greet_ref = \&greet;
```

### Anonymous References

Create references to data without naming the original variable:

```perl
# Anonymous array reference (square brackets)
my $fruits = ["apple", "banana", "cherry"];

# Anonymous hash reference (curly braces)
my $config = {
    host  => "localhost",
    port  => 8080,
    debug => 1,
};

# Anonymous subroutine reference
my $square = sub { return $_[0] ** 2 };
```

## Dereferencing

To access the value a reference points to, you must **dereference** it.

```perl
my $name = "Alice";
my $ref = \$name;

# Scalar dereferencing
print $$ref, "\n";         # Alice
print ${$ref}, "\n";       # Alice (clearer with braces)

# Array dereferencing
my $arr_ref = [10, 20, 30];
print $$arr_ref[0], "\n";       # 10
print ${$arr_ref}[1], "\n";     # 20
print $arr_ref->[2], "\n";      # 30  (arrow notation — preferred)

# Full array dereference
my @copy = @$arr_ref;           # (10, 20, 30)
my @copy2 = @{$arr_ref};        # same thing

# Hash dereferencing
my $hash_ref = { name => "Bob", age => 25 };
print $$hash_ref{name}, "\n";       # Bob
print ${$hash_ref}{age}, "\n";      # 25
print $hash_ref->{name}, "\n";      # Bob (arrow notation — preferred)

# Full hash dereference
my %copy = %$hash_ref;

# Subroutine dereferencing
my $func = sub { return $_[0] * 2 };
print $func->(5), "\n";     # 10
print &$func(5), "\n";      # 10
```

> **Best Practice**: Use the **arrow notation** (`->`) for dereferencing. It is the clearest and most widely used style.

## Nested Data Structures

References allow you to build complex, multi-level structures.

### Array of Arrays

```perl
my $matrix = [
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9],
];

# Access element at row 1, column 2
print $matrix->[1][2], "\n";   # 6

# Iterate over the matrix
for my $row (@$matrix) {
    for my $val (@$row) {
        printf "%3d", $val;
    }
    print "\n";
}
# Output:
#   1  2  3
#   4  5  6
#   7  8  9
```

### Array of Hashes

```perl
my @employees = (
    { name => "Alice",   dept => "Engineering", salary => 95000 },
    { name => "Bob",     dept => "Marketing",   salary => 72000 },
    { name => "Carol",   dept => "Engineering", salary => 88000 },
    { name => "Dave",    dept => "Marketing",   salary => 68000 },
);

# Print all employees
for my $emp (@employees) {
    printf "%-10s %-15s \$%d\n", $emp->{name}, $emp->{dept}, $emp->{salary};
}

# Filter: engineers only
my @engineers = grep { $_->{dept} eq "Engineering" } @employees;

# Sort by salary (descending)
my @by_salary = sort { $b->{salary} <=> $a->{salary} } @employees;

# Total salary by department
my %dept_total;
for my $emp (@employees) {
    $dept_total{$emp->{dept}} += $emp->{salary};
}

for my $dept (sort keys %dept_total) {
    printf "%-15s \$%d\n", $dept, $dept_total{$dept};
}
```

### Hash of Arrays

```perl
my %courses = (
    math    => ["Alice", "Bob", "Carol"],
    science => ["Bob", "Dave", "Eve"],
    english => ["Alice", "Carol", "Eve", "Frank"],
);

# Print students in each course
for my $course (sort keys %courses) {
    my @students = @{$courses{$course}};
    print "$course: ", join(", ", @students), "\n";
}

# Add a student to a course
push @{$courses{math}}, "Eve";

# Find students in both math and science
my %math_students = map { $_ => 1 } @{$courses{math}};
my @both = grep { $math_students{$_} } @{$courses{science}};
print "In both math and science: @both\n";
```

### Hash of Hashes

```perl
my %inventory = (
    fruits => {
        apple  => { price => 1.20, stock => 50 },
        banana => { price => 0.50, stock => 100 },
    },
    vegetables => {
        carrot => { price => 0.80, stock => 75 },
        potato => { price => 0.60, stock => 200 },
    },
);

# Access nested values
print "Apple price: \$", $inventory{fruits}{apple}{price}, "\n";

# Iterate over the entire structure
for my $category (sort keys %inventory) {
    print "\n=== \u$category ===\n";
    for my $item (sort keys %{$inventory{$category}}) {
        my $info = $inventory{$category}{$item};
        printf "  %-10s \$%.2f  (stock: %d)\n",
               $item, $info->{price}, $info->{stock};
    }
}
```

## The ref() Function

Use `ref()` to determine what type of reference a scalar holds.

```perl
my $scalar_ref = \"hello";
my $array_ref  = [1, 2, 3];
my $hash_ref   = { a => 1 };
my $code_ref   = sub { 1 };
my $regex_ref  = qr/pattern/;

print ref($scalar_ref), "\n";   # SCALAR
print ref($array_ref), "\n";    # ARRAY
print ref($hash_ref), "\n";     # HASH
print ref($code_ref), "\n";     # CODE
print ref($regex_ref), "\n";    # Regexp

# Useful for type checking
sub process {
    my ($data) = @_;
    if (ref($data) eq "ARRAY") {
        print "Processing array with ", scalar @$data, " elements\n";
    } elsif (ref($data) eq "HASH") {
        print "Processing hash with ", scalar keys %$data, " keys\n";
    } else {
        print "Processing scalar: $data\n";
    }
}

process([1, 2, 3]);                 # Processing array with 3 elements
process({ a => 1, b => 2 });        # Processing hash with 2 keys
process("hello");                   # Processing scalar: hello
```

## Data::Dumper — Inspecting Data Structures

`Data::Dumper` is an invaluable debugging tool that prints complex data structures in a readable format.

```perl
use Data::Dumper;

my $complex = {
    users => [
        { name => "Alice", roles => ["admin", "user"] },
        { name => "Bob",   roles => ["user"] },
    ],
    settings => {
        theme    => "dark",
        language => "en",
    },
};

print Dumper($complex);
```

Output:

```
$VAR1 = {
          'settings' => {
                          'language' => 'en',
                          'theme' => 'dark'
                        },
          'users' => [
                       {
                         'name' => 'Alice',
                         'roles' => [
                                      'admin',
                                      'user'
                                    ]
                       },
                       {
                         'name' => 'Bob',
                         'roles' => [
                                      'user'
                                    ]
                       }
                     ]
        };
```

## Avoiding Common Pitfalls

### Autovivification

Perl automatically creates intermediate references when you access nested structures:

```perl
my %data;

# This automatically creates $data{a} as a hash ref and $data{a}{b} as a hash ref
$data{a}{b}{c} = "deep value";

print Dumper(\%data);
# $VAR1 = { 'a' => { 'b' => { 'c' => 'deep value' } } };

# Be careful: even checking existence can autovivify!
if ($data{x}{y}{z}) {  # creates $data{x} and $data{x}{y} as side effect
    print "Found\n";
}

# Use exists() safely at each level
if (exists $data{x} && exists $data{x}{y} && exists $data{x}{y}{z}) {
    print "Truly found\n";
}
```

### Circular References and Memory Leaks

```perl
# This creates a circular reference that leaks memory
my $a = {};
my $b = {};
$a->{other} = $b;
$b->{other} = $a;   # circular!

# Solution: use Scalar::Util's weaken()
use Scalar::Util qw(weaken);
$b->{other} = $a;
weaken($b->{other});  # won't prevent $a from being garbage collected
```

## Practical Example: Configuration File Parser

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

my $config_text = <<'END_CONFIG';
[database]
host = db.example.com
port = 5432
name = myapp_production
max_connections = 20

[server]
host = 0.0.0.0
port = 8080
workers = 4

[logging]
level = info
file = /var/log/myapp.log
rotate = daily
END_CONFIG

sub parse_ini {
    my ($text) = @_;
    my %config;
    my $current_section = "global";

    for my $line (split /\n/, $text) {
        $line =~ s/^\s+|\s+$//g;    # trim whitespace
        next if $line eq '' || $line =~ /^[#;]/;   # skip empty lines and comments

        if ($line =~ /^\[(.+)\]$/) {
            $current_section = $1;
            next;
        }

        if ($line =~ /^(\w+)\s*=\s*(.+)$/) {
            $config{$current_section}{$1} = $2;
        }
    }

    return \%config;
}

my $config = parse_ini($config_text);

print "Database host: $config->{database}{host}\n";
print "Server port: $config->{server}{port}\n";
print "Log level: $config->{logging}{level}\n";

print "\nFull config:\n";
print Dumper($config);
```

## Chapter Summary

- References are scalars that point to other values, enabling complex data structures.
- Use `\` to reference existing variables; use `[]` for anonymous arrays and `{}` for anonymous hashes.
- The arrow notation `->` is the preferred way to dereference.
- Nested structures (AoA, AoH, HoA, HoH) are built by combining references.
- Use `ref()` to check what type of reference a scalar holds.
- `Data::Dumper` is essential for inspecting complex data structures during development.
- Watch out for autovivification and circular references.

---

**Previous**: [Chapter 5 — Regular Expressions](05-regular-expressions.md)
**Next**: [Chapter 7 — File I/O](07-file-io.md)
