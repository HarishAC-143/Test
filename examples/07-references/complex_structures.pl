#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Complex Data Structures
# ============================================================

say "=== ARRAY OF ARRAYS (2D MATRIX) ===";

my @matrix = (
    [1,  2,  3,  4],
    [5,  6,  7,  8],
    [9,  10, 11, 12],
);

say "Matrix:";
for my $row (@matrix) {
    printf "  [%s]\n", join(", ", map { sprintf "%2d", $_ } @$row);
}

say "\nElement at (1,2): $matrix[1][2]";
say "Row 0: @{$matrix[0]}";

my @transposed;
for my $i (0 .. $#{$matrix[0]}) {
    $transposed[$i] = [ map { $_->[$i] } @matrix ];
}

say "\nTransposed:";
for my $row (@transposed) {
    printf "  [%s]\n", join(", ", map { sprintf "%2d", $_ } @$row);
}

say "\n=== ARRAY OF HASHES ===";

my @books = (
    {
        title  => "Learning Perl",
        author => "Randal L. Schwartz",
        year   => 2011,
        pages  => 388,
    },
    {
        title  => "Programming Perl",
        author => "Larry Wall",
        year   => 2012,
        pages  => 1176,
    },
    {
        title  => "Modern Perl",
        author => "chromatic",
        year   => 2015,
        pages  => 300,
    },
    {
        title  => "Perl Cookbook",
        author => "Tom Christiansen",
        year   => 2003,
        pages  => 964,
    },
);

printf "\n%-25s %-22s %5s %6s\n", "Title", "Author", "Year", "Pages";
say "-" x 62;
for my $book (sort { $a->{year} <=> $b->{year} } @books) {
    printf "%-25s %-22s %5d %6d\n",
        $book->{title}, $book->{author}, $book->{year}, $book->{pages};
}

my $total_pages = 0;
$total_pages += $_->{pages} for @books;
say "Total pages: $total_pages";

my @long_books = grep { $_->{pages} > 500 } @books;
say "\nBooks with 500+ pages:";
say "  - $_->{title} ($_->{pages} pages)" for @long_books;

say "\n=== HASH OF ARRAYS ===";

my %class_roster = (
    "Mathematics" => ["Alice", "Bob", "Carol", "Dave"],
    "Science"     => ["Bob", "Eve", "Frank"],
    "English"     => ["Alice", "Carol", "Eve", "Grace"],
    "History"     => ["Dave", "Frank", "Grace", "Bob"],
);

say "\nClass Roster:";
for my $class (sort keys %class_roster) {
    my @students = @{$class_roster{$class}};
    printf "  %-15s (%d students): %s\n",
        $class, scalar @students, join(", ", sort @students);
}

say "\nStudents in multiple classes:";
my %student_classes;
for my $class (keys %class_roster) {
    for my $student (@{$class_roster{$class}}) {
        push @{$student_classes{$student}}, $class;
    }
}
for my $student (sort keys %student_classes) {
    my @classes = sort @{$student_classes{$student}};
    printf "  %-8s: %s (%d classes)\n",
        $student, join(", ", @classes), scalar @classes;
}

say "\n=== HASH OF HASHES ===";

my %inventory = (
    "Electronics" => {
        "Laptop"  => { price => 999, stock => 15 },
        "Phone"   => { price => 699, stock => 42 },
        "Tablet"  => { price => 449, stock => 28 },
    },
    "Books" => {
        "Fiction"     => { price => 15, stock => 200 },
        "Non-Fiction" => { price => 20, stock => 150 },
        "Technical"   => { price => 45, stock => 75 },
    },
    "Clothing" => {
        "T-Shirt" => { price => 25, stock => 300 },
        "Jacket"  => { price => 89, stock => 50 },
    },
);

say "\nInventory Report:";
say "=" x 55;

my $grand_total = 0;
for my $category (sort keys %inventory) {
    say "\n  $category:";
    my $cat_total = 0;
    for my $item (sort keys %{$inventory{$category}}) {
        my $info = $inventory{$category}{$item};
        my $value = $info->{price} * $info->{stock};
        $cat_total += $value;
        printf "    %-15s \$%5d x %3d = \$%8d\n",
            $item, $info->{price}, $info->{stock}, $value;
    }
    printf "    %s\n    Category total: \$%d\n", "-" x 40, $cat_total;
    $grand_total += $cat_total;
}
say "\n  Grand total: \$$grand_total";

say "\n=== COMPLEX NESTED STRUCTURE ===";

my $company = {
    name => "TechCorp",
    founded => 2010,
    departments => [
        {
            name => "Engineering",
            manager => { name => "Alice", email => "alice\@tech.com" },
            employees => [
                { name => "Bob",   role => "Senior Dev",  salary => 120000 },
                { name => "Carol", role => "Junior Dev",  salary => 75000 },
                { name => "Dave",  role => "DevOps",      salary => 110000 },
            ],
        },
        {
            name => "Marketing",
            manager => { name => "Eve", email => "eve\@tech.com" },
            employees => [
                { name => "Frank", role => "Content Lead", salary => 85000 },
                { name => "Grace", role => "SEO Analyst",  salary => 72000 },
            ],
        },
    ],
};

say "\nCompany: $company->{name} (founded $company->{founded})";
for my $dept (@{$company->{departments}}) {
    say "\n  Department: $dept->{name}";
    say "  Manager:    $dept->{manager}{name} ($dept->{manager}{email})";
    say "  Team:";
    my $dept_total = 0;
    for my $emp (@{$dept->{employees}}) {
        printf "    - %-10s %-15s \$%d\n",
            $emp->{name}, $emp->{role}, $emp->{salary};
        $dept_total += $emp->{salary};
    }
    printf "    Department salary total: \$%d\n", $dept_total;
}

say "\n--- Complex structures demo complete ---";
