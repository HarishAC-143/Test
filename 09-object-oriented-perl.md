# Chapter 9: Object-Oriented Perl

Perl supports object-oriented programming (OOP) through a few simple mechanisms: packages (as classes), `bless` (to associate data with a class), and method dispatch via the arrow operator `->`.

## Classic OOP: bless-Based Objects

### A Simple Class

```perl
package Animal;

use strict;
use warnings;

# Constructor
sub new {
    my ($class, %args) = @_;
    my $self = {
        name   => $args{name}   // "Unknown",
        species => $args{species} // "Unknown",
        sound  => $args{sound}  // "...",
    };
    return bless $self, $class;
}

# Accessor methods
sub name    { return $_[0]->{name} }
sub species { return $_[0]->{species} }
sub sound   { return $_[0]->{sound} }

# Method
sub speak {
    my ($self) = @_;
    printf "%s the %s says '%s!'\n", $self->name, $self->species, $self->sound;
}

# Setter
sub set_name {
    my ($self, $name) = @_;
    $self->{name} = $name;
    return $self;   # for method chaining
}

sub describe {
    my ($self) = @_;
    return sprintf("Animal: %s (species: %s)", $self->name, $self->species);
}

1;
```

### Using the Class

```perl
#!/usr/bin/perl
use strict;
use warnings;
use lib '.';
use Animal;

my $dog = Animal->new(
    name    => "Rex",
    species => "Dog",
    sound   => "Woof",
);

my $cat = Animal->new(
    name    => "Whiskers",
    species => "Cat",
    sound   => "Meow",
);

$dog->speak();   # Rex the Dog says 'Woof!'
$cat->speak();   # Whiskers the Cat says 'Meow!'

print $dog->describe(), "\n";

# Method chaining
$dog->set_name("Buddy")->speak();   # Buddy the Dog says 'Woof!'
```

## Inheritance

```perl
package Dog;

use strict;
use warnings;
use parent 'Animal';   # inherits from Animal

sub new {
    my ($class, %args) = @_;
    $args{species} = "Dog";
    $args{sound}   //= "Woof";
    my $self = $class->SUPER::new(%args);
    $self->{tricks} = $args{tricks} // [];
    return $self;
}

sub learn_trick {
    my ($self, $trick) = @_;
    push @{$self->{tricks}}, $trick;
    print $self->name, " learned '$trick'!\n";
    return $self;
}

sub show_tricks {
    my ($self) = @_;
    my @tricks = @{$self->{tricks}};
    if (@tricks) {
        print $self->name, " knows: ", join(", ", @tricks), "\n";
    } else {
        print $self->name, " hasn't learned any tricks yet.\n";
    }
}

# Override parent method
sub speak {
    my ($self) = @_;
    $self->SUPER::speak();
    print "(wags tail)\n";
}

1;
```

Usage:

```perl
use Dog;

my $dog = Dog->new(name => "Rex");
$dog->speak();
# Rex the Dog says 'Woof!'
# (wags tail)

$dog->learn_trick("sit")
    ->learn_trick("shake")
    ->learn_trick("roll over");

$dog->show_tricks();
# Rex knows: sit, shake, roll over

# Inheritance check
print "Is a Dog: ", ref($dog) eq "Dog" ? "yes" : "no", "\n";       # yes
print "Is an Animal: ", $dog->isa("Animal") ? "yes" : "no", "\n";  # yes
```

## Modern OOP with Moo

`Moo` (Minimalist Object Orientation) is a lightweight OO framework that eliminates boilerplate.

```perl
package Person;

use Moo;
use Types::Standard qw(Str Int ArrayRef);

has name => (
    is       => 'ro',           # read-only
    isa      => Str,
    required => 1,
);

has age => (
    is      => 'rw',            # read-write
    isa     => Int,
    default => 0,
);

has email => (
    is        => 'rw',
    isa       => Str,
    predicate => 'has_email',   # generates has_email() method
    clearer   => 'clear_email', # generates clear_email() method
);

has hobbies => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    default => sub { [] },
);

sub introduce {
    my ($self) = @_;
    printf "Hi, I'm %s, age %d.\n", $self->name, $self->age;
    if ($self->has_email) {
        printf "Email: %s\n", $self->email;
    }
    if (@{$self->hobbies}) {
        printf "Hobbies: %s\n", join(", ", @{$self->hobbies});
    }
}

sub celebrate_birthday {
    my ($self) = @_;
    $self->age($self->age + 1);
    printf "%s is now %d years old!\n", $self->name, $self->age;
}

1;
```

