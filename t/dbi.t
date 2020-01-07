use strict;
use warnings;
use Test::More;
use Devel::KYTProf;
use Devel::KYTProf; # test for multiple applied problem

use Test::Requires 'DBI', 'DBD::SQLite';

local $ENV{ANSI_COLORS_DISABLED} = 1;

my $buffer = '';
open my $fh, '>', \$buffer or die "Could not open in-memory buffer";
*STDERR = $fh;

my $dbi = DBI->connect('dbi:SQLite:testdb','','');

$dbi->do(q{create table mock (id integer, name text, primary key ( id ))});

close $fh;

{
    my $buffer = '';
    open my $fh, '>', \$buffer or die "Could not open in-memory buffer";
    *STDERR = $fh;

    my $sth = $dbi->prepare('insert into mock (id, name) values (?,?)');
    $sth->execute(1,'nekokak');

    like $buffer, qr/\[DBI::st\]  \(db:testdb\) insert into mock \(id, name\) values \(\?,\?\) \(bind: 1, nekokak\) \(1 rows\)  \|/;

    close $fh;
}

{
    my $buffer = '';
    open my $fh, '>', \$buffer or die "Could not open in-memory buffer";
    *STDERR = $fh;

    my $sth = $dbi->prepare('insert into mock (id, name) values (?,?)');
    $sth->bind_param(1, 2);
    $sth->bind_param(2, 'onishi');
    $sth->execute;

    like $buffer, qr/\[DBI::st\]  \(db:testdb\) insert into mock \(id, name\) values \(\?,\?\) \(bind: 2, onishi\) \(1 rows\)  \|/;

    close $fh;
}

done_testing;

