use strict;
use warnings;
use Test::More;
use Devel::KYTProf;

Devel::KYTProf->add_prof(
    'Mock',
    'foo',
    sub {
        return [
            'alarm here (%s/%d)',
            ['string', 'number'],
            {
                string => undef,
                number => undef,
            },
        ];
    }
);

{
    my $buffer = '';
    open my $fh, '>', \$buffer or die "Could not open in-memory buffer";
    *STDERR = $fh;

    Mock->foo;

    unlike $buffer, qr/Use of uninitialized value in sprintf/;
    like $buffer, qr/alarm here \(\/0\)/;

    close $fh;
}

done_testing;

package Mock;

sub foo {'foo'}
