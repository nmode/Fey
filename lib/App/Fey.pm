package App::Fey;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(fey);
our $version = '0.01';

sub new {
    my ($class, $args) = @_;
    my $config = do ($ENV{XDG_CONFIG_HOME} // "$ENV{HOME}/.config") . '/fey/config.pl';
    my $placeholder = $args->{placeholder} // $config->{placeholder} // '//f';

    my $self = {
        contexts => $args->{contexts} // $config->{contexts} // { default => 1 },
        placeholder => $placeholder,
        mime_query => $args->{mime_query} // $config->{mime_query} // "file --brief --mime-type $placeholder",
        targets => $args->{targets} // $config->{targets} // {}
    };

    bless $self, $class;
}

sub launch {
    my ($self, $file_or_uri) = @_;

    if ($file_or_uri =~ m|^file://(.+)|) {
        $file_or_uri = $1;
    }

    my ($mime_or_uri, $targets);
    if (-e $file_or_uri) {
        $mime_or_uri = $self->{mime_query} =~ s/$self->{placeholder}/"$file_or_uri"/r;
        $mime_or_uri = `$mime_or_uri`;
    } else {
        $mime_or_uri = $file_or_uri;
    }

    for my $target (@{ $self->{targets} }) {
        for my $pattern (@{ $target->{patterns} }) {
            if ($mime_or_uri =~ /$pattern/) {
                my $associations = $target->{associations};
                for my $context (keys %{ $associations }) {
                    if ($self->{contexts}->{$context}) {
                        my $command = $associations->{$context};
                        $command =~ s/$self->{placeholder}/"$file_or_uri"/;
                        `$command`;
                        return;
                    }
                }
            }
        }
    }
}

sub fey {
    App::Fey->new($_[1] // {})->launch($_[0] // die 'Error: No file or URI specified.');
}
