package Devel::KYTProf;
use strict;
use warnings;

use base qw/Class::Data::Inheritable/;

our $VERSION = '0.04';

__PACKAGE__->mk_classdata( namespace_regex       => undef );
__PACKAGE__->mk_classdata( ignore_class_regex    => undef );
__PACKAGE__->mk_classdata( context_classes_regex => undef );
__PACKAGE__->mk_classdata( logger => undef );
__PACKAGE__->mk_classdata( threshold => undef );
__PACKAGE__->mk_classdata( remove_linefeed => undef );
__PACKAGE__->mk_classdata( remove_escape_sequences => undef );

__PACKAGE__->mk_classdata( color_time   => 'red' );
__PACKAGE__->mk_classdata( color_module => 'cyan' );
__PACKAGE__->mk_classdata( color_info   => 'blue' );
__PACKAGE__->mk_classdata( color_call   => 'green' );

__PACKAGE__->mk_classdata( _orig_code   => {} );
__PACKAGE__->mk_classdata( _prof_code   => {} );

use UNIVERSAL::require;
use Time::HiRes;
use Term::ANSIColor;

'DBI'->require and do {
    no warnings 'redefine';
    __PACKAGE__->add_prof(
        'DBI',
        'connect',
        sub {
            my ($orig, $class, $dsn, $user, $pass, $attr) = @_;
            return [
                '%s %s',
                ['dbi_connect_method', 'dsn'],
                {
                    dbi_connect_method => $attr->{dbi_connect_method} || 'connect',
                    dsn => $dsn,
                },
            ];
        }
    );
    __PACKAGE__->add_prof(
        'DBI::st',
        'execute',
        sub {
            my ($orig, $sth, @binds) = @_;
            my $sql = $sth->{Database}->{Statement};
            my $bind_info = scalar(@binds) ? '(bind: '.join(', ', map { defined $_ ? $_ : 'undef' } @binds).')' : '';
            return [
                '%s %s (%d rows)',
                ['sql', 'sql_binds', 'rows'],
                {
                    sql => $sql,
                    sql_binds => $bind_info,
                    rows => $sth->rows,
                },
            ];
        }
    );
};

'LWP::UserAgent'->require and do {
    __PACKAGE__->add_prof(
        'LWP::UserAgent',
        'request',
        sub {
            my($orig, $self, $request, $arg, $size, $previous) = @_;
            return [
                '%s %s',
                ['http_method', 'http_url'],
                {
                    http_method => $request->method,
                    http_url => ''.$request->uri,
                },
            ];
        },
    );
};

