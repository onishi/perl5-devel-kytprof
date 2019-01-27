requires 'Class::Data::Inheritable';
requires 'Module::Load';
requires 'Term::ANSIColor';
requires 'Time::HiRes';

on build => sub {
    requires 'ExtUtils::MakeMaker', '6.36';
};
