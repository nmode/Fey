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

    if ($options->{group}) {
        $self->_launch_group($options, @_);
    } elsif ($options->{single}) {
        $self->_launch_single($options, @_);
    } else {
        $self->_launch($options, @_);
    }
}

sub _launch {
    my $self = shift;
    my $options = shift;

    if ($options->{fork}) {
        for my $file_or_uri (@_) {
            my $pid = fork;
            next if $pid;

            my $handler = $self->_get_handler($file_or_uri);
            $handler->($file_or_uri) if $handler;
            return;
        }
    } else {
        for my $file_or_uri (@_) {
            my $handler = $self->_get_handler($file_or_uri);
            $handler->($file_or_uri) if $handler;
        }
    }
}

sub _launch_group {
    my $self = shift;
    my $options = shift;

    my ($groups, $handlers) = ({}, {});
    for my $file_or_uri (@_) {
        my $handler = $self->_get_handler($file_or_uri);
        if ($handler) {
            $groups->{"$handler"} //= [];
            push @{ $groups->{"$handler"} }, $file_or_uri;
            $handlers->{"$handler"} = $handler;
        }
    }

    if ($options->{fork}) {
        for my $group (keys %{ $groups }) {
            if ($options->{fork}) {
                my $pid = fork;
                next if $pid;
            }

            $handlers->{$group}->(@{ $groups->{$group} });
            return;
        }
    } else {
        for my $group (keys %{ $groups }) {
            $handlers->{$group}->(@{ $groups->{$group} });
        }
    }
}

sub _launch_single {
    my $self = shift;
    my $options = shift;

    if ($options->{fork}) {
        my $pid = fork;
        return if $pid;
    }

    my $handler = $self->_get_handler($_[0]);
    $handler->(@_) if $handler;
}

sub _get_handler {
    my $self = shift;
    
    my $file_or_uri = $_[0] =~ m|^file://(.+)| ? $1 : $_[0];
    my $mime_or_uri = -e $file_or_uri ? $self->{mime_query}->($file_or_uri) : $file_or_uri;

    for my $target (@{ $self->{targets} }) {
        for my $pattern (@{ $target->{patterns} }) {
            if ($mime_or_uri =~ /$pattern/) {
                my $associations = $target->{associations};
                for my $context (keys %{ $associations }) {
                    if ($self->{contexts}->{$context}->()) {
                        return $associations->{$context};
                    }
                }
            }
        }
    }
}

sub fey {
    App::Fey->new(ref $_[0] ? $_[0] : {})->launch(@_);
}
