#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Array Variables (@) — Ordered Lists
# ============================================================

say "=== CREATING ARRAYS ===";

my @fruits   = ("apple", "banana", "cherry", "date", "elderberry");
my @numbers  = (1, 2, 3, 4, 5);
my @mixed    = ("hello", 42, 3.14, undef);
my @range    = (1..10);
my @letters  = ('a'..'z');
my @words    = qw(these are individual words);  # Quote words

say "Fruits:  @fruits";
say "Numbers: @numbers";
say "Range:   @range";
say "Words:   @words";

say "\n=== ACCESSING ELEMENTS ===";

say "First fruit:  $fruits[0]";
say "Third fruit:  $fruits[2]";
say "Last fruit:   $fruits[-1]";
say "Second last:  $fruits[-2]";

say "\n=== ARRAY INFORMATION ===";

my $length     = scalar @fruits;
my $last_index = $#fruits;
say "Array length: $length";
say "Last index:   $last_index";

say "\n=== ARRAY SLICES ===";

my @first_three = @fruits[0..2];
my @picked      = @fruits[0, 2, 4];
say "First three: @first_three";
say "Picked:      @picked";

say "\n=== MODIFYING ARRAYS ===";

my @stack = (1, 2, 3);

push @stack, 4, 5;
say "After push 4,5:    @stack";

my $popped = pop @stack;
say "After pop (got $popped): @stack";

unshift @stack, 0;
say "After unshift 0:   @stack";

my $shifted = shift @stack;
say "After shift (got $shifted): @stack";

say "\n=== SPLICE ===";

my @data = ('a', 'b', 'c', 'd', 'e');
say "Original:  @data";

my @removed = splice(@data, 1, 2);
say "Removed:   @removed";
say "After splice(1,2): @data";

splice(@data, 1, 0, 'X', 'Y');
say "After insert X,Y at 1: @data";

say "\n=== SORTING ===";

my @unsorted = (42, 7, 13, 1, 99, 23);
my @alpha_sort = sort @unsorted;                    # String sort (default)
my @num_sort   = sort { $a <=> $b } @unsorted;     # Numeric ascending
my @desc_sort  = sort { $b <=> $a } @unsorted;     # Numeric descending

say "Original:          @unsorted";
say "Alphabetic sort:   @alpha_sort";
say "Numeric ascending: @num_sort";
say "Numeric descending:@desc_sort";

my @names = ("charlie", "Alice", "Bob", "alice", "bob");
my @ci_sort = sort { lc($a) cmp lc($b) } @names;
say "Case-insensitive:  @ci_sort";

say "\n=== MAP AND GREP ===";

my @nums = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);

my @doubled = map { $_ * 2 } @nums;
say "Doubled: @doubled";

my @evens = grep { $_ % 2 == 0 } @nums;
say "Evens:   @evens";

my @big_evens = grep { $_ > 5 } grep { $_ % 2 == 0 } @nums;
say "Evens>5: @big_evens";

say "\n=== JOIN AND SPLIT ===";

my $csv = join(",", @fruits);
say "Joined:  $csv";

my @parts = split(/,/, "one,two,three,four");
say "Split:   @parts";

say "\n=== ITERATING ===";

say "--- foreach ---";
foreach my $fruit (@fruits) {
    say "  Fruit: $fruit";
}

say "--- for with index ---";
for my $i (0 .. $#fruits) {
    say "  [$i] $fruits[$i]";
}

say "\n--- Postfix for ---";
print "  $_  " for @numbers;
say "";

say "\n--- Program complete ---";
