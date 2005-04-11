#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 6;

# We need to load the mocking modules first because they fill the 
# namespaces and %INC. Otherwise, "use CGI" and "use SVN::*" will cause
# the real modules to be loaded.
use SVN::RaWeb::Light::Mock::CGI;
use SVN::RaWeb::Light::Mock::Svn;
use SVN::RaWeb::Light::Mock::Stdout;

use SVN::RaWeb::Light;

{
    @CGI::new_params = ('path_info' => "");

    reset_out_buffer();

    my $svn_ra_web = SVN::RaWeb::Light->new('url' => "http://svn-i.shlomifish.org/svn/myrepos");

    # TEST
    ok($svn_ra_web, "Object Initialization Succeeded");
    $svn_ra_web->run();
}

# Checking for multiple adjacent slashes.
{
    @CGI::new_params = ('path_info' => "/hello//you/");

    reset_out_buffer();

    my $svn_ra_web = SVN::RaWeb::Light->new('url' => "http://svn-i.shlomifish.org/svn/myrepos");

    $svn_ra_web->run();

    my $results = get_out_buffer();

    # TEST
    ok(($results =~ /Wrong URL/), "Testing for result on multiple adjacent slashes");
    # TEST
    ok (($results =~ /Multiple Adjacent Slashes/), "Testing for result on multiple adjacent slashes");
}

{
    local @CGI::new_params = ('path_info' => "/trunk/src/");

    local @SVN::Ra::new_params =
    (
        'check_path' => sub {
            my ($self, $path, $rev_num) = @_;
            if ($path eq "trunk/src")
            {
                return $SVN::Node::file;
            }
            die "Wrong path queried - $path.";
        },
    );
    reset_out_buffer();

    my $svn_ra_web = 
        SVN::RaWeb::Light->new(
            'url' => "http://svn-i.shlomifish.org/svn/myrepos/"
        );

    eval {
    $svn_ra_web->run();
    };

    my $exception = $@;

    # TEST
    ok($exception, "Testing that an exception was thrown.");
    # TEST
    is($exception->{'type'}, "redirect", "Excpecting type redirect");
    # TEST
    is($exception->{'redirect_to'}, "../src", "Right redirect URL");
}

1;

