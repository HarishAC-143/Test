package Animal;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = {
        name  => $args{name}  // "Unknown",
        sound => $args{sound} // "...",
        legs  => $args{legs}  // 4,
    };
    return bless $self, $class;
}

sub name  { return $_[0]->{name}; }
sub sound { return $_[0]->{sound}; }
sub legs  { return $_[0]->{legs}; }

sub speak {
    my ($self) = @_;
    printf "%s says %s!\n", $self->name(), $self->sound();
}

sub describe {
    my ($self) = @_;
    printf "%s has %d legs.\n", $self->name(), $self->legs();
}

sub to_string {
    my ($self) = @_;
    return sprintf("%s (sound: %s, legs: %d)", $self->name(), $self->sound(), $self->legs());
}

1;