'Cache::Memcached::Fast'->require and do {
    for my $method (qw/add append set get gets delete prepend replace cas incr decr/) {
        __PACKAGE__->add_prof(
            'Cache::Memcached::Fast',
            $method,
            sub {
                my ($orig, $self, $key) = @_;
                return [
                    '%s %s',
                    ['memcached_method', 'memcached_key'],
                    {
                        memcached_method => $method,
                        memcached_key => $key,
                    },
                ];
            }
        );
        my $method_multi = $method.'_multi';
        __PACKAGE__->add_prof(
            'Cache::Memcached::Fast',
            $method_multi,
            sub {
                my ($orig, $self, @args) = @_;
                if (ref $args[0] eq 'ARRAY') {
                    return [
                        '%s %s',
                        ['memcached_method', 'memcached_key'],
                        {
                            memcached_method => $method_multi,
                            memcached_key => join( ', ', map { $_->[0] } @args),
                        },
                    ];
                } else {
                    return [
                        '%s %s',
                        ['memcached_method', 'memcached_key'],
                        {
                            memcached_method => $method_multi,
                            memcached_key => join( ', ', map {ref($_) eq 'ARRAY' ? join(', ',@$_) : $_} @args),
                        },
                    ];
                }
            }
        );
    }

    __PACKAGE__->add_prof(
        'Cache::Memcached::Fast',
        'remove',
        sub {
            my ($orig, $self, $key,) = @_;
            return [
                '%s %s',
                ['memcached_method', 'memcached_key'],
                {
                    memcached_method => 'remove',
                    memcached_key => $key,
                },
            ];
        }
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

'Furl::HTTP'->require and do {
    __PACKAGE__->add_prof(
        'Furl::HTTP',
        'request',
        sub {
            my($orig, $self, %args) = @_;
            return [
                '%s %s',
                ['http_method', 'http_url'],
                {
                    http_method => $args{method},
                    http_url => $args{url},
                },
            ];
        },
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
    $class->_orig_code->{$module}->{$method} = $orig;

    my $code  = sub {
        my ($package, $file, $line, $level);
        my $namespace_regex       = $class->namespace_regex;
        my $ignore_class_regex    = $class->ignore_class_regex;
        my $context_classes_regex = $class->context_classes_regex;
        my $threshold             = $class->threshold;
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
                    ($package, $file, $line) = ($p, $f, $l);
                }

                if ($context_classes_regex && !$level && $p =~ /^($context_classes_regex)$/) {
                    $level = $i;
                }
            }
        } else {
            for my $i (1..30) {
                my ($p, $f, $l) = caller($i) or next;
                if ($p !~ /^($module)/) {
                    ($package, $file, $line) = ($p, $f, $l);
                    last;
                }
            }
        }
        unless ($package) {
            ($package, $file, $line) = caller;
        }
        my $start = [ Time::HiRes::gettimeofday ];
        my ($res, @res);
        if (wantarray) {
            @res = $orig->(@_);
        } else {
            $res = $orig->(@_);
        }
        my $ns = Time::HiRes::tv_interval($start) * 1000;
        if (!$threshold || $ns >= $threshold) {
            my $message = "";
            $message .= colored(sprintf('% 9.3f ms ', $ns), $class->color_time);
            $message .= colored(sprintf(' [%s] ', ref $_[0] || $_[0] || ''), $class->color_module);
            my $cb_info;
            my $cb_data;
            if ($callback) {
                my $v = $callback->($orig, @_);
                if (ref $v eq "ARRAY") {
                    $cb_info = sprintf $v->[0], map { $v->[2]->{$_} } @{$v->[1]};
                    $cb_data = $v->[2];
                } else {
                    $cb_info = $v;
                    $cb_data = {};
                }
            } else {
                $cb_info = $method;
                $cb_data = {};
            }
            $cb_info =~ s/[[:cntrl:]]//smg if $class->remove_escape_sequences;
            $message .= colored(sprintf(' %s ', $cb_info), $class->color_info);
            $message .= ' | ';
            $message .= colored(sprintf('%s:%d', $package || '', $line || 0), $class->color_call);
            $message =~ s/\n/ /g if $class->remove_linefeed;
            $message .= "\n";
            $class->logger ? $class->logger->log(
                level   => 'debug',
                message => $message,
                module  => $module,
                method  => $method,
                time    => $ns,
                package => $package,
                file    => $file,
                line    => $line,
                data    => $cb_data,
            ) : print STDERR $message;
        }
        return wantarray ? @res : $res;
    };
    $class->_prof_code->{$module}->{$method} = $code;

    $class->_inject_code($module, $method, $code);
}

sub _inject_code {
    my ($class, $module, $method, $code) = @_;
    no strict 'refs';
    no warnings qw/redefine prototype/;
    *{"$module\::$method"} = $code;
}

sub mute {
    my ($class, $module, @methods) = @_;

    if (scalar(@methods)) {
        for my $method (@methods) {
            $class->_inject_code($module, $method, $class->_orig_code->{$module}->{$method});
        }
    } else {
        for my $method (keys %{$class->_orig_code->{$module}}) {
            $class->_inject_code($module, $method, $class->_orig_code->{$module}->{$method});
        }
    }
}

sub unmute {
    my ($class, $module, @methods) = @_;

    if (scalar(@methods)) {
        for my $method (@methods) {
            $class->_inject_code($module, $method, $class->_prof_code->{$module}->{$method});
        }
    } else {
        for my $method (keys %{$class->_prof_code->{$module}}) {
            $class->_inject_code($module, $method, $class->_prof_code->{$module}->{$method});
        }
    }
}

{
    no warnings 'redefine';
    *DB::DB = sub {};
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

You can change settings.

  Devel::KYTProf->namespace_regex();
  Devel::KYTProf->ignore_class_regex();
  Devel::KYTProf->context_classes_regex();
  Devel::KYTProf->logger($logger);
  Devel::KYTProf->threshold(100); # ms
  Devel::KYTProf->mute($module, $method);
  Devel::KYTProf->unmute($module, $method);
  Devel::KYTProf->remove_linefeed(1);
  Devel::KYTProf->remove_escape_sequences(1);

=head1 AUTHOR

Yasuhiro Onishi E<lt>yasuhiro.onishi@gmail.comE<gt>

=head1 SEE ALSO

=over

=item L<DBI>

=item L<LWP::UserAgent>

=item L<Cache::Memcached::Fast>

=back

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
