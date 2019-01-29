package Devel::KYTProf::Profiler::Furl::HTTP;

use strict;
use warnings;

sub apply {
    Devel::KYTProf->add_prof(
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
}

1;
