#!/usr/bin/perl -w

use strict;
use warnings;

use lib "../lib";

use SVN::RaWeb::Light;

my $app = SVN::RaWeb::Light->new(
    'url' => "svn://svn.berlios.de/web-cpan/",
    'url_translations' => 
    [
        {
            'label' => "Read/Write URL",
            'url' => "svn+ssh://svn.berlios.de/svnroot/repos/web-cpan/",
        },
        {
            'label' => "Read URL",
            'url' => "svn://svn.berlios.de/web-cpan/",
        },
    ],
);

$app->run();

