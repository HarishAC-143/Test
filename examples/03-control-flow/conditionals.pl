#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Conditional Statements
# ============================================================

say "=== IF / ELSIF / ELSE ===";

my $temperature = 72;

if ($temperature > 90) {
    say "It's hot!";
} elsif ($temperature > 70) {
    say "It's warm and pleasant.";
} elsif ($temperature > 50) {
    say "It's cool.";
} else {
    say "It's cold!";
}

say "\n=== UNLESS ===";

my $age = 20;

unless ($age >= 21) {
    say "You cannot purchase alcohol (age $age).";
}

unless ($age < 18) {
    say "You can vote (age $age).";
}

say "\n=== POSTFIX CONDITIONALS ===";

my $score = 95;
say "Excellent!" if $score >= 90;
say "Needs improvement" if $score < 60;
say "Passed!" unless $score < 60;

say "\n=== TERNARY OPERATOR ===";

my $status = ($score >= 60) ? "PASS" : "FAIL";
say "Status: $status";

my $label = ($score >= 90) ? "A" :
            ($score >= 80) ? "B" :
            ($score >= 70) ? "C" :
            ($score >= 60) ? "D" : "F";
say "Grade: $label";

say "\n=== LOGICAL OPERATORS AS CONTROL FLOW ===";

my $username = "admin";
my $is_valid = ($username eq "admin") && say("Username is valid");

my $value = undef;
my $display = $value // "N/A";
say "Value: $display";

$value = 0;
$display = $value || "fallback";
say "With || (0 is falsy): $display";

$display = $value // "fallback";
say "With // (0 is defined): $display";

say "\n=== TRUTH AND FALSITY IN PERL ===";

my @false_values = (0, "", "0", undef);
my @true_values  = (1, "hello", " ", "00", -1, 0.1);

say "False values:";
for my $val (@false_values) {
    my $label = defined($val) ? qq{"$val"} : "undef";
    printf "  %-10s => %s\n", $label, $val ? "true" : "false";
}

say "\nTrue values:";
for my $val (@true_values) {
    my $label = qq{"$val"};
    printf "  %-10s => %s\n", $label, $val ? "true" : "false";
}

say "\n=== CHAINED COMPARISONS ===";

my $x = 15;
if ($x > 10 && $x < 20) {
    say "$x is between 10 and 20";
}

my @allowed = qw(admin moderator editor);
my $role = "moderator";
if (grep { $_ eq $role } @allowed) {
    say "Role '$role' is authorized";
}

say "\n--- Conditionals demo complete ---";
