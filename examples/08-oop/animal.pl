#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Object-Oriented Perl — Basic Classes
# ============================================================

# --- Define the Animal class inline ---
{
    package Animal;

    sub new {
        my ($class, %args) = @_;
        my $self = {
            name  => $args{name}  // "Unknown",
            sound => $args{sound} // "...",
            legs  => $args{legs}  // 4,
            type  => $args{type}  // "mammal",
        };
        return bless $self, $class;
    }

    sub name  { return $_[0]->{name} }
    sub sound { return $_[0]->{sound} }
    sub legs  { return $_[0]->{legs} }
    sub type  { return $_[0]->{type} }

    sub speak {
        my ($self) = @_;
        printf "%s says '%s'!\n", $self->name(), $self->sound();
    }

    sub describe {
        my ($self) = @_;
        printf "%s is a %s with %d legs.\n",
            $self->name(), $self->type(), $self->legs();
    }

    sub to_string {
        my ($self) = @_;
        return sprintf("Animal{name=%s, type=%s, sound=%s, legs=%d}",
            $self->name(), $self->type(), $self->sound(), $self->legs());
    }
}

# --- Define a BankAccount class ---
{
    package BankAccount;

    sub new {
        my ($class, %args) = @_;
        my $self = {
            owner   => $args{owner}   // "Unknown",
            balance => $args{balance} // 0,
            _transactions => [],
        };
        bless $self, $class;
        $self->_record("Account opened with balance \$$self->{balance}");
        return $self;
    }

    sub owner   { return $_[0]->{owner} }
    sub balance { return $_[0]->{balance} }

    sub deposit {
        my ($self, $amount) = @_;
        die "Deposit amount must be positive\n" unless $amount > 0;
        $self->{balance} += $amount;
        $self->_record("Deposited \$$amount");
        return $self;  # Enable method chaining
    }

    sub withdraw {
        my ($self, $amount) = @_;
        die "Withdrawal amount must be positive\n" unless $amount > 0;
        die "Insufficient funds\n" if $amount > $self->{balance};
        $self->{balance} -= $amount;
        $self->_record("Withdrew \$$amount");
        return $self;
    }

    sub statement {
        my ($self) = @_;
        printf "\n--- Statement for %s ---\n", $self->owner();
        for my $tx (@{$self->{_transactions}}) {
            printf "  %s\n", $tx;
        }
        printf "  Current balance: \$%.2f\n", $self->balance();
        print "---\n";
    }

    sub _record {
        my ($self, $msg) = @_;
        push @{$self->{_transactions}}, $msg;
    }
}

# --- Main program ---
package main;

say "=== ANIMAL CLASS ===";

my $dog = Animal->new(name => "Rex",      sound => "Woof", type => "mammal");
my $cat = Animal->new(name => "Whiskers", sound => "Meow");
my $bird = Animal->new(name => "Tweety",  sound => "Tweet", legs => 2, type => "bird");
my $fish = Animal->new(name => "Nemo",    sound => "Blub",  legs => 0, type => "fish");

my @zoo = ($dog, $cat, $bird, $fish);

for my $animal (@zoo) {
    $animal->speak();
    $animal->describe();
    say "  -> " . $animal->to_string();
    say "";
}

say "Object class: " . ref($dog);
say "Is an Animal? " . ($dog->isa("Animal") ? "Yes" : "No");

say "\n=== BANK ACCOUNT CLASS ===";

my $account = BankAccount->new(owner => "Alice", balance => 1000);

$account->deposit(500)
        ->deposit(250)
        ->withdraw(100);

$account->statement();

eval { $account->withdraw(5000) };
if ($@) {
    say "Error: $@";
}

eval { $account->deposit(-50) };
if ($@) {
    say "Error: $@";
}

say "--- OOP basics demo complete ---";
