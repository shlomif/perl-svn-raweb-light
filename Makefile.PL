use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'SVN::RaWeb::Light',
    VERSION_FROM      => 'lib/SVN/RaWeb/Light.pm', # finds $VERSION
    PREREQ_PM         => 
        {
            'SVN::Ra' => 0,
            'CGI' => 0,
        }, # e.g., Module::Name => 1.1
    ABSTRACT_FROM  => 'lib/SVN/RaWeb/Light.pm', # retrieve abstract from module
    AUTHOR         => 'Shlomi Fish <shlomif@iglu.org.il>',
);

