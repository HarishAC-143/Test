package Dog;
use strict;
use warnings;
use parent 'Animal';

sub new {
    my ($class, %args) = @_;
    $args{sound} //= "Woof";
    my $self = $class->SUPER::new(%args);
    $self->{tricks} = $args{tricks} // [];
    $self->{breed}  = $args{breed}  // "Mixed";
    return $self;
}

sub breed { return $_[0]->{breed}; }

sub learn_trick {
    my ($self, $trick) = @_;
    push @{$self->{tricks}}, $trick;
    printf "%s learned '%s'!\n", $self->name(), $trick;
}

sub show_tricks {
    my ($self) = @_;
    my @tricks = @{$self->{tricks}};
    if (@tricks) {
        printf "%s knows: %s\n", $self->name(), join(", ", @tricks);
    } else {
        printf "%s doesn't know any tricks yet.\n", $self->name();
    }
}

sub describe {
    my ($self) = @_;
    $self->SUPER::describe();
    printf "%s is a %s.\n", $self->name(), $self->breed();
}

1;
