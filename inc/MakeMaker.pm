package inc::MakeMaker;

use Moose;
use namespace::autoclean;

extends 'Dist::Zilla::Plugin::MakeMaker::Awesome';

around _build_WriteMakefile_args => sub {
    my ($orig, $self, @args) = @_;

    return {
        %{ $self->$orig(@args) },
        LIBS => '-lnanomsg',
    };
};

__PACKAGE__->meta->make_immutable;

1;
