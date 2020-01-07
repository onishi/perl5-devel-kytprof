use strict;
use warnings;
use Test::More;
use Test::Requires 'DBI', 'Test::mysqld';

use Devel::KYTProf;
local $ENV{ANSI_COLORS_DISABLED} = 1;

sub prof(&) {
    my $code = shift;
    my $buffer = '';
    open my $fh, '>', \$buffer or die "Could not open in-memory buffer";
    local *STDERR = $fh;
    $code->();
    close $fh;
    $buffer;
}

Devel::KYTProf->mute($_) for qw/DBI DBI::st DBI::db/;
my $mysqld = Test::mysqld->new(
    my_cnf => {
        'skip-networking' => '',
    },
) or plan skip_all => $Test::mysqld::errstr;

my $dbh = DBI->connect($mysqld->dsn);
Devel::KYTProf->unmute($_) for qw/DBI DBI::st DBI::db/;

like
    prof { $dbh->do(q{CREATE TABLE mock (id INTEGER, name TEXT, PRIMARY KEY ( id ))}) },
    qr/\[DBI::db\]  \(db:dbname=test;mysql_socket=[^)]+\) CREATE TABLE mock \(id INTEGER, name TEXT, PRIMARY KEY \( id \)\)   \|/;

Devel::KYTProf->mute($_) for qw/DBI DBI::st DBI::db/;
my $sth = $dbh->prepare('INSERT INTO mock (id, name) VALUES (?,?)');
$sth->execute(1, 'nekokak');
$sth->execute(2, 'charsbar');
$sth->execute(3, 'tokuhirom');
$sth->execute(4, 'miyagawa');
$sth->execute(5, 'yappo');
$sth->execute(6, 'kazuho');
Devel::KYTProf->unmute($_) for qw/DBI DBI::st DBI::db/;

like
    prof { $dbh->selectrow_array('SELECT * FROM mock WHERE id = ?', undef, 1) },
    qr/\[DBI::db\]  \(db:dbname=test;mysql_socket=[^)]+\) SELECT \* FROM mock WHERE id = \? \(bind: 1\)  \|/;

like
    prof { $dbh->selectrow_arrayref('SELECT * FROM mock WHERE id = ?', undef, 2) },
    qr/\[DBI::db\]  \(db:dbname=test;mysql_socket=[^)]+\) SELECT \* FROM mock WHERE id = \? \(bind: 2\)  \|/;

like
    prof { $dbh->selectrow_hashref('SELECT * FROM mock WHERE id = ?', undef, 3) },
    qr/\[DBI::st\]  \(db:dbname=test;mysql_socket=[^)]+\) SELECT \* FROM mock WHERE id = \? \(bind: 3\) \(1 rows\)  \|/;

like
    prof { $dbh->selectall_arrayref('SELECT * FROM mock WHERE id = ?', undef, 4) },
    qr/\[DBI::db\]  \(db:dbname=test;mysql_socket=[^)]+\) SELECT \* FROM mock WHERE id = \? \(bind: 4\)  \|/;

like
    prof { $dbh->selectall_hashref('SELECT * FROM mock WHERE id = ?', 'id', undef, 5) },
    qr/\[DBI::st\]  \(db:dbname=test;mysql_socket=[^)]+\) SELECT \* FROM mock WHERE id = \? \(bind: 5\) \(1 rows\)  \|/;

like
    prof { $dbh->selectcol_arrayref('SELECT id, name FROM mock WHERE id = ?', undef, 6) },
    qr/\[DBI::st\]  \(db:dbname=test;mysql_socket=[^)]+\) SELECT id, name FROM mock WHERE id = \? \(bind: 6\) \(1 rows\)  \|/;

done_testing;
