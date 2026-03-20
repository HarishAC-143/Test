#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';
use Data::Dumper;

# ============================================================
# References — Perl's Pointers
# ============================================================

say "=== SCALAR REFERENCES ===";

my $name = "Alice";
my $ref = \$name;

say "Value:     $name";
say "Reference: $ref";
say "Deref:     $$ref";
say "Deref:     ${$ref}";

$$ref = "Bob";
say "After modifying through ref: $name";

say "\n=== ARRAY REFERENCES ===";

my @colors = ("red", "green", "blue");
my $aref = \@colors;

say "Array:     @colors";
say "Reference: $aref";
say "Element 0: $aref->[0]";
say "Element 1: $$aref[1]";
say "Element 2: ${$aref}[2]";
say "Length:    " . scalar @$aref;

push @$aref, "yellow";
say "After push: @colors";

say "\nAnonymous array ref:";
my $anon_arr = [10, 20, 30, 40, 50];
say "Element 2: $anon_arr->[2]";
say "Slice:     @{$anon_arr}[1..3]";

say "\n=== HASH REFERENCES ===";

my %person = (name => "Alice", age => 30, city => "NYC");
my $href = \%person;

say "Name:  $href->{name}";
say "Age:   $$href{age}";
say "City:  ${$href}{city}";

$href->{email} = 'alice@example.com';
say "Keys: " . join(", ", sort keys %$href);

say "\nAnonymous hash ref:";
my $config = {
    host    => "localhost",
    port    => 8080,
    debug   => 1,
};

for my $key (sort keys %$config) {
    say "  $key: $config->{$key}";
}

say "\n=== CODE REFERENCES ===";

my $greet = sub {
    my ($name) = @_;
    return "Hello, $name!";
};

say $greet->("World");
say $greet->("Perl");

sub make_validator {
    my ($min, $max) = @_;
    return sub {
        my ($value) = @_;
        return ($value >= $min && $value <= $max);
    };
}

my $valid_age = make_validator(0, 150);
my $valid_score = make_validator(0, 100);

say "Age 25 valid?   " . ($valid_age->(25) ? "yes" : "no");
say "Age 200 valid?  " . ($valid_age->(200) ? "yes" : "no");
say "Score 85 valid? " . ($valid_score->(85) ? "yes" : "no");

say "\n=== REF() FUNCTION ===";

my $sref = \42;
my $ar   = [1, 2, 3];
my $hr   = {a => 1};
my $cr   = sub { 1 };
my $not_a_ref = 42;

printf "%-10s => %s\n", 'scalar ref', ref($sref);
printf "%-10s => %s\n", 'array ref',  ref($ar);
printf "%-10s => %s\n", 'hash ref',   ref($hr);
printf "%-10s => %s\n", 'code ref',   ref($cr);
printf "%-10s => %s\n", 'plain val',  ref(\$not_a_ref);

say "\n=== NESTED DEREFERENCING ===";

my $data = {
    users => [
        { name => "Alice", scores => [90, 85, 92] },
        { name => "Bob",   scores => [78, 88, 95] },
    ],
    metadata => {
        version => "1.0",
        count   => 2,
    },
};

say "First user:  $data->{users}[0]{name}";
say "Bob's score: $data->{users}[1]{scores}[2]";
say "Version:     $data->{metadata}{version}";

say "\nAll users and average scores:";
for my $user (@{$data->{users}}) {
    my @scores = @{$user->{scores}};
    my $avg = 0;
    $avg += $_ for @scores;
    $avg /= scalar @scores;
    printf "  %s: avg = %.1f (scores: %s)\n",
        $user->{name}, $avg, join(", ", @scores);
}

say "\n=== DATA::DUMPER FOR DEBUGGING ===";

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent = 1;
print Dumper($data);

say "\n--- References demo complete ---";
