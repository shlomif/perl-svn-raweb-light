#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 14;

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

    my $svn_ra_web = SVN::RaWeb::Light->new('url' => "http://svn-i.shlomifish.org/svn/myrepos/");

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

# Check that if no url translations are specified then, they are empty.
{
    @CGI::new_params = ('path_info' => "/trunk/build.txt");

    reset_out_buffer();

    my $svn_ra_web = SVN::RaWeb::Light->new('url' => "http://svn-i.shlomifish.org/svn/myrepos/");

    my $url_trans = $svn_ra_web->get_url_translations();

    # TEST
    is (ref($url_trans), "ARRAY", 
        "Checking for url_trans being proper array reference");
    # TEST
    ok ((scalar(@$url_trans) == 0), "Checking for url_trans being empty array");
}

# Check that if no url translations are specified then, they are empty.
{
    @CGI::new_params = ('path_info' => "/trunk/build.txt");

    reset_out_buffer();

    my $svn_ra_web = 
        SVN::RaWeb::Light->new(
            'url' => "http://svn-i.shlomifish.org/svn/myrepos/",
            'url_translations' =>
            [
                {
                    'url' => "svn://svn-i.nodomain.foo/hello/",
                    'label' => "nodomain",
                },
                {
                    'url' => "file:///home/shlomi/svn/foo/",
                    'label' => "myfile",
                },
            ],
        );

    my $url_trans = $svn_ra_web->get_url_translations();

    # TEST
    is (ref($url_trans), "ARRAY", 
        "Checking for url_trans being proper array reference");
    # TEST
    is_deeply(
        $url_trans, 
        [
            {
                'url' => "svn://svn-i.nodomain.foo/hello/",
                'label' => "nodomain",
            },
            {
                'url' => "file:///home/shlomi/svn/foo/",
                'label' => "myfile",
            },
        ],
        "Checking for url_trans being correct"
    );
}

# Unit tests for calc_rev_num()

{
    @CGI::new_params = 
    (
        'path_info' => "/trunk/build.txt", 
        'params' =>
        {
            'rev' => "600",
        },
        'query_string' => "rev=600",
    );

    reset_out_buffer();

    my $svn_ra_web = 
        SVN::RaWeb::Light->new(
            'url' => "http://svn-i.shlomifish.org/svn/myrepos/",
        );

    $svn_ra_web->calc_rev_num();

    # TEST
    is($svn_ra_web->rev_num(), "600", 
        "Checking for validity of rev_num() when it's explicitly speicified"
    );

    # TEST
    is($svn_ra_web->url_suffix(), "?rev=600", 
        "Checking for url_suffix() when rev is speicified"
    );
}

{
    @CGI::new_params = 
    (
        'path_info' => "/trunk/build.txt", 
    );

    @SVN::Ra::new_params =
    (
        'get_latest_revnum' => sub { return 5267; },
    );

    reset_out_buffer();

    my $svn_ra_web = 
        SVN::RaWeb::Light->new(
            'url' => "http://svn-i.shlomifish.org/svn/myrepos/",
        );

    $svn_ra_web->calc_rev_num();

    # TEST
    is($svn_ra_web->rev_num(), "5267",
        "Checking rev_num() when it isn't specified"
    );

    # TEST
    is($svn_ra_web->url_suffix(), "", 
        "Checking url_suffix() when rev isn't speicified"
    );
}

{
    @CGI::new_params = 
    (
        'path_info' => "/trunk/build.txt", 
    );

    reset_out_buffer();

    my $svn_ra_web = 
        SVN::RaWeb::Light->new(
            'url' => "http://svn-i.shlomifish.org/svn/myrepos/",
        );

    $svn_ra_web->calc_path();

    # TEST
    is($svn_ra_web->path(), "trunk/build.txt",
        "Checking path()"
    );

    # TEST
    ok((!$svn_ra_web->should_be_dir()), "Checking should_be_dir()");
}

{
    @CGI::new_params = 
    (
        'path_info' => "/trunk/src/perl/", 
    );

    reset_out_buffer();

    my $svn_ra_web = 
        SVN::RaWeb::Light->new(
            'url' => "http://svn-i.shlomifish.org/svn/myrepos/",
        );

    $svn_ra_web->calc_path();

    # TEST
    is($svn_ra_web->path(), "trunk/src/perl",
        "Checking path()"
    );

    # TEST
    ok($svn_ra_web->should_be_dir(), "Checking should_be_dir()");
}

# Unit tests for calc_rev_num()

# Checking that url_suffix() is valid if rev is not specified, but 
# query_string is not empty.
{
    @CGI::new_params = 
    (
        'path_info' => "/trunk/build.txt", 
        'params' =>
        {
            'trans_hide_all' => 1,
        },
        'query_string' => "trans_hide_all=1",
    );

    reset_out_buffer();

    my $svn_ra_web = 
        SVN::RaWeb::Light->new(
            'url' => "http://svn-i.shlomifish.org/svn/myrepos/",
        );

    $svn_ra_web->calc_rev_num();

    # TEST
    is($svn_ra_web->url_suffix(), "?trans_hide_all=1", 
        "Checking for url_suffix() when rev is speicified"
    );
}

