#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 1;

# We need to load the mocking modules first because they fill the 
# namespaces and %INC. Otherwise, "use CGI" and "use SVN::*" will cause
# the real modules to be loaded.
use SVN::RaWeb::Light::Mock::CGI;
use SVN::RaWeb::Light::Mock::Svn;
use SVN::RaWeb::Light::Mock::Stdout;

use SVN::RaWeb::Light;

{
    @CGI::new_params = ('path_info' => "/trunk///build.txt");

    reset_out_buffer();

    my $svn_ra_web = SVN::RaWeb::Light->new('url' => "http://svn-i.shlomifish.org/svn/myrepos");

    $svn_ra_web->multi_slashes();

    my $results = get_out_buffer();

    # TEST
    is($results, ("Content-Type: text/html\n\n" . 
        "<html><head><title>Wrong URL!</title></head>" . 
        "<body><h1>Wrong URL - Multiple Adjacent Slashes (//) in the URL." . 
        "</h1></body></html>"), 
        "Checking validity of multi_slashes()"
    );
}
