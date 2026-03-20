#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# --- Object-Oriented Programming ---

# =============================================
# Class: Animal (base class)
# =============================================
package Animal;

sub new {
    my ($class, %args) = @_;
    my $self = {
        name  => $args{name}  // "Unknown",
        sound => $args{sound} // "...",
        legs  => $args{legs}  // 4,
    };
    return bless $self, $class;
}

sub name  { return $_[0]->{name} }
sub sound { return $_[0]->{sound} }
sub legs  { return $_[0]->{legs} }

sub speak {
    my ($self) = @_;
    printf "%s the %s says '%s'!\n", $self->name(), ref($self), $self->sound();
}

sub describe {
    my ($self) = @_;
    printf "%s has %d legs.\n", $self->name(), $self->legs();
}

# =============================================
# Class: Dog (inherits from Animal)
# =============================================
package Dog;
our @ISA = ('Animal');

sub new {
    my ($class, %args) = @_;
    $args{sound} //= "Woof";
    my $self = $class->SUPER::new(%args);
    $self->{tricks} = $args{tricks} // [];
    return $self;
}

sub learn_trick {
    my ($self, $trick) = @_;
    push @{$self->{tricks}}, $trick;
    say "${\$self->name()} learned '$trick'!";
}

sub show_tricks {
    my ($self) = @_;
    my @tricks = @{$self->{tricks}};
    if (@tricks) {
        say $self->name() . "'s tricks: " . join(", ", @tricks);
    } else {
        say $self->name() . " doesn't know any tricks yet.";
    }
}

# =============================================
# Class: Cat (inherits from Animal)
# =============================================
package Cat;
our @ISA = ('Animal');

sub new {
    my ($class, %args) = @_;
    $args{sound} //= "Meow";
    my $self = $class->SUPER::new(%args);
    $self->{indoor} = $args{indoor} // 1;
    return $self;
}

sub is_indoor {
    my ($self) = @_;
    return $self->{indoor} ? "indoor" : "outdoor";
}

sub describe {
    my ($self) = @_;
    $self->SUPER::describe();
    printf "%s is an %s cat.\n", $self->name(), $self->is_indoor();
}

# =============================================
# Class: BankAccount (encapsulation example)
# =============================================
package BankAccount;

sub new {
    my ($class, %args) = @_;
    my $self = {
        owner   => $args{owner}   // "Unknown",
        balance => $args{balance} // 0,
        _history => [],
    };
    return bless $self, $class;
}

sub owner   { return $_[0]->{owner} }
sub balance { return $_[0]->{balance} }

sub deposit {
    my ($self, $amount) = @_;
    die "Deposit amount must be positive\n" if $amount <= 0;
    $self->{balance} += $amount;
    push @{$self->{_history}}, "+$amount";
    return $self;
}

sub withdraw {
    my ($self, $amount) = @_;
    die "Withdrawal amount must be positive\n" if $amount <= 0;
    die "Insufficient funds\n" if $amount > $self->{balance};
    $self->{balance} -= $amount;
    push @{$self->{_history}}, "-$amount";
    return $self;
}

sub statement {
    my ($self) = @_;
    say "Account: " . $self->owner();
    say "Balance: \$" . sprintf("%.2f", $self->balance());
    if (@{$self->{_history}}) {
        say "History: " . join(", ", @{$self->{_history}});
    }
}

# =============================================
# Class: Shape hierarchy (polymorphism)
# =============================================
package Shape;

sub new {
    my ($class, %args) = @_;
    return bless { color => $args{color} // "black" }, $class;
}

sub color { return $_[0]->{color} }
sub area  { die ref($_[0]) . " must implement area()\n" }

sub describe {
    my ($self) = @_;
    printf "%s (color: %s, area: %.2f)\n", ref($self), $self->color(), $self->area();
}

package Circle;
our @ISA = ('Shape');

use POSIX qw(M_PI);

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{radius} = $args{radius} // 1;
    return $self;
}

sub radius { return $_[0]->{radius} }
sub area   { return M_PI * $_[0]->{radius} ** 2 }

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

package Triangle;
our @ISA = ('Shape');

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{base}   = $args{base}   // 1;
    $self->{height} = $args{height} // 1;
    return $self;
}

sub area { return 0.5 * $_[0]->{base} * $_[0]->{height} }

# =============================================
# Main program
# =============================================
package main;

say "=== ANIMAL HIERARCHY ===\n";

my $dog = Dog->new(name => "Rex");
$dog->speak();
$dog->describe();
$dog->learn_trick("sit");
$dog->learn_trick("shake");
$dog->learn_trick("roll over");
$dog->show_tricks();

say "";

my $cat = Cat->new(name => "Whiskers", indoor => 0);
$cat->speak();
$cat->describe();

say "\n=== BANK ACCOUNT ===\n";

my $account = BankAccount->new(owner => "Alice", balance => 1000);
$account->deposit(500)->deposit(250)->withdraw(100);
$account->statement();

eval {
    $account->withdraw(5000);
};
say "Error: $@" if $@;

say "\n=== SHAPE POLYMORPHISM ===\n";

my @shapes = (
    Circle->new(radius => 5, color => "red"),
    Rectangle->new(width => 4, height => 6, color => "blue"),
    Triangle->new(base => 3, height => 8, color => "green"),
    Circle->new(radius => 2.5, color => "yellow"),
    Rectangle->new(width => 10, height => 10, color => "purple"),
);

for my $shape (@shapes) {
    $shape->describe();
}

my $total_area = 0;
$total_area += $_->area() for @shapes;
printf "\nTotal area of all shapes: %.2f\n", $total_area;

my @sorted = sort { $b->area() <=> $a->area() } @shapes;
say "\nShapes sorted by area (descending):";
for my $s (@sorted) {
    printf "  %-12s area = %.2f\n", ref($s), $s->area();
}

say "\nDone!";
