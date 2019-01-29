package Devel::KYTProf::Profiler::MogileFS::Client;

use strict;
use warnings;

sub apply {
    Devel::KYTProf->add_profs(
        'MogileFS::Client',
        [qw{
            edit_file
            read_file
            store_file
            store_content
            get_paths
            get_file_data
            delete
            rename
        }],
    );
}

1;
