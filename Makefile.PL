use ExtUtils::MakeMaker;

open O, ">", "lib/SVN/RaWeb/Light/Help.pm";
print O <<'EOF';
package SVN::RaWeb::Light::Help;

sub print_data
{
    local $/;
    print <DATA>;
}

1;
EOF

print O "__DATA__\n";

{
    local $/;
    open I, "<", "docs/Help.html";
    print O <I>;
    close(I);
}
close(O);

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'SVN::RaWeb::Light',
    VERSION_FROM      => 'lib/SVN/RaWeb/Light.pm', # finds $VERSION
    PREREQ_PM         => 
        {
            'SVN::Ra' => 0,
            'CGI' => 0,
            'IO::Scalar' => 0,
            'Class::Accessor' => 0,
            'Test::More' => 0,
        }, # e.g., Module::Name => 1.1
    ABSTRACT_FROM  => 'lib/SVN/RaWeb/Light.pm', # retrieve abstract from module
    AUTHOR         => 'Shlomi Fish <shlomif@iglu.org.il>',
);

