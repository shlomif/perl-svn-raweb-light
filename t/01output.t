#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 1;

# We need to load the mocking modules first because they fill the 
# namespaces and %INC. Otherwise, "use CGI" and "use SVN::*" will cause
# the real modules to be loaded.
use SVN::RaWeb::Light::Mock::CGI;
use SVN::RaWeb::Light::Mock::Svn;

use SVN::RaWeb::Light;

{
    @CGI::new_params = ('path_info' => "");

    my $svn_ra_web = SVN::RaWeb::Light->new('url' => "http://svn-non-existentent.shlomifish.org/svn/myrepos");

    # TEST
    ok($svn_ra_web, "Object Initialization Succeeded");
    $svn_ra_web->run();
}

1;

