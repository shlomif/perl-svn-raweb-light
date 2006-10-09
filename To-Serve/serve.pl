#!/usr/bin/perl -w

use strict;
use warnings;

use lib "../lib";

use SVN::RaWeb::Light;

my $app = SVN::RaWeb::Light->new(
    'url' => "http://localhost:8080/svn/repos/",
);

$app->run();

