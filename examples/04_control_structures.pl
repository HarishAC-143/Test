#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

say "=== IF / ELSIF / ELSE ===";

my $temperature = 28;

if ($temperature > 35) {
    say "It's very hot! ($temperature°C)";
} elsif ($temperature > 25) {
    say "It's warm. ($temperature°C)";
} elsif ($temperature > 15) {
    say "It's mild. ($temperature°C)";
} elsif ($temperature > 5) {
    say "It's cool. ($temperature°C)";
} else {
    say "It's cold! ($temperature°C)";
}

say "\n=== UNLESS ===";

my $error = 0;

unless ($error) {
    say "No errors detected.";
}

# Equivalent to: if (!$error) { ... }

say "\n=== POSTFIX CONDITIONALS ===";

my $age = 21;
my $logged_in = 1;

say "Welcome, user!" if $logged_in;
say "Access denied." unless $logged_in;
say "You can vote."  if $age >= 18;

say "\n=== TERNARY OPERATOR ===";

my $hour = 14;
my $greeting = ($hour < 12)  ? "Good morning" :
               ($hour < 17)  ? "Good afternoon" :
               ($hour < 21)  ? "Good evening" :
                               "Good night";
say "$greeting! (Hour: $hour)";

say "\n=== TRUTHINESS IN PERL ===";

my @falsy_values = (0, "", "0", undef);
my @truthy_values = (1, "hello", "00", " ", -1, 0.1);

say "Falsy values:";
for my $val (@falsy_values) {
    my $display = defined($val) ? "'$val'" : "undef";
    say "  $display is " . ($val ? "truthy" : "falsy");
}

say "\nTruthy values:";
for my $val (@truthy_values) {
    my $display = defined($val) ? "'$val'" : "undef";
    say "  $display is " . ($val ? "truthy" : "falsy");
}

say "\n=== CHAINED CONDITIONS ===";

my $user_role = "editor";
my $is_active = 1;

if ($user_role eq "admin" && $is_active) {
    say "Full access granted.";
} elsif ($user_role eq "editor" && $is_active) {
    say "Edit access granted.";
} elsif ($user_role eq "viewer") {
    say "Read-only access.";
} else {
    say "No access.";
}

say "\n=== UNLESS WITH ELSE ===";

my $file_exists = 0;

unless ($file_exists) {
    say "File not found, creating new file...";
} else {
    say "File found, opening...";
}
