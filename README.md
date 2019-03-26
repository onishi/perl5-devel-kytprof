[![Build Status](https://travis-ci.org/onishi/perl5-devel-kytprof.svg?branch=master)](https://travis-ci.org/onishi/perl5-devel-kytprof)
# NAME

Devel::KYTProf - Simple profiler

# SYNOPSIS

```perl
use Devel::KYTProf;

# your code ( including DBI, LWP )
```

# DESCRIPTION

Devel::KYTProf is a perl code profiler to explore IO blocking time.

```perl
use Devel::KYTProf;

# your code ( including DBI, LWP )
```

Output as follows.

```
315.837 ms [DBI::st] select * from table where name = ? (1 rows) | main:23
1464.204 ms [LWP::UserAgent] GET http://www.hatena.ne.jp/ | main:25
```

You can add profiler to any method.

```
Devel::KYTProf->add_prof($module, $method, [$callback, $sampler]);
Devel::KYTProf->add_profs($module, $methods, [$callback, $sampler]);
Devel::KYTProf->add_profs($module, ':all', [$callback, $sampler]);
```

The `$sampler` is still an experimental feature.

You can specify profiler packages.

```
Devel::KYTProf->apply_prof($pkg, [$prof_pkg, @args]);
```

You can change settings.

```
Devel::KYTProf->namespace_regex();
Devel::KYTProf->ignore_class_regex();
Devel::KYTProf->context_classes_regex();
Devel::KYTProf->logger($logger);
Devel::KYTProf->threshold(100); # ms
Devel::KYTProf->mute($module, $method);
Devel::KYTProf->unmute($module, $method);
Devel::KYTProf->remove_linefeed(1);
Devel::KYTProf->remove_escape_sequences(1);
```

# AUTHOR

Yasuhiro Onishi <yasuhiro.onishi@gmail.com>

# SEE ALSO

- [DBI](https://metacpan.org/pod/DBI)
- [LWP::UserAgent](https://metacpan.org/pod/LWP::UserAgent)
- [Cache::Memcached::Fast](https://metacpan.org/pod/Cache::Memcached::Fast)

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
