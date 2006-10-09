use strict;
use warnings;

use File::Spec;
use lib File::Spec->catdir(File::Spec->curdir(), "inc");

use Test::Run::Builder;
use SVN::RaWeb::Light::GenHelp;

_gen_help();

my $build = Test::Run::Builder->new(
    module_name => 'SVN::RaWeb::Light',
    dist_version_from => 'lib/SVN/RaWeb/Light.pm', # finds $VERSION
    requires =>
    {
        'SVN::Ra' => 0,
        'CGI' => 0,
        'IO::Scalar' => 0,
        'Class::Accessor' => 0,
        'Test::More' => 0,
    },
    license => "bsd",
    dist_author => 'Shlomi Fish <shlomif@iglu.org.il>',
);

$build->create_build_script;

