use strict;
use Test::More;
use Test::Requires 'Test::Perl::Critic';

Test::Perl::Critic->import( -profile => 'xt/perlcriticrc');
all_critic_ok('lib');
