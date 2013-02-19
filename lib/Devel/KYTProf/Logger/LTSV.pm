package Devel::KYTProf::Logger::LTSV;
use strict;
use warnings;

sub _escape ($) {
    my $s = $_[0];
    $s =~ s{([\x00-\x1F\x5C\x7F-\x9F])}{sprintf '\\%02X', ord $1}ge;
    return $s;
}

sub log {
    my ($class, %args) = @_;

    print join "\t", map { $_->[0] . ':' . _escape $_->[1] }
        [runtime => $args{time}],
        [operation_class => $args{module}],
        [operation_method => $args{method}],
        [caller_package => $args{package}],
        [caller_file_name => $args{file}],
        [caller_line => $args{line}],
        map { [$_ => $args{data}->{$_}] } keys %{$args{data}},
    ;
    print "\n";
}

1;
