use strict;
use warnings;
use Test::More;
use Devel::KYTProf;

Devel::KYTProf->add_prof(
    'Mock',
    'foo',
    sub {
        my ($orig, $self, $arg) = @_;
        return sprintf '%s %s', "foo", $arg;
    }
);

{
    my $buffer = '';
    open my $fh, '>', \$buffer or die "Could not open in-memory buffer";
    *STDERR = $fh;

    Mock->foo("BAR");

    like $buffer, qr/foo BAR/;
    close $fh;
}

done_testing;

package Mock;

sub foo {'foo'}


