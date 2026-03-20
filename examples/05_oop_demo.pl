#!/usr/bin/perl
# Demonstrates object-oriented programming in Perl.

use strict;
use warnings;

# ─── Class: BankAccount ─────────────────────────────────────────────

package BankAccount;

my $next_account_number = 1000;

sub new {
    my ($class, %args) = @_;
    my $self = bless {
        account_number => $next_account_number++,
        owner          => $args{owner}   // "Unknown",
        balance        => $args{balance} // 0,
        transactions   => [],
    }, $class;
    $self->_record("Account opened with balance \$$self->{balance}");
    return $self;
}

sub owner          { $_[0]->{owner} }
sub balance        { $_[0]->{balance} }
sub account_number { $_[0]->{account_number} }

sub deposit {
    my ($self, $amount) = @_;
    die "Deposit amount must be positive\n" unless $amount > 0;
    $self->{balance} += $amount;
    $self->_record(sprintf("Deposit: +\$%.2f (balance: \$%.2f)", $amount, $self->{balance}));
    return $self;
}

sub withdraw {
    my ($self, $amount) = @_;
    die "Withdrawal amount must be positive\n" unless $amount > 0;
    die "Insufficient funds (balance: \$$self->{balance})\n" if $amount > $self->{balance};
    $self->{balance} -= $amount;
    $self->_record(sprintf("Withdrawal: -\$%.2f (balance: \$%.2f)", $amount, $self->{balance}));
    return $self;
}

sub transfer {
    my ($self, $target, $amount) = @_;
    $self->withdraw($amount);
    $target->deposit($amount);
    $self->_record(sprintf("Transfer to #%d: -\$%.2f", $target->account_number, $amount));
    $target->_record(sprintf("Transfer from #%d: +\$%.2f", $self->account_number, $amount));
    return $self;
}

sub statement {
    my ($self) = @_;
    my $output = sprintf("\n=== Account #%d (%s) ===\n", $self->{account_number}, $self->{owner});
    for my $t (@{$self->{transactions}}) {
        $output .= sprintf("  [%s] %s\n", $t->{time}, $t->{description});
    }
    $output .= sprintf("  Current Balance: \$%.2f\n", $self->{balance});
    return $output;
}

sub _record {
    my ($self, $desc) = @_;
    push @{$self->{transactions}}, {
        time        => _timestamp(),
        description => $desc,
    };
}

sub _timestamp {
    my @t = localtime;
    return sprintf("%02d:%02d:%02d", $t[2], $t[1], $t[0]);
}

# ─── Class: SavingsAccount (inherits from BankAccount) ──────────────

package SavingsAccount;
use parent -norequire, 'BankAccount';

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{interest_rate} = $args{interest_rate} // 0.02;
    return $self;
}

sub interest_rate { $_[0]->{interest_rate} }

sub apply_interest {
    my ($self) = @_;
    my $interest = $self->{balance} * $self->{interest_rate};
    $self->{balance} += $interest;
    $self->_record(sprintf("Interest (%.1f%%): +\$%.2f",
                           $self->{interest_rate} * 100, $interest));
    return $self;
}

sub withdraw {
    my ($self, $amount) = @_;
    my $min_balance = 100;
    die "Savings accounts require a minimum balance of \$$min_balance\n"
        if ($self->{balance} - $amount) < $min_balance;
    return $self->SUPER::withdraw($amount);
}

# ─── Main Program ──────────────────────────────────────────────────

package main;

print "=== Bank Account Demo ===\n";

my $checking = BankAccount->new(owner => "Alice", balance => 1000);
my $savings  = SavingsAccount->new(owner => "Alice", balance => 5000, interest_rate => 0.03);
my $bob      = BankAccount->new(owner => "Bob", balance => 500);

$checking->deposit(500);
$checking->withdraw(200);
$checking->transfer($bob, 300);

$savings->apply_interest();
$savings->deposit(1000);

eval {
    $savings->withdraw(5800);
};
if ($@) {
    print "Error: $@";
}

eval {
    $checking->withdraw(99999);
};
if ($@) {
    print "Error: $@";
}

print $checking->statement();
print $savings->statement();
print $bob->statement();

printf "\nAll Balances:\n";
for my $acct ($checking, $savings, $bob) {
    printf "  #%d %-10s \$%.2f%s\n",
           $acct->account_number,
           $acct->owner,
           $acct->balance,
           $acct->isa("SavingsAccount") ? " (savings)" : "";
}
