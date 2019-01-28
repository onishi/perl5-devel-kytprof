requires 'Class::Data::Lite';
requires 'Class::Inspector';
requires 'DBIx::Tracer';
requires 'Module::Load';
requires 'Term::ANSIColor';
requires 'Time::HiRes';

on build => sub {
    requires 'ExtUtils::MakeMaker', '6.36';
};
