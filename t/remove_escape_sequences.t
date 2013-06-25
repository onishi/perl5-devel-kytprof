use strict;
use warnings;
use Test::More;
use Devel::KYTProf;

local $ENV{ANSI_COLORS_DISABLED} = 1;

Devel::KYTProf->add_prof(
    'Mock',
    'foo',
    sub {
        return [
            'alarm here%s!',
            ['alarm'],
            {
                alarm => "\a"
            }
        ];
    }
);

{
    my $buffer = '';
    open my $fh, '>', \$buffer or die "Could not open in-memory buffer";
    *STDERR = $fh;

    Mock->foo;

    like $buffer, qr/alarm here\a!/;

    close $fh;
}

{
    Devel::KYTProf->remove_escape_sequences(1);
    my $buffer = '';
    open my $fh, '>', \$buffer or die "Could not open in-memory buffer";
    *STDERR = $fh;

    Mock->foo;

    like $buffer, qr/alarm here!/;

    close $fh;
}

done_testing;

package Mock;

sub foo {'foo'}