### Moo Inheritance and Roles

```perl
package Employee;

use Moo;
use Types::Standard qw(Str Num);

extends 'Person';   # inheritance

has company => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has salary => (
    is      => 'rw',
    isa     => Num,
    default => 0,
);

around introduce => sub {
    my ($orig, $self) = @_;
    $self->$orig();    # call parent method
    printf "I work at %s.\n", $self->company;
};

1;
```

### Roles (Like Interfaces with Implementation)

```perl
package Role::Printable;

use Moo::Role;

requires 'to_string';   # classes using this role must implement to_string()

sub print_self {
    my ($self) = @_;
    print $self->to_string(), "\n";
}

sub print_to_file {
    my ($self, $filename) = @_;
    open(my $fh, ">>", $filename) or die "Cannot open $filename: $!\n";
    print $fh $self->to_string(), "\n";
    close $fh;
}

1;

# Using the role
package Report;

use Moo;
use Types::Standard qw(Str ArrayRef);

with 'Role::Printable';   # compose the role

has title => (is => 'ro', isa => Str, required => 1);
has lines => (is => 'ro', isa => ArrayRef[Str], default => sub { [] });

sub add_line {
    my ($self, $line) = @_;
    push @{$self->lines}, $line;
    return $self;
}

sub to_string {
    my ($self) = @_;
    return join("\n",
        "=== " . $self->title . " ===",
        @{$self->lines},
        "=" x (length($self->title) + 8),
    );
}

1;
```

## Method Modifiers (Moo/Moose)

```perl
package CachedFetcher;

use Moo;

has cache => (is => 'ro', default => sub { {} });

sub fetch {
    my ($self, $url) = @_;
    return "Content of $url";
}

# 'before' — runs before the method
before fetch => sub {
    my ($self, $url) = @_;
    print "Fetching: $url\n";
};

# 'after' — runs after the method
after fetch => sub {
    my ($self, $url) = @_;
    print "Done fetching: $url\n";
};

# 'around' — wraps the method (most powerful)
around fetch => sub {
    my ($orig, $self, $url) = @_;

    if (exists $self->cache->{$url}) {
        print "(cache hit)\n";
        return $self->cache->{$url};
    }

    my $result = $self->$orig($url);
    $self->cache->{$url} = $result;
    return $result;
};

1;
```

## Overloading Operators

Make objects work with built-in operators:

```perl
package Vector;

use strict;
use warnings;

use overload
    '+'  => \&add,
    '-'  => \&subtract,
    '*'  => \&multiply,
    '""' => \&to_string,
    '==' => \&is_equal;

sub new {
    my ($class, $x, $y) = @_;
    return bless { x => $x, y => $y }, $class;
}

sub x { $_[0]->{x} }
sub y { $_[0]->{y} }

sub add {
    my ($self, $other) = @_;
    return Vector->new($self->x + $other->x, $self->y + $other->y);
}

sub subtract {
    my ($self, $other) = @_;
    return Vector->new($self->x - $other->x, $self->y - $other->y);
}

sub multiply {
    my ($self, $scalar, $reversed) = @_;
    return Vector->new($self->x * $scalar, $self->y * $scalar);
}

sub magnitude {
    my ($self) = @_;
    return sqrt($self->x ** 2 + $self->y ** 2);
}

sub to_string {
    my ($self) = @_;
    return sprintf("(%s, %s)", $self->x, $self->y);
}

sub is_equal {
    my ($self, $other) = @_;
    return $self->x == $other->x && $self->y == $other->y;
}

1;
```

Usage:

```perl
my $v1 = Vector->new(3, 4);
my $v2 = Vector->new(1, 2);

my $v3 = $v1 + $v2;        # (4, 6)
my $v4 = $v1 - $v2;        # (2, 2)
my $v5 = $v1 * 3;          # (9, 12)

print "v1 = $v1\n";            # v1 = (3, 4)
print "v1 + v2 = $v3\n";       # v1 + v2 = (4, 6)
print "v1 magnitude = ", $v1->magnitude(), "\n";   # 5
print "Equal: ", ($v1 == $v1 ? "yes" : "no"), "\n"; # yes
```

## DESTROY and Cleanup

