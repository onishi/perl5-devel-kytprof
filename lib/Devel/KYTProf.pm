package Devel::KYTProf;
use strict;
use warnings;

use base qw/Class::Data::Inheritable/;

__PACKAGE__->mk_classdata( namespace_regex       => undef );
__PACKAGE__->mk_classdata( ignore_class_regex    => undef );
__PACKAGE__->mk_classdata( context_classes_regex => undef );
__PACKAGE__->mk_classdata( logger => '' );
__PACKAGE__->mk_classdata( st_sql => {} ); # for DBI

use UNIVERSAL::require;
use Time::HiRes;

'DBI'->require and do {
    no warnings 'redefine';
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

'LWP::UserAgent'->require and do {
    __PACKAGE__->add_prof(
        'LWP::UserAgent',
        'request',
        sub {
            my($orig, $self, $request, $arg, $size, $previous) = @_;
            return sprintf '%s %s', $request->method, $request->uri;
        },
    );
};

'Cache::Memcached::Fast'->require and do {
    __PACKAGE__->add_profs(
        'Cache::Memcached::Fast',
        [qw{
            add     add_multi
            append  append_multi
            cas     cas_multi
            decr    decr_multi
            delete  delete_multi
            get     get_multi
            gets    gets_multi
            incr    incr_multi
            prepend prepend_multi
            remove
            replace replace_multi
            set     set_multi
        }],
    );
};

'MogileFS::Client'->require and do {
    __PACKAGE__->add_profs(
        'MogileFS::Client',
        [qw{
            edit_file
            read_file
            store_file
            store_content
            get_paths
            get_file_data
            delete
            rename
        }],
    );
};

sub add_profs {
    my ($class, $module, $methods, $callback) = @_;
    $module->require; # or warn $@ and return;
    if ($methods eq ':all') {
        Class::Inspector->require or return;
        $methods = [];
        @$methods = @{Class::Inspector->methods($module, 'public')};
    }
    for my $method (@$methods) {
        $class->add_prof($module, $method, $callback);
    }
}

sub add_prof {
    my ($class, $module, $method, $callback) = @_;
    $module->require; # or warn $@ and return;
    my $orig  = $module->can($method) or return;
    my $code  = sub {
        my ($package, $line, $level);
        my $namespace_regex       = $class->namespace_regex;
        my $ignore_class_regex    = $class->ignore_class_regex;
        my $context_classes_regex = $class->context_classes_regex;
        if ($namespace_regex || $context_classes_regex) {
            for my $i (1..30) {
                my ($p, $f, $l) = caller($i) or next;
                if (
                    $namespace_regex
                        &&
                    !$package
                        &&
                    $p =~ /^($namespace_regex)/
                        &&
                    (! $ignore_class_regex || $p !~ /$ignore_class_regex/)
                ) {
                    ($package, $line) = ($p, $l);
                }

                if ($context_classes_regex && !$level && $p =~ /^($context_classes_regex)$/) {
                    $level = $i;
                }
            }
        } else {
            for my $i (1..30) {
                my ($p, $f, $l) = caller($i) or next;
                if ($p !~ /^($module)/) {
                    ($package, $line) = ($p, $l);
                    last;
                }
            }
        }
        unless ($package) {
            ($package, undef, $line) = caller;
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
    no warnings qw/redefine prototype/;
    *{"$module\::$method"} = $code;
}

1;

__END__

=head1 NAME

Devel::KYTProf - Simple profiler

=head1 SYNOPSIS

  use Devel::KYTProf;

  # your code ( including DBI, LWP )

=head1 DESCRIPTION

Devel::KYTProf is a perl code profiler to explore IO blocking time.

  use Devel::KYTProf;

  # your code ( including DBI, LWP )

Output as follows.

  315.837 ms [DBI::st] select * from table where name = ? (1 rows) | main:23
  1464.204 ms [LWP::UserAgent] GET http://www.hatena.ne.jp/ | main:25

You can add profiler to any method.

  Devel::KYTProf->add_prof($module, $method);
  Devel::KYTProf->add_prof($module, $method, $callback);

  Devel::KYTProf->add_profs($module, $methods);
  Devel::KYTProf->add_profs($module, $methods, $callback);

  Devel::KYTProf->add_profs($module, ':all');
  Devel::KYTProf->add_profs($module, ':all', $callback);

=head1 AUTHOR

Yasuhiro Onishi E<lt>yasuhiro.onishi@gmail.comE<gt>

=head1 SEE ALSO

=over

=item L<DBI>

=item L<LWP::UserAgent>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
