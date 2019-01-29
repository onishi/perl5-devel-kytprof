package Devel::KYTProf::Profiler::DBI;

use strict;
use warnings;

sub apply {
    Devel::KYTProf->add_prof(
        'DBI',
        'connect',
        sub {
            my ($orig, $class, $dsn, $user, $pass, $attr) = @_;
            return [
                '%s %s',
                ['dbi_connect_method', 'dsn'],
                {
                    dbi_connect_method => $attr->{dbi_connect_method} || 'connect',
                    dsn => $dsn,
                },
            ];
        }
    );
    Devel::KYTProf->add_prof(
        'DBI::st',
        'execute',
        sub {
            my ($orig, $sth, @binds) = @_;
            my $sql = $sth->{Database}->{Statement};
            my $bind_info = scalar(@binds) ? '(bind: '.join(', ', map { defined $_ ? $_ : 'undef' } @binds).')' : '';
            return [
                '%s %s (%d rows)',
                ['sql', 'sql_binds', 'rows'],
                {
                    sql => $sql,
                    sql_binds => $bind_info,
                    rows => $sth->rows,
                },
            ];
        }
    );
}

1;
