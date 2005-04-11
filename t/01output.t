#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 13;

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

# Testing redirect from a supposed directory to a file.
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

# Testing redirect from supposed file to a directory with the same name
{
    local @CGI::new_params = ('path_info' => "/trunk/src.txt");

    local @SVN::Ra::new_params =
    (
        'check_path' => sub {
            my ($self, $path, $rev_num) = @_;
            if ($path eq "trunk/src.txt")
            {
                return $SVN::Node::dir;
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
    is($exception->{'redirect_to'}, "./src.txt/", "Right redirect URL");
}

{
    local @CGI::new_params = ('path_info' => "/trunk/not-exist");

    local @SVN::Ra::new_params =
    (
        'check_path' => sub {
            my ($self, $path, $rev_num) = @_;
            if ($path eq "trunk/not-exist")
            {
                return $SVN::Node::none;
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

    # TEST
    ok(!$@, "Testing that no exception was thrown.");
    
    my $results = get_out_buffer();

    # TEST
    is($results, ("Content-Type: text/html\n\n" . 
        "<html><head><title>Does not exist!</title></head>" . 
        "<body><h1>Does not exist!</h1></body></html>"),
        "Checking for correct results for non-existent file"
    );
}

# Test the directory output for a regular (non-root) directory.
# TODO: test for a root directory.
# TODO: test for a directory with a specified revision.
# TODO: check for file output
# TODO: check with url_translations.
{
    local @CGI::new_params = ('path_info' => "/trunk/mydir/");

    local @SVN::Ra::new_params =
    (
        'get_latest_revnum' => sub {
            return 10900;
        },
        'check_path' => sub {
            my ($self, $path, $rev_num) = @_;
            if ($path eq "trunk/mydir")
            {
                return $SVN::Node::dir;
            }
            die "Wrong path queried - $path.";
        },
        'get_dir' => sub {
            my $self = shift;
            my $path = shift;
            my $rev_num = shift;

            if ($path ne "trunk/mydir")
            {
                die "Wrong Path - $path";
            }

            if ($rev_num != 10900)
            {
                die "Wrong rev_num - $rev_num";
            }
    
            return 
            (
                {
                    'hello.pm' => 
                    { 
                        'kind' => $SVN::Node::file,
                    },
                    'mydir' =>
                    {
                        'kind' => $SVN::Node::dir,
                    },
                },
                $rev_num
            );
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

    # TEST
    ok(!$@, "Testing that no exception was thrown.");
    
    my $results = get_out_buffer();

    # TEST
    is($results, ("Content-Type: text/html\n\n" . 
        "<html><head><title>Revision 10900: /trunk/mydir</title></head>\n" .
        "<body>\n" .
        "<h2>Revision 10900: /trunk/mydir</h2>\n" .
        "<ul>\n" .
        "<li><a href=\"../\">..</a></li>\n" .
        "<li><a href=\"hello.pm\">hello.pm</a></li>\n" .
        "<li><a href=\"mydir/\">mydir/</a></li>\n" .
        "</ul>\n".
        "</body></html>\n"),
        "Checking for valid output of a dir listing");
        
}


1;

