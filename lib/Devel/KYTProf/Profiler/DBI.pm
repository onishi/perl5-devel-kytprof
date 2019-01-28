package Devel::KYTProf::Profiler::DBI;

use strict;
use warnings;
use DBIx::Tracer;

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

    my $_last_sql;
    my $_last_binds;
    my $_in_prof;

    our $_tracer = DBIx::Tracer->new(sub {
        my %args = @_;
        $_last_sql = $args{sql};
        my $bind_params = $args{bind_params} || [];
        $_last_binds = scalar(@$bind_params) ? '(bind: '.join(', ', map { defined $_ ? $_ : 'undef' } @$bind_params).')' : '';
    });
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
        },
        sub { !$_in_prof },
    );

    Devel::KYTProf->add_profs(
        'DBI::db',
        [qw/do selectall_arrayref selectrow_arrayref selectrow_array/],
        sub {
            undef $_in_prof;
            return [
                '%s %s',
                ['sql', 'sql_binds'],
                {
                    sql       => $_last_sql,
                    sql_binds => $_last_binds,
                },
            ];
        },
        sub { $_in_prof = 1 },
    );
}

1;
