use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Language::XSB::Converter',
    'VERSION_FROM'	=> 'Converter.pm', # finds $VERSION
    'PREREQ_PM'		=> { 'Language::Prolog::Types' => 0, },
    'ABSTRACT_FROM'     => 'Converter.pm', # retrieve abstract from module
    'AUTHOR'            => 'Salvador Fandiño <sfandino@yahoo.com>',
);
