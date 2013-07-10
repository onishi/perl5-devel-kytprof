requires 'Class::Data::Inheritable';
requires 'Term::ANSIColor';
requires 'Time::HiRes';
requires 'UNIVERSAL::require';

on build => sub {
    requires 'ExtUtils::MakeMaker', '6.36';
};
