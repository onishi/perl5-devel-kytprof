package Devel::KYTProf::Profiler::DBI;

use strict;
use warnings;
use DBIx::Tracer;

sub apply {
    my $_last_sql;
    my $_last_binds;

    our $_tracer = DBIx::Tracer->new(sub {
        my %args = @_;
        $_last_sql = $args{sql};
        $_last_binds = scalar(@{ $args{bind_parans} }) ? '(bind: '.join(', ', map { defined $_ ? $_ : 'undef' } @{ $args{bind_parans} }).')' : '';
    });

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
            my (undef, $sth) = @_;
            return [
                '%s %s (%d rows)',
                ['sql', 'sql_binds', 'rows'],
                {
                    sql       => $_last_sql,
                    sql_binds => $_last_binds,
                    rows      => $sth->rows,
                },
            ];
        }
    );
}

1;
