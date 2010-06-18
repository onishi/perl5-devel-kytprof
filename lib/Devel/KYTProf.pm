package Devel::KYTProf;
use strict;
use warnings;
no warnings 'redefine';

use base qw/Class::Data::Inheritable/;

__PACKAGE__->mk_classdata( base_classes => [qw//] );
__PACKAGE__->mk_classdata( _base_classes_regex => undef );
__PACKAGE__->mk_classdata( logger => '' );
__PACKAGE__->mk_classdata( st_sql => {} );

use UNIVERSAL::require;
use DBI;
use Time::HiRes;

{ # DBI
    my $orig_prepare        = \&DBI::db::prepare;
    my $orig_prepare_cached = \&DBI::db::prepare_cached;
    *DBI::db::prepare = sub {
        my $sth = $orig_prepare->(@_);
        __PACKAGE__->st_sql->{$sth} = $_[1];
        return $sth;
    };
    *DBI::db::prepare_cached = sub {
        my $sth = $orig_prepare_cached->(@_);
        __PACKAGE__->st_sql->{$sth} = $_[1];
        return $sth;
    };
    __PACKAGE__->add_prof(
        'DBI::st',
        'execute',
        sub {
            my ($orig, $sth) = @_;
            return sprintf '%s (%d rows)', __PACKAGE__->st_sql->{$sth}, $sth->rows;
        }
    );
};

{ # LWP::UserAgent
    __PACKAGE__->add_prof(
        'LWP::UserAgent',
        'request',
        sub {
            my($orig, $self, $request, $arg, $size, $previous) = @_;
            return sprintf '%s %s', $request->method, $request->uri;
        },
    );
};

sub base_classes_regex {
    my $class = shift;
    return defined $class->_base_classes_regex
        ? $class->_base_classes_regex
        : $class->_base_classes_regex(join '|', map { quotemeta } @{$class->base_classes} || '');
}

sub add_prof {
    my ($class, $module, $method, $callback) = @_;
    $module->require; # or warn $@ and return;
    my $orig  = $module->can($method) or return;
    my $regex = $class->base_classes_regex;
    my $code  = sub {
        my ($package, $line, $level);
        if ($regex) {
            my ($i, $known);
            for (1..10) {
                my ($p, $f, $l) = caller($_) or next;
                $known->{$p}++ and next;
                $i++;
                if ($p =~ /^($regex)$/) {
                    $level = $i;
                    last;
                }
                ($package, $line) = ($p, $l);
            }
        }
        my $start = [ Time::HiRes::gettimeofday ];
        my ($res, @res);
        if (wantarray) {
            @res = $orig->(@_);
        } else {
            $res = $orig->(@_);
        }
        my $ns = Time::HiRes::tv_interval($start);
        my $message = sprintf(
            "%s ms [%s] %s | %s:%d\n",
            $ns * 1000,
            ref $_[0] || $_[0] || '',
            $callback ? $callback->($orig, @_) || '' : $method || '',
            $package || '',
            $line || 0,
        );
        $class->logger ? $class->logger->log(
            level   => 'debug',
            message => $message,
        ) : warn $message;
        return wantarray ? @res : $res;
    };
    no strict 'refs';
    *{"$module\::$method"} = $code;
}

1;

__END__

=head1 NAME

Devel::KYTProf -

=head1 SYNOPSIS

  use Devel::KYTProf;

=head1 DESCRIPTION

Devel::KYTProf is

=head1 AUTHOR

Yasuhiro Onishi E<lt>yasuhiro.onishi@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
