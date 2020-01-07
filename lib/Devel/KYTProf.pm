package Devel::KYTProf;
use strict;
use warnings;

our $VERSION = '0.9994';

my $Applied = {};

use Class::Data::Lite (
    rw => {
        namespace_regex         => undef,
        ignore_class_regex      => undef,
        context_classes_regex   => undef,
        logger                  => undef,
        threshold               => undef,
        remove_linefeed         => undef,
        remove_escape_sequences => undef,

        color_time   => 'red',
        color_module => 'cyan',
        color_info   => 'blue',
        color_call   => 'green',

        _orig_code => {},
        _prof_code => {},
    },
);

use Module::Load ();
use Time::HiRes;
use Term::ANSIColor;

sub import {
    __PACKAGE__->apply_prof('DBI');
    __PACKAGE__->apply_prof('LWP::UserAgent');
    __PACKAGE__->apply_prof('Cache::Memcached::Fast');
    __PACKAGE__->apply_prof('MogileFS::Client');
    __PACKAGE__->apply_prof('Furl::HTTP');
    1;
}

sub apply_prof {
    my ($class, $pkg, $prof_pkg, @args) = @_;
    eval { Module::Load::load($pkg) };
    return if $@;

    $prof_pkg ||= "Devel::KYTProf::Profiler::$pkg";
    eval {Module::Load::load($prof_pkg)};
    if ($@) {
        die qq{failed to load profiler package "$prof_pkg" for "$pkg": $@\n};
    }
    unless ($prof_pkg->can('apply')) {
        die qq{"$prof_pkg" has no `apply` method. A profiler package should implement it.\n};
    }
    return if ++$Applied->{$prof_pkg} > 1; # skip if already applied
    $prof_pkg->apply(@args);
}

sub add_profs {
    my ($class, $module, $methods, $callback, $sampler) = @_;
    eval {Module::Load::load($module)};
    if ($methods eq ':all') {
        eval { Module::Load::load('Class/Inspector.pm') };
        return if $@;
        $methods = [];
        @$methods = @{Class::Inspector->methods($module, 'public')};
    }
    for my $method (@$methods) {
        $class->add_prof($module, $method, $callback, $sampler);
    }
}

sub add_prof {
    my ($class, $module, $method, $callback, $sampler) = @_;
    eval {Module::Load::load($module)};
    my $orig = $class->_orig_code->{$module}{$method};
    unless ($orig) {
        $orig = $module->can($method) or return;
        $class->_orig_code->{$module}->{$method} = $orig;
    }

    my $code = sub {
        if ($sampler) {
            my $is_sample = $sampler->($orig, @_);
            unless ($is_sample) {
                return $orig->(@_);
            }
        }

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

  Devel::KYTProf->add_prof($module, $method, [$callback, $sampler]);
  Devel::KYTProf->add_profs($module, $methods, [$callback, $sampler]);
  Devel::KYTProf->add_profs($module, ':all', [$callback, $sampler]);

The C<< $sampler >> is still an experimental feature.

You can specify profiler packages.

  Devel::KYTProf->apply_prof($pkg, [$prof_pkg, @args]);

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
