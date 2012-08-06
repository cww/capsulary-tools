use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Capsulary::Tools',
    AUTHOR              => q{Colin Wetherbee <cww@cpan.org>},
    VERSION_FROM        => 'lib/Capsulary/Tools.pm',
    ABSTRACT_FROM       => 'lib/Capsulary/Tools.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'mit')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Carp' => '1.11',
        'common::sense' => '3.3',
        'DBI' => '1.612',
        'Digest::MD5' => '2.51',
        'FindBin' => '1.50',
        'Getopt::Long' => '2.38',
        'JSON::PP' => '2.27200',
        'Log::Log4perl' => '1.36',
        'Redis' => '1.951',
        'Test::More' => '0.98',
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Capsulary-Tools-*' },
);
