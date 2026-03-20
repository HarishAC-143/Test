#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

# ============================================================
# Object-Oriented Perl — Inheritance and Polymorphism
# ============================================================

# --- Base class: Shape ---
{
    package Shape;

    sub new {
        my ($class, %args) = @_;
        my $self = {
            color => $args{color} // "black",
            x     => $args{x}    // 0,
            y     => $args{y}    // 0,
        };
        return bless $self, $class;
    }

    sub color { return $_[0]->{color} }
    sub x     { return $_[0]->{x} }
    sub y     { return $_[0]->{y} }

    sub area {
        die ref($_[0]) . " must implement area()\n";
    }

    sub perimeter {
        die ref($_[0]) . " must implement perimeter()\n";
    }

    sub describe {
        my ($self) = @_;
        printf "%s at (%d,%d), color=%s, area=%.2f, perimeter=%.2f\n",
            ref($self), $self->x(), $self->y(),
            $self->color(), $self->area(), $self->perimeter();
    }

    sub move {
        my ($self, $dx, $dy) = @_;
        $self->{x} += $dx;
        $self->{y} += $dy;
        return $self;
    }
}

# --- Circle ---
{
    package Circle;
    use parent -norequire, 'Shape';
    use POSIX qw();

    my $PI = 4 * atan2(1, 1);

    sub new {
        my ($class, %args) = @_;
        my $self = $class->SUPER::new(%args);
        $self->{radius} = $args{radius} // 1;
        return $self;
    }

    sub radius { return $_[0]->{radius} }
    sub area   { return $PI * $_[0]->{radius} ** 2 }
    sub perimeter { return 2 * $PI * $_[0]->{radius} }
}

# --- Rectangle ---
{
    package Rectangle;
    use parent -norequire, 'Shape';

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

# --- Square (inherits from Rectangle) ---
{
    package Square;
    use parent -norequire, 'Rectangle';

    sub new {
        my ($class, %args) = @_;
        $args{height} = $args{side} // $args{width} // 1;
        $args{width}  = $args{height};
        return $class->SUPER::new(%args);
    }

    sub side { return $_[0]->{width} }
}

# --- Triangle ---
{
    package Triangle;
    use parent -norequire, 'Shape';

    sub new {
        my ($class, %args) = @_;
        my $self = $class->SUPER::new(%args);
        $self->{base}   = $args{base}   // 1;
        $self->{height} = $args{height} // 1;
        $self->{side_a} = $args{side_a} // $self->{base};
        $self->{side_b} = $args{side_b} // $self->{height};
        return $self;
    }

    sub base   { return $_[0]->{base} }
    sub height { return $_[0]->{height} }
    sub area   { return 0.5 * $_[0]->{base} * $_[0]->{height} }
    sub perimeter {
        my ($self) = @_;
        return $self->{base} + $self->{side_a} + $self->{side_b};
    }
}

# --- Main program ---
package main;

say "=== CREATING SHAPES ===";

my @shapes = (
    Circle->new(radius => 5, color => "red", x => 10, y => 20),
    Rectangle->new(width => 8, height => 4, color => "blue"),
    Square->new(side => 6, color => "green", x => 5, y => 5),
    Triangle->new(base => 10, height => 7, side_a => 8, side_b => 9, color => "yellow"),
    Circle->new(radius => 3, color => "purple", x => -5, y => 15),
);

say "\n=== DESCRIBING ALL SHAPES (POLYMORPHISM) ===";

for my $shape (@shapes) {
    $shape->describe();
}

say "\n=== SORTING BY AREA ===";

my @by_area = sort { $a->area() <=> $b->area() } @shapes;
for my $shape (@by_area) {
    printf "  %-12s area = %8.2f\n", ref($shape), $shape->area();
}

say "\n=== TOTAL AREA ===";

my $total = 0;
$total += $_->area() for @shapes;
printf "Total area of all shapes: %.2f\n", $total;

say "\n=== INHERITANCE CHAIN ===";

my $square = Square->new(side => 4);
say "Square ISA Rectangle? " . ($square->isa("Rectangle") ? "Yes" : "No");
say "Square ISA Shape?     " . ($square->isa("Shape")     ? "Yes" : "No");
say "Square ISA Circle?    " . ($square->isa("Circle")    ? "Yes" : "No");
say "Class: " . ref($square);

say "\n=== MOVING SHAPES ===";

my $circle = $shapes[0];
say "Before move: ";
$circle->describe();
$circle->move(5, -3);
say "After move(5,-3): ";
$circle->describe();

say "\n=== METHOD RESOLUTION ORDER ===";

no strict 'refs';
say "Square's ISA: " . join(" -> ", @{"Square::ISA"});
say "Rectangle's ISA: " . join(" -> ", @{"Rectangle::ISA"});
say "Circle's ISA: " . join(" -> ", @{"Circle::ISA"});

say "\n--- Inheritance demo complete ---";
