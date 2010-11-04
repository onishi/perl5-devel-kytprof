use strict;
use warnings;
use Test::More;
use Devel::KYTProf;

BEGIN {
    eval "use DBI";
    plan skip_all => 'DBI is not installed. skip testing' if $@;
    eval "use DBD::SQLite";
    plan skip_all => 'needs DBD::SQLite for testing' if $@;
}

my $buffer = '';
open my $fh, '>', \$buffer or die "Could not open in-memory buffer";
*STDERR = $fh;

my $dbi = DBI->connect('dbi:SQLite:','','');

$dbi->do(q{create table mock (id integer, name text, primary key ( id ))});

close $fh;

{
    my $buffer = '';
    open my $fh, '>', \$buffer or die "Could not open in-memory buffer";
    *STDERR = $fh;

    my $sth = $dbi->prepare('insert into mock (id, name) values (?,?)');
    $sth->execute(1,'nekokak');

    like $buffer, qr/\[DBI::st\]  insert into mock \(id, name\) values \(\?,\?\) \(bind: 1, nekokak\) \(1 rows\)  |/;

    close $fh;
}

done_testing;

