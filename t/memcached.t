use strict;
use warnings;
use Test::More;
use Devel::KYTProf;

use Test::Requires 'Cache::Memcached::Fast';

local $ENV{ANSI_COLORS_DISABLED} = 1;

my $memd = Cache::Memcached::Fast->new(
    {
        servers => [qw/127.0.0.1:11211/],
    }
);

unless (keys %{$memd->server_versions}) {
    plan skip_all => 'memcached server missing. skip testing';
}

my $buffer = '';
open my $fh, '>', \$buffer or die "Could not open in-memory buffer";
*STDERR = $fh;

$memd->incr('devel_kytprof_incr');
like $buffer, qr/\[Cache::Memcached::Fast\]  incr devel_kytprof_incr  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->decr('devel_kytprof_incr');
like $buffer, qr/\[Cache::Memcached::Fast\]  decr devel_kytprof_incr  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->incr_multi('devel_kytprof_incr',['devel_kytprof_incr2']);
like $buffer, qr/\[Cache::Memcached::Fast\]  incr_multi devel_kytprof_incr, devel_kytprof_incr2  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->decr_multi('devel_kytprof_incr',['devel_kytprof_incr2']);
like $buffer, qr/\[Cache::Memcached::Fast\]  decr_multi devel_kytprof_incr, devel_kytprof_incr2  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->set('devel_kytprof_set', 'set', 60);
like $buffer, qr/\[Cache::Memcached::Fast\]  set devel_kytprof_set  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->add('devel_kytprof_add', 'add', 60);
like $buffer, qr/\[Cache::Memcached::Fast\]  add devel_kytprof_add  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

my $ret = $memd->get('devel_kytprof_set');
like $buffer, qr/\[Cache::Memcached::Fast\]  get devel_kytprof_set  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

#$memd->cas('devel_kytprof_set', @$ret);
#like $buffer, qr/\[Cache::Memcached::Fast\]  cas devel_kytprof_set  |/;

#    seek(STDERR,0,0);
#    truncate(STDERR, 0);

$memd->gets('devel_kytprof_add');
like $buffer, qr/\[Cache::Memcached::Fast\]  gets devel_kytprof_add  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->prepend('devel_kytprof_add', 'prepend');
like $buffer, qr/\[Cache::Memcached::Fast\]  prepend devel_kytprof_add  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->append('devel_kytprof_add', 'append');
like $buffer, qr/\[Cache::Memcached::Fast\]  append devel_kytprof_add  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->replace('devel_kytprof_add', 'replace');
like $buffer, qr/\[Cache::Memcached::Fast\]  replace devel_kytprof_add  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->delete('devel_kytprof_add');
like $buffer, qr/\[Cache::Memcached::Fast\]  delete devel_kytprof_add  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->remove('devel_kytprof_set');
like $buffer, qr/\[Cache::Memcached::Fast\]  remove devel_kytprof_set  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->set_multi(
    ['devel_kytprof_set_multi1','set_multi1', 60],
    ['devel_kytprof_set_multi2','set_multi2', 60],
);
like $buffer, qr/\[Cache::Memcached::Fast\]  set_multi devel_kytprof_set_multi1, devel_kytprof_set_multi2  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->add_multi(
    ['devel_kytprof_add_multi1','add_multi1', 60],
    ['devel_kytprof_add_multi2','add_multi2', 60],
);
like $buffer, qr/\[Cache::Memcached::Fast\]  add_multi devel_kytprof_add_multi1, devel_kytprof_add_multi2  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->get_multi(qw/devel_kytprof_add_multi1 devel_kytprof_add_multi2/);
like $buffer, qr/\[Cache::Memcached::Fast\]  get_multi devel_kytprof_add_multi1, devel_kytprof_add_multi2  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->gets_multi(qw/devel_kytprof_set_multi1 devel_kytprof_set_multi2/);
like $buffer, qr/\[Cache::Memcached::Fast\]  gets_multi devel_kytprof_set_multi1, devel_kytprof_set_multi2  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->prepend_multi(
    ['devel_kytprof_set_multi1','prepend1'],
    ['devel_kytprof_set_multi2','prepend2']
);
like $buffer, qr/\[Cache::Memcached::Fast\]  prepend_multi devel_kytprof_set_multi1, devel_kytprof_set_multi2  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->append_multi(
    ['devel_kytprof_set_multi1','append1'],
    ['devel_kytprof_set_multi2','append2']
);
like $buffer, qr/\[Cache::Memcached::Fast\]  append_multi devel_kytprof_set_multi1, devel_kytprof_set_multi2  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

$memd->replace_multi(
    ['devel_kytprof_set_multi1','replace1'],
    ['devel_kytprof_set_multi2','replace2']
);
like $buffer, qr/\[Cache::Memcached::Fast\]  replace_multi devel_kytprof_set_multi1, devel_kytprof_set_multi2  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);
$memd->delete_multi(qw/devel_kytprof_set_multi1 devel_kytprof_set_multi2/);
like $buffer, qr/\[Cache::Memcached::Fast\]  delete_multi devel_kytprof_set_multi1, devel_kytprof_set_multi2  \|/;

    seek(STDERR,0,0);
    truncate(STDERR, 0);

close $fh;

done_testing;

