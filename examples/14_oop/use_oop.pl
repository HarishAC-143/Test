#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';
use File::Basename;

use lib dirname(__FILE__);

use Animal;
use Dog;
use Cat;

say "=== CREATING OBJECTS ===";

my $generic = Animal->new(name => "Mystery", sound => "???", legs => 6);
$generic->speak();
$generic->describe();

say "\n=== DOG CLASS (inherits from Animal) ===";

my $rex = Dog->new(name => "Rex", breed => "German Shepherd");
$rex->speak();
$rex->describe();

$rex->learn_trick("sit");
$rex->learn_trick("shake");
$rex->learn_trick("roll over");
$rex->show_tricks();

say "\n=== CAT CLASS (inherits from Animal) ===";

my $whiskers = Cat->new(name => "Whiskers", indoor => 1);
$whiskers->speak();
$whiskers->describe();
$whiskers->purr();

say "\n=== POLYMORPHISM ===";

my @animals = (
    Animal->new(name => "Parrot", sound => "Squawk", legs => 2),
    Dog->new(name => "Buddy", breed => "Golden Retriever"),
    Cat->new(name => "Luna", indoor => 0),
    Dog->new(name => "Max", breed => "Poodle"),
    Cat->new(name => "Milo"),
);

say "All animals speak:";
for my $animal (@animals) {
    print "  ";
    $animal->speak();
}

say "\nType checking with ref():";
for my $animal (@animals) {
    printf "  %-10s is a %s\n", $animal->name(), ref($animal);
}

say "\nType checking with isa():";
for my $animal (@animals) {
    my @types;
    push @types, "Animal" if $animal->isa('Animal');
    push @types, "Dog"    if $animal->isa('Dog');
    push @types, "Cat"    if $animal->isa('Cat');
    printf "  %-10s isa: %s\n", $animal->name(), join(", ", @types);
}

say "\n=== ACCESSOR PATTERN ===";

{
    package Person;

    sub new {
        my ($class, %args) = @_;
        return bless {
            _name  => $args{name}  // "Unknown",
            _age   => $args{age}   // 0,
            _email => $args{email} // "",
        }, $class;
    }

    # Read-write accessor
    sub name {
        my ($self, $new_name) = @_;
        $self->{_name} = $new_name if defined $new_name;
        return $self->{_name};
    }

    sub age {
        my ($self, $new_age) = @_;
        if (defined $new_age) {
            die "Age must be non-negative" if $new_age < 0;
            $self->{_age} = $new_age;
        }
        return $self->{_age};
    }

    sub email {
        my ($self, $new_email) = @_;
        $self->{_email} = $new_email if defined $new_email;
        return $self->{_email};
    }

    sub greet {
        my ($self) = @_;
        return sprintf "Hi, I'm %s, age %d.", $self->name(), $self->age();
    }
}

my $person = Person->new(name => "Alice", age => 30, email => "alice\@example.com");
say $person->greet();

$person->name("Alicia");
$person->age(31);
say $person->greet();
say "Email: " . $person->email();

say "\n=== METHOD CHAINING ===";

{
    package QueryBuilder;

    sub new {
        my ($class) = @_;
        return bless {
            _table      => "",
            _conditions => [],
            _order      => "",
            _limit      => 0,
        }, $class;
    }

    sub from {
        my ($self, $table) = @_;
        $self->{_table} = $table;
        return $self;
    }

    sub where {
        my ($self, $condition) = @_;
        push @{$self->{_conditions}}, $condition;
        return $self;
    }

    sub order_by {
        my ($self, $column) = @_;
        $self->{_order} = $column;
        return $self;
    }

    sub limit {
        my ($self, $n) = @_;
        $self->{_limit} = $n;
        return $self;
    }

    sub build {
        my ($self) = @_;
        my $sql = "SELECT * FROM $self->{_table}";
        if (@{$self->{_conditions}}) {
            $sql .= " WHERE " . join(" AND ", @{$self->{_conditions}});
        }
        $sql .= " ORDER BY $self->{_order}" if $self->{_order};
        $sql .= " LIMIT $self->{_limit}"    if $self->{_limit};
        return $sql;
    }
}

my $query = QueryBuilder->new
    ->from("users")
    ->where("age > 18")
    ->where("active = 1")
    ->order_by("name")
    ->limit(10)
    ->build();

say "Generated SQL:";
say "  $query";
