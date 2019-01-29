package Devel::KYTProf::Profiler::Cache::Memcached::Fast;

use strict;
use warnings;

sub apply {
    for my $method (qw/add append set get gets delete prepend replace cas incr decr/) {
        Devel::KYTProf->add_prof(
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
        Devel::KYTProf->add_prof(
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

    Devel::KYTProf->add_prof(
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
}

1;
