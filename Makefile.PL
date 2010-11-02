use inc::Module::Install;
name 'Devel-KYTProf';
all_from 'lib/Devel/KYTProf.pm';

requires 'Class::Data::Inheritable';
requires 'UNIVERSAL::require';
requires 'Time::HiRes';
requires 'Term::ANSIColor';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More' => '0.94';
auto_set_repository;
auto_include;
WriteAll;