```perl
package DatabaseConnection;

use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = bless {
        host      => $args{host} // "localhost",
        connected => 0,
    }, $class;
    $self->connect();
    return $self;
}

sub connect {
    my ($self) = @_;
    print "Connecting to $self->{host}...\n";
    $self->{connected} = 1;
}

sub disconnect {
    my ($self) = @_;
    if ($self->{connected}) {
        print "Disconnecting from $self->{host}...\n";
        $self->{connected} = 0;
    }
}

sub DESTROY {
    my ($self) = @_;
    $self->disconnect();
}

1;

# Usage:
{
    my $db = DatabaseConnection->new(host => "db.example.com");
    # ... use database ...
}   # $db goes out of scope, DESTROY is called automatically
# Output: Connecting to db.example.com...
#         Disconnecting from db.example.com...
```

## Practical Example: Task Manager

```perl
package Task;

use strict;
use warnings;
use POSIX qw(strftime);

my $next_id = 1;

sub new {
    my ($class, %args) = @_;
    return bless {
        id          => $next_id++,
        title       => $args{title}       // "Untitled",
        description => $args{description} // "",
        priority    => $args{priority}    // "medium",
        status      => "pending",
        created_at  => strftime("%Y-%m-%d %H:%M:%S", localtime),
        completed_at => undef,
    }, $class;
}

sub id          { $_[0]->{id} }
sub title       { $_[0]->{title} }
sub status      { $_[0]->{status} }
sub priority    { $_[0]->{priority} }

sub complete {
    my ($self) = @_;
    $self->{status} = "completed";
    $self->{completed_at} = strftime("%Y-%m-%d %H:%M:%S", localtime);
    return $self;
}

sub to_string {
    my ($self) = @_;
    return sprintf("[#%d] [%s] [%s] %s",
        $self->{id}, uc($self->{priority}), $self->{status}, $self->{title});
}

1;

package TaskManager;

use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless { tasks => [] }, $class;
}

sub add_task {
    my ($self, %args) = @_;
    my $task = Task->new(%args);
    push @{$self->{tasks}}, $task;
    print "Added: ", $task->to_string(), "\n";
    return $task;
}

sub complete_task {
    my ($self, $id) = @_;
    for my $task (@{$self->{tasks}}) {
        if ($task->id == $id) {
            $task->complete();
            print "Completed: ", $task->to_string(), "\n";
            return 1;
        }
    }
    print "Task #$id not found.\n";
    return 0;
}

sub list_tasks {
    my ($self, %filter) = @_;
    my @tasks = @{$self->{tasks}};

    if ($filter{status}) {
        @tasks = grep { $_->status eq $filter{status} } @tasks;
    }
    if ($filter{priority}) {
        @tasks = grep { $_->priority eq $filter{priority} } @tasks;
    }

    print "\n--- Tasks ---\n";
    if (@tasks) {
        print $_->to_string(), "\n" for @tasks;
    } else {
        print "(no tasks found)\n";
    }
    print "---\n";
}

sub summary {
    my ($self) = @_;
    my $total     = scalar @{$self->{tasks}};
    my $completed = scalar grep { $_->status eq "completed" } @{$self->{tasks}};
    my $pending   = $total - $completed;
    printf "\nTotal: %d | Completed: %d | Pending: %d\n", $total, $completed, $pending;
}

1;
```

Usage:

```perl
my $tm = TaskManager->new();

$tm->add_task(title => "Write documentation", priority => "high");
$tm->add_task(title => "Fix login bug",       priority => "high");
$tm->add_task(title => "Update CSS styles",   priority => "low");
$tm->add_task(title => "Add unit tests",      priority => "medium");

$tm->list_tasks();
$tm->complete_task(1);
$tm->complete_task(2);
$tm->list_tasks(status => "pending");
$tm->summary();
```

## Chapter Summary

- Classic Perl OOP uses `bless`, manual constructors, and accessor methods.
- `use parent` provides single and multiple inheritance.
- `Moo` eliminates OOP boilerplate with declarative attribute definitions, type checking, and role composition.
- Method modifiers (`before`, `after`, `around`) provide powerful aspect-oriented features.
- `overload` lets objects work with Perl's built-in operators.
- `DESTROY` handles automatic cleanup when objects go out of scope.
- Roles (via `Moo::Role`) are Perl's alternative to multiple inheritance, providing safer code composition.

---

**Previous**: [Chapter 8 — Modules and CPAN](08-modules-and-cpan.md)
**Next**: [Chapter 10 — Error Handling](10-error-handling.md)
