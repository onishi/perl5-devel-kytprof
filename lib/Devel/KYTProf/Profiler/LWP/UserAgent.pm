package Devel::KYTProf::Profiler::LWP::UserAgent;

use strict;
use warnings;

sub apply {
    Devel::KYTProf->add_prof(
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
}

1;
