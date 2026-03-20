#!/usr/bin/perl
# 08_oop.pl — Object-Oriented Programming in Perl
use strict;
use warnings;
use feature 'say';

say "=" x 50;
say "  Perl Object-Oriented Programming Demo";
say "=" x 50;

# =========================================
# Class: BankAccount
# =========================================
{
    package BankAccount;

    sub new {
        my ($class, %args) = @_;
        my $self = {
            owner   => $args{owner}   // "Anonymous",
            balance => $args{balance} // 0,
            _history => [],
        };
        bless $self, $class;
        $self->_log("Account opened with balance \$$self->{balance}");
        return $self;
    }

    sub owner   { return $_[0]->{owner} }
    sub balance { return $_[0]->{balance} }

    sub deposit {
        my ($self, $amount) = @_;
        die "Deposit amount must be positive\n" if $amount <= 0;
        $self->{balance} += $amount;
        $self->_log("Deposited \$$amount");
        return $self;
    }

    sub withdraw {
        my ($self, $amount) = @_;
        die "Withdrawal amount must be positive\n" if $amount <= 0;
        die "Insufficient funds\n" if $amount > $self->{balance};
        $self->{balance} -= $amount;
        $self->_log("Withdrew \$$amount");
        return $self;
    }

    sub statement {
        my ($self) = @_;
        my $stmt = sprintf("Account: %s | Balance: \$%.2f\n", $self->{owner}, $self->{balance});
        $stmt .= "Transaction History:\n";
        for my $entry (@{$self->{_history}}) {
            $stmt .= "  - $entry\n";
        }
        return $stmt;
    }

    sub _log {
        my ($self, $message) = @_;
        push @{$self->{_history}}, $message;
    }
}

# =========================================
# Class: SavingsAccount (inherits BankAccount)
# =========================================
{
    package SavingsAccount;
    our @ISA = ('BankAccount');

    sub new {
        my ($class, %args) = @_;
        my $self = $class->SUPER::new(%args);
        $self->{interest_rate} = $args{interest_rate} // 0.02;
        return $self;
    }

    sub interest_rate { return $_[0]->{interest_rate} }

    sub apply_interest {
        my ($self) = @_;
        my $interest = $self->{balance} * $self->{interest_rate};
        $self->{balance} += $interest;
        $self->_log(sprintf("Interest applied: \$%.2f (rate: %.1f%%)",
            $interest, $self->{interest_rate} * 100));
        return $self;
    }
}

# =========================================
# Class: Shape (base class)
# =========================================
{
    package Shape;

    sub new {
        my ($class, %args) = @_;
        return bless { color => $args{color} // "black" }, $class;
    }

    sub color { return $_[0]->{color} }
    sub area  { die ref($_[0]) . " must implement area()\n" }
    sub describe {
        my ($self) = @_;
        return sprintf("%s [%s]: area = %.2f", ref($self), $self->color, $self->area);
    }
}

# =========================================
# Class: Circle
# =========================================
{
    package Circle;
    our @ISA = ('Shape');

    sub new {
        my ($class, %args) = @_;
        my $self = $class->SUPER::new(%args);
        $self->{radius} = $args{radius} // 1;
        return $self;
    }

    sub radius { return $_[0]->{radius} }
    sub area   { return 3.14159265 * $_[0]->{radius} ** 2 }
    sub circumference { return 2 * 3.14159265 * $_[0]->{radius} }
}

# =========================================
# Class: Rectangle
# =========================================
{
    package Rectangle;
    our @ISA = ('Shape');

    sub new {
        my ($class, %args) = @_;
        my $self = $class->SUPER::new(%args);
        $self->{width}  = $args{width}  // 1;
        $self->{height} = $args{height} // 1;
        return $self;
    }

    sub width  { return $_[0]->{width} }
    sub height { return $_[0]->{height} }
    sub area   { return $_[0]->{width} * $_[0]->{height} }
    sub perimeter { return 2 * ($_[0]->{width} + $_[0]->{height}) }
}

# =========================================
# Class: Square (inherits Rectangle)
# =========================================
{
    package Square;
    our @ISA = ('Rectangle');

    sub new {
        my ($class, %args) = @_;
        $args{height} = $args{side} // $args{width} // 1;
        $args{width}  = $args{height};
        return $class->SUPER::new(%args);
    }

    sub side { return $_[0]->{width} }
}

# =========================================
# Main program
# =========================================
package main;

# --- Bank Account Demo ---
say "\n--- Bank Account Demo ---";

my $account = BankAccount->new(owner => "Alice", balance => 1000);
$account->deposit(500)->deposit(250)->withdraw(200);
print $account->statement();

say "\n--- Savings Account Demo ---";

my $savings = SavingsAccount->new(
    owner         => "Bob",
    balance       => 5000,
    interest_rate => 0.05,
);
$savings->deposit(1000);
$savings->apply_interest();
print $savings->statement();

# --- Shape Hierarchy Demo ---
say "\n--- Shape Hierarchy Demo ---";

my @shapes = (
    Circle->new(radius => 5, color => "red"),
    Rectangle->new(width => 4, height => 6, color => "blue"),
    Square->new(side => 3, color => "green"),
    Circle->new(radius => 2.5, color => "yellow"),
    Rectangle->new(width => 10, height => 3, color => "purple"),
);

for my $shape (@shapes) {
    say "  " . $shape->describe();
}

# Polymorphism: sort by area
my @by_area = sort { $a->area <=> $b->area } @shapes;
say "\nSorted by area:";
for my $shape (@by_area) {
    printf "  %-10s area = %.2f\n", ref($shape), $shape->area;
}

# Type checking with isa
say "\n--- Type Checking ---";
for my $shape (@shapes) {
    my @types;
    push @types, "Shape"     if $shape->isa("Shape");
    push @types, "Rectangle" if $shape->isa("Rectangle");
    push @types, "Square"    if $shape->isa("Square");
    push @types, "Circle"    if $shape->isa("Circle");
    printf "  %-10s isa: %s\n", ref($shape), join(", ", @types);
}

# Circle-specific methods
say "\n--- Circle Details ---";
my $circle = $shapes[0];
printf "  Radius: %.1f\n", $circle->radius;
printf "  Area: %.2f\n", $circle->area;
printf "  Circumference: %.2f\n", $circle->circumference;

say "\nDone!";
