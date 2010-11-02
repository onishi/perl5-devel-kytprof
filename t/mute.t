use strict;
use warnings;
use Test::More;
use Devel::KYTProf;
use Data::Dumper;

Devel::KYTProf->add_profs('Mock',[qw/foo baz/]);

{
    my $buffer = '';
    open my $fh, '>', \$buffer or die "Could not open in-memory buffer";
    *STDERR = $fh;

    Mock->foo;
    like $buffer, qr/\[Mock\]  foo  |/;

    close $fh;
}

{
    my $buffer = '';
    open my $fh, '>', \$buffer or die "Could not open in-memory buffer";
    *STDERR = $fh;

    Devel::KYTProf->mute('Mock','foo');
    Mock->foo;

    is $buffer, '';

    Mock->baz;

    like $buffer, qr/\[Mock\]  baz  |/;

    Devel::KYTProf->unmute('Mock','foo');

    like $buffer, qr/\[Mock\]  foo  |/;

    close $fh;
}

{
    my $buffer = '';
    open my $fh, '>', \$buffer or die "Could not open in-memory buffer";
    *STDERR = $fh;

    Devel::KYTProf->mute('Mock');
    Mock->foo;
    Mock->baz;

    is $buffer, '';

    Devel::KYTProf->unmute('Mock');

    Mock->foo;
    Mock->baz;
    like $buffer, qr/\[Mock\]  foo  |/;
    like $buffer, qr/\[Mock\]  baz  |/;

    close $fh;
}

done_testing;

package Mock;

sub foo {'foo'}
sub baz {'baz'}

