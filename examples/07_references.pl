#!/usr/bin/perl
# 07_references.pl — References and complex data structures
use strict;
use warnings;
use feature 'say';
use Data::Dumper;

say "=" x 50;
say "  Perl References & Data Structures Demo";
say "=" x 50;

# --- Scalar References ---
say "\n--- Scalar References ---";

my $name = "Alice";
my $name_ref = \$name;

say "Value: $name";
say "Reference: $name_ref";
say "Dereferenced: $$name_ref";

$$name_ref = "Bob";
say "After modifying via ref, \$name = $name";

# --- Array References ---
say "\n--- Array References ---";

my @colors = ("red", "green", "blue");
my $colors_ref = \@colors;

say "Array: @colors";
say "Via ref [0]: $colors_ref->[0]";
say "Via ref [2]: $$colors_ref[2]";
say "Length via ref: " . scalar(@$colors_ref);

my $anon_array = [10, 20, 30, 40, 50];
say "Anonymous array: @$anon_array";

# --- Hash References ---
say "\n--- Hash References ---";

my %config = (host => "localhost", port => 8080, debug => 1);
my $config_ref = \%config;

say "host: $config_ref->{host}";
say "port: $$config_ref{port}";

my $anon_hash = {
    name  => "Widget",
    price => 19.99,
    stock => 42,
};
say "Product: $anon_hash->{name}, \$$anon_hash->{price}";

# --- Array of Arrays (Matrix) ---
say "\n--- 2D Matrix (Array of Arrays) ---";

my @matrix = (
    [1,  2,  3,  4],
    [5,  6,  7,  8],
    [9,  10, 11, 12],
);

say "Matrix:";
for my $row (@matrix) {
    say "  [" . join(", ", map { sprintf("%3d", $_) } @$row) . "]";
}

say "Element [1][2] = $matrix[1][2]";

# Transpose
my @transposed;
for my $i (0 .. $#matrix) {
    for my $j (0 .. $#{$matrix[$i]}) {
        $transposed[$j][$i] = $matrix[$i][$j];
    }
}

say "\nTransposed:";
for my $row (@transposed) {
    say "  [" . join(", ", map { sprintf("%3d", $_) } @$row) . "]";
}

# --- Array of Hashes (Records) ---
say "\n--- Array of Hashes (Records) ---";

my @employees = (
    { name => "Alice",  dept => "Engineering", salary => 95000 },
    { name => "Bob",    dept => "Marketing",   salary => 75000 },
    { name => "Carol",  dept => "Engineering", salary => 105000 },
    { name => "Dave",   dept => "Sales",       salary => 68000 },
    { name => "Eve",    dept => "Engineering", salary => 88000 },
);

printf "%-10s %-15s %10s\n", "Name", "Department", "Salary";
say "-" x 37;
for my $emp (@employees) {
    printf "%-10s %-15s \$%9d\n", $emp->{name}, $emp->{dept}, $emp->{salary};
}

# Filter and sort
my @engineers = sort { $b->{salary} <=> $a->{salary} }
                grep { $_->{dept} eq "Engineering" }
                @employees;

say "\nEngineers by salary (descending):";
for my $eng (@engineers) {
    say "  $eng->{name}: \$$eng->{salary}";
}

# Aggregate
my %dept_totals;
for my $emp (@employees) {
    $dept_totals{$emp->{dept}} += $emp->{salary};
}

say "\nSalary totals by department:";
for my $dept (sort keys %dept_totals) {
    printf "  %-15s \$%d\n", $dept, $dept_totals{$dept};
}

# --- Hash of Arrays ---
say "\n--- Hash of Arrays ---";

my %courses = (
    math    => ["Alice", "Bob", "Carol"],
    science => ["Dave", "Eve"],
    english => ["Alice", "Dave", "Frank", "Grace"],
    history => ["Bob", "Carol", "Eve", "Frank"],
);

for my $course (sort keys %courses) {
    my $count = scalar @{$courses{$course}};
    say "  $course ($count): " . join(", ", @{$courses{$course}});
}

# --- Hash of Hashes (Nested Config) ---
say "\n--- Hash of Hashes (Nested Config) ---";

my %app_config = (
    database => {
        host     => "db.example.com",
        port     => 5432,
        name     => "production",
        pool     => { min => 5, max => 20 },
    },
    cache => {
        host     => "cache.example.com",
        port     => 6379,
        ttl      => 3600,
    },
    logging => {
        level    => "info",
        file     => "/var/log/app.log",
        rotate   => { size => "100M", keep => 7 },
    },
);

say "DB Host: $app_config{database}{host}";
say "DB Pool Max: $app_config{database}{pool}{max}";
say "Log Rotation Keep: $app_config{logging}{rotate}{keep}";

# --- Data::Dumper for Debugging ---
say "\n--- Data::Dumper Output ---";

$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;

my $complex = {
    users => [
        { id => 1, name => "Alice", roles => ["admin", "user"] },
        { id => 2, name => "Bob",   roles => ["user"] },
    ],
    settings => { theme => "dark", language => "en" },
};

print Dumper($complex);

# --- ref() to check reference type ---
say "\n--- Checking Reference Types ---";

my @refs = ($name_ref, $colors_ref, $config_ref, $anon_array, $anon_hash, sub { 1 });
my @labels = qw(scalar_ref array_ref hash_ref anon_array anon_hash code_ref);

for my $i (0 .. $#refs) {
    printf "  %-12s => %s\n", $labels[$i], ref($refs[$i]);
}

say "\nDone!";
