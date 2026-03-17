#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

say "=== SCALAR REFERENCES ===";

my $name = "Alice";
my $ref = \$name;

say "Value:     $name";
say "Reference: $ref";
say "Deref:     $$ref";
say "Type:      " . ref($ref);

$$ref = "Bob";
say "After modifying via ref: $name";

say "\n=== ARRAY REFERENCES ===";

my @colors = ("red", "green", "blue");
my $aref = \@colors;

say "Array ref: $aref";
say "Deref [0]: $$aref[0]";
say "Arrow [1]: $aref->[1]";
say "All:       @$aref";
say "Length:    " . scalar @$aref;

my $anon_aref = ["cyan", "magenta", "yellow"];
say "Anonymous: $anon_aref->[0], $anon_aref->[1], $anon_aref->[2]";

say "\n=== HASH REFERENCES ===";

my %person = (name => "Carol", age => 28, city => "NYC");
my $href = \%person;

say "Hash ref:   $href";
say "Deref name: $$href{name}";
say "Arrow city: $href->{city}";

my $anon_href = { language => "Perl", version => 5 };
say "Anonymous:  $anon_href->{language} $anon_href->{version}";

say "\nIterating hash ref:";
for my $key (sort keys %$href) {
    say "  $key => $href->{$key}";
}

say "\n=== SUBROUTINE REFERENCES ===";

my $greet = sub {
    my ($name) = @_;
    return "Hello, $name!";
};

say $greet->("Dave");
say "Type: " . ref($greet);

sub make_multiplier {
    my ($factor) = @_;
    return sub { return $_[0] * $factor; };
}

my $double = make_multiplier(2);
my $triple = make_multiplier(3);

say "Double 5: " . $double->(5);
say "Triple 5: " . $triple->(5);

say "\n=== NESTED DATA STRUCTURES ===";

my $school = {
    name    => "Springfield Elementary",
    address => {
        street => "123 Education Lane",
        city   => "Springfield",
        state  => "IL",
    },
    classes => [
        {
            name     => "Math 101",
            teacher  => "Ms. Johnson",
            students => ["Alice", "Bob", "Carol"],
        },
        {
            name     => "Science 201",
            teacher  => "Mr. Smith",
            students => ["Dave", "Eve", "Frank", "Grace"],
        },
        {
            name     => "English 101",
            teacher  => "Mrs. Williams",
            students => ["Alice", "Frank", "Heidi"],
        },
    ],
};

say "School: $school->{name}";
say "City:   $school->{address}{city}";
say "";

for my $class (@{$school->{classes}}) {
    my $count = scalar @{$class->{students}};
    printf "  %-15s taught by %-15s (%d students: %s)\n",
           $class->{name},
           $class->{teacher},
           $count,
           join(", ", @{$class->{students}});
}

say "\n=== ARRAY OF HASH REFS (common pattern) ===";

my @employees = (
    { name => "Alice",   dept => "Engineering", salary => 95000 },
    { name => "Bob",     dept => "Marketing",   salary => 72000 },
    { name => "Carol",   dept => "Engineering", salary => 105000 },
    { name => "Dave",    dept => "Marketing",   salary => 68000 },
    { name => "Eve",     dept => "Engineering", salary => 88000 },
);

say "All employees:";
printf "  %-10s %-15s %10s\n", "Name", "Department", "Salary";
printf "  %-10s %-15s %10s\n", "-" x 10, "-" x 15, "-" x 10;
for my $emp (sort { $b->{salary} <=> $a->{salary} } @employees) {
    printf "  %-10s %-15s \$%9s\n", $emp->{name}, $emp->{dept},
           commify($emp->{salary});
}

my %by_dept;
for my $emp (@employees) {
    push @{$by_dept{$emp->{dept}}}, $emp;
}

say "\nGrouped by department:";
for my $dept (sort keys %by_dept) {
    my @dept_emps = @{$by_dept{$dept}};
    my $total = 0;
    $total += $_->{salary} for @dept_emps;
    my $avg = $total / scalar @dept_emps;
    printf "  %s (%d employees, avg salary: \$%.0f)\n",
           $dept, scalar @dept_emps, $avg;
    for my $emp (@dept_emps) {
        printf "    - %s (\$%s)\n", $emp->{name}, commify($emp->{salary});
    }
}

say "\n=== REF() — TYPE CHECKING ===";

my @refs = (\42, \@colors, \%person, $greet, \*STDOUT);
my @names = qw(scalar_ref array_ref hash_ref code_ref glob_ref);

for my $i (0..$#refs) {
    printf "  %-12s => %s\n", $names[$i], ref($refs[$i]);
}

say "\n=== DEEP COPY WITH NESTED STRUCTURES ===";

use Storable qw(dclone);

my $original = {
    name   => "Config",
    values => [1, 2, 3],
    nested => { key => "value" },
};

my $shallow = { %$original };
my $deep    = dclone($original);

$original->{values}[0] = 999;
$original->{nested}{key} = "changed";

say "Original values[0]:  $original->{values}[0]";
say "Shallow values[0]:   $shallow->{values}[0]";
say "Deep copy values[0]: $deep->{values}[0]";

say "Original nested.key:  $original->{nested}{key}";
say "Shallow nested.key:   $shallow->{nested}{key}";
say "Deep copy nested.key: $deep->{nested}{key}";

sub commify {
    my ($n) = @_;
    my $text = reverse $n;
    $text =~ s/(\d{3})(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}
