#!/usr/bin/perl -w

use strict;
use warnings;

use lib "../lib";

use SVN::RaWeb::Light;

my $app = SVN::RaWeb::Light->new(
    'url' => "svn://svn.berlios.de/fc-solve/",
    'url_translations' => 
    [
        {
            'label' => "Read/Write URL",
            'url' => "svn+ssh://svn.berlios.de/svnroot/repos/fc-solve/",
        },
        {
            'label' => "Read URL",
            'url' => "svn://svn.berlios.de/fc-solve/",
        },
    ],
);

$app->run();

