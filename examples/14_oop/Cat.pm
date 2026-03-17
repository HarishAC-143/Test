package Cat;
use strict;
use warnings;
use parent 'Animal';

sub new {
    my ($class, %args) = @_;
    $args{sound} //= "Meow";
    my $self = $class->SUPER::new(%args);
    $self->{indoor} = $args{indoor} // 1;
    $self->{lives}  = 9;
    return $self;
}

sub is_indoor { return $_[0]->{indoor}; }
sub lives     { return $_[0]->{lives}; }

sub purr {
    my ($self) = @_;
    printf "%s purrs contentedly...\n", $self->name();
}

sub describe {
    my ($self) = @_;
    $self->SUPER::describe();
    printf "%s is an %s cat with %d lives remaining.\n",
           $self->name(),
           $self->is_indoor() ? "indoor" : "outdoor",
           $self->lives();
}

1;
