package App::Fey;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(fey);
our $version = '0.01';

sub new {
    my ($class, $options) = @_;
    my $config = do ($ENV{XDG_CONFIG_HOME} // "$ENV{HOME}/.config") . '/fey/config.pl';

    my $self = {
        mime_query => $options->{mime_query} // $config->{mime_query} // sub {
            open my $mime_type, '-|', 'file', '--brief', '--mime-type', $_[0];
            <$mime_type>;
        },
        contexts => $options->{contexts} // $config->{contexts} // { default => sub { 1 } },
        targets => $options->{targets} // $config->{targets} // {}
    };

    bless $self, $class;
}

sub launch {
    my $self = shift;
    my $options = ref $_[0] ? shift : {};

    die "No files or URIs specified.\n" unless @_;

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
                            if ($options->{single}) {
                                $associations->{$context}->(@_);
                                return;
                            }
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
    App::Fey->new(ref $_[0] ? $_[0] : {})->launch(@_);
}
