use inc::Module::Install;
name 'Devel-KYTProf';
all_from 'lib/Devel/KYTProf.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
