#!perl
# ABSTRACT: Wrapper for Oracle objects
use strict;
use warnings;

package DBD::Oracle::Object;
# VERSION

sub type_name { shift->{type_name} }

sub attributes { @{shift->{attributes}} }

sub attr_hash {
    my $self = shift;
    return $self->{attr_hash} ||= { $self->attributes };
}

sub attr {
    my $self = shift;
    if (@_) {
        my $key = shift;
        return $self->attr_hash->{$key};
    }
    return $self->attr_hash;
}

1;
