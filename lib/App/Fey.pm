package App::Fey;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(fey);
our $version = '0.01';

sub new {
    my ($class, $args) = @_;
    my $config = do ($ENV{XDG_CONFIG_HOME} // "$ENV{HOME}/.config") . '/fey/config.pl';

    my $self = {
        mime_query => $args->{mime_query} // $config->{mime_query} // sub { `file --brief --mime-type "$_[0]"` },
        contexts => $args->{contexts} // $config->{contexts} // { default => sub { 1 } },
        targets => $args->{targets} // $config->{targets} // {}
    };

    bless $self, $class;
}

sub launch {
    my $self = shift;

    ARG: for my $file_or_uri (@_) {
        if ($file_or_uri =~ m|^file://(.+)|) {
            $file_or_uri = $1;
        }

        my ($mime_or_uri, $targets);
        if (-e $file_or_uri) {
            $mime_or_uri = $self->{mime_query}->($file_or_uri)
        } else {
            $mime_or_uri = $file_or_uri;
        }

        for my $target (@{ $self->{targets} }) {
            for my $pattern (@{ $target->{patterns} }) {
                if ($mime_or_uri =~ /$pattern/) {
                    my $associations = $target->{associations};
                    for my $context (keys %{ $associations }) {
                        if ($self->{contexts}->{$context}->()) {
                            $associations->{$context}->($file_or_uri);
                            next ARG;
                        }
                    }
                }
            }
        }
    }
}

sub fey {
    App::Fey->new(ref $_[0] ? shift : {})->launch(@_ ? @_ : die 'Error: No files or URIs specified.');
}
