requires 'Class::Data::Lite';
requires 'Class::Inspector';
requires 'DBIx::Tracer';
requires 'Module::Load';
requires 'Term::ANSIColor';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
    requires 'perl', '5.008_001';
};

on test => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Requires';
};

on develop => sub {
    requires 'Cache::Memcached::Fast';
    requires 'DBD::SQLite';
    requires 'DBI';
    requires 'Test::Perl::Critic';
    requires 'Test::mysqld';
};
