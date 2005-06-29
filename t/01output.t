#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 23;

# We need to load the mocking modules first because they fill the 
# namespaces and %INC. Otherwise, "use CGI" and "use SVN::*" will cause
# the real modules to be loaded.
use SVN::RaWeb::Light::Mock::CGI;
use SVN::RaWeb::Light::Mock::Svn;
use SVN::RaWeb::Light::Mock::Stdout;

use SVN::RaWeb::Light;

{
    @CGI::new_params = ('path_info' => "/trunk/hello/");

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
# TODO: check with url_translations.
# TODO: check for file output with a defualt mime type of text/plain.
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

# Test the directory output for the root directory
{
    local @CGI::new_params = ('path_info' => "/");

    local @SVN::Ra::new_params =
    (
        'get_latest_revnum' => sub {
            return 10900;
        },
        'check_path' => sub {
            my ($self, $path, $rev_num) = @_;
            if ($path eq "")
            {
                return $SVN::Node::dir;
            }
            die "Wrong path queried - $path.";
        },
        'get_dir' => sub {
            my $self = shift;
            my $path = shift;
            my $rev_num = shift;

            if ($path ne "")
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
                    'yowza.txt' => 
                    { 
                        'kind' => $SVN::Node::file,
                    },
                    'the-directory' =>
                    {
                        'kind' => $SVN::Node::dir,
                    },
                    'parser' =>
                    {
                        'kind' => $SVN::Node::file,
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
        "<html><head><title>Revision 10900: /</title></head>\n" .
        "<body>\n" .
        "<h2>Revision 10900: /</h2>\n" .
        "<ul>\n" .
        "<li><a href=\"parser\">parser</a></li>\n" .
        "<li><a href=\"the-directory/\">the-directory/</a></li>\n" .
        "<li><a href=\"yowza.txt\">yowza.txt</a></li>\n" .
        "</ul>\n".
        "</body></html>\n"),
        "Checking for valid output of a dir listing in root");
}

# Testing for a directory with a specified revision.
{
    local @CGI::new_params = 
    (
        'path_info' => "/trunk/subversion/", 
        'params' =>
        {
            'rev' => 150,
        },
    );

    local @SVN::Ra::new_params =
    (
        'get_latest_revnum' => sub {
            return 10900;
        },
        'check_path' => sub {
            my ($self, $path, $rev_num) = @_;
            if ($path eq "trunk/subversion")
            {
                return $SVN::Node::dir;
            }
            die "Wrong path queried - $path.";
        },
        'get_dir' => sub {
            my $self = shift;
            my $path = shift;
            my $rev_num = shift;

            if ($path ne "trunk/subversion")
            {
                die "Wrong Path - $path";
            }

            if ($rev_num != 150)
            {
                die "Wrong rev_num - $rev_num";
            }
    
            return 
            (
                {
                    'yowza.txt' => 
                    { 
                        'kind' => $SVN::Node::file,
                    },
                    'the-directory' =>
                    {
                        'kind' => $SVN::Node::dir,
                    },
                    'parser' =>
                    {
                        'kind' => $SVN::Node::file,
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

    $svn_ra_web->run();
    
    my $results = get_out_buffer();

    # TEST
    is($results, ("Content-Type: text/html\n\n" . 
        "<html><head><title>Revision 150: /trunk/subversion</title></head>\n" .
        "<body>\n" .
        "<h2>Revision 150: /trunk/subversion</h2>\n" .
        "<ul>\n" .
        "<li><a href=\"../?rev=150\">..</a></li>\n" .
        "<li><a href=\"parser?rev=150\">parser</a></li>\n" .
        "<li><a href=\"the-directory/?rev=150\">the-directory/</a></li>\n" .
        "<li><a href=\"yowza.txt?rev=150\">yowza.txt</a></li>\n" .
        "</ul>\n".
        "</body></html>\n"),
        "Checking for valid output of a dir listing in root");
}

# Checking the retrieving of a file.
{
    local @CGI::new_params = ('path_info' => "/trunk/mydir/myfile.txt");

    local @SVN::Ra::new_params =
    (
        'get_latest_revnum' => sub {
            return 10900;
        },
        'check_path' => sub {
            my ($self, $path, $rev_num) = @_;
            if ($path eq "trunk/mydir/myfile.txt")
            {
                return $SVN::Node::file;
            }
            die "Wrong path queried - $path.";
        },
        'get_file' => sub {
            my ($self, $path, $rev_num, $out_fh) = @_;
            if ($path ne "trunk/mydir/myfile.txt")
            {
                die "Wrong path - $path";
            }
            if ($rev_num != 10900)
            {
                die "Wrong revision - $rev_num";
            }
            print {$out_fh} "<html><body>\nTesting One tWO t|-||/33 - Subversion ownz.\n</body></html>";
            return (10900, { 'svn:mime-type' => "text/html", });
        },
    );
    reset_out_buffer();

    my $svn_ra_web =
        SVN::RaWeb::Light->new(
            'url' => "http://svn-i.shlomifish.org/svn/myrepos/"
        );

    $svn_ra_web->run();

    my $results = get_out_buffer();

    # TEST
    is($results, ("Content-Type: text/html\n\n" . 
        "<html><body>\nTesting One tWO t|-||/33 - " . 
        "Subversion ownz.\n</body></html>"),
        "Testing for get_file()"
    );
}


# Checking the retrieving of a file without a mime type.
{
    local @CGI::new_params = ('path_info' => "/trunk/mydir/myfile.txt");

    local @SVN::Ra::new_params =
    (
        'get_latest_revnum' => sub {
            return 10900;
        },
        'check_path' => sub {
            my ($self, $path, $rev_num) = @_;
            if ($path eq "trunk/mydir/myfile.txt")
            {
                return $SVN::Node::file;
            }
            die "Wrong path queried - $path.";
        },
        'get_file' => sub {
            my ($self, $path, $rev_num, $out_fh) = @_;
            if ($path ne "trunk/mydir/myfile.txt")
            {
                die "Wrong path - $path";
            }
            if ($rev_num != 10900)
            {
                die "Wrong revision - $rev_num";
            }
            print {$out_fh} "Yo, yo, yo!\nTime to get busy...\n";
            return (10900, {});
        },
    );
    reset_out_buffer();

    my $svn_ra_web =
        SVN::RaWeb::Light->new(
            'url' => "http://svn-i.shlomifish.org/svn/myrepos/"
        );

    $svn_ra_web->run();

    my $results = get_out_buffer();

    # TEST
    is($results, ("Content-Type: text/plain\n\n" . 
        "Yo, yo, yo!\nTime to get busy...\n"),
        "Checking for retrieving a file with no mime type."
    );
}

# Check that if the script is hosted at http://myhost.foo/serve.pl, and the
# URL accessed is "http://myhost.foo/serve.pl" then it should redirect to 
# http://myhost.foo/serve.pl/.
{
    local @CGI::new_params = 
    (
        'path_info' => "",
        'script_name' => "/cgi-bin/shlomi/serve-67jyumber200.pl",
    );

    local @SVN::Ra::new_params =
    (
        'get_latest_revnum' => sub {
            return 10900;
        },
        'check_path' => sub {
            my ($self, $path, $rev_num) = @_;
            if ($path eq "trunk/mydir/myfile.txt")
            {
                return $SVN::Node::file;
            }
            die "Wrong path queried - $path.";
        },
        'get_file' => sub {
            my ($self, $path, $rev_num, $out_fh) = @_;
            if ($path ne "trunk/mydir/myfile.txt")
            {
                die "Wrong path - $path";
            }
            if ($rev_num != 10900)
            {
                die "Wrong revision - $rev_num";
            }
            print {$out_fh} "Yo, yo, yo!\nTime to get busy...\n";
            return (10900, {});
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
    ok($exception, "Checking for exception");
    # TEST
    is($exception->{'type'}, "redirect", "Excpecting type redirect");
    # TEST
    is($exception->{'redirect_to'}, "./serve-67jyumber200.pl/", 
        "Right redirect URL");
}

# Check for url_translations of a regular (non-root) directory.
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
            'url' => "http://svn-i.shlomifish.org/svn/myrepos/",
            'url_translations' =>
            [
                {
                    'label' => "Read-Only",
                    'url' => "svn://svn.myhost.mytld/hello/there/",
                },
                {
                    'label' => "Write",
                    'url' => "svn+ssh://svnwrite.myhost.mytld/root/myroot/",
                },
            ],
        );

    eval {
    $svn_ra_web->run();
    };

    # TEST
    ok(!$@, "Testing that no exception was thrown.");
    
    my $results = get_out_buffer();

    # TEST
    is_deeply([split(/\n/, $results)], [(split /\n/, <<"EOF")]
Content-Type: text/html

<html><head><title>Revision 10900: /trunk/mydir</title></head>
<body>
<h2>Revision 10900: /trunk/mydir</h2>
<table border=\"1\">
<tr><td><a href=\"svn://svn.myhost.mytld/hello/there/trunk/mydir/\">Read-Only</a></td></tr>
<tr><td><a href=\"svn+ssh://svnwrite.myhost.mytld/root/myroot/trunk/mydir/\">Write</a></td></tr>
</table>
<ul>
<li><a href=\"../\">..</a> [<a href="svn://svn.myhost.mytld/hello/there/trunk/">Read-Only</a>] [<a href="svn+ssh://svnwrite.myhost.mytld/root/myroot/trunk/">Write</a>]</li>
<li><a href=\"hello.pm\">hello.pm</a> [<a href="svn://svn.myhost.mytld/hello/there/trunk/mydir/hello.pm">Read-Only</a>] [<a href="svn+ssh://svnwrite.myhost.mytld/root/myroot/trunk/mydir/hello.pm">Write</a>]</li>
<li><a href=\"mydir/\">mydir/</a> [<a href="svn://svn.myhost.mytld/hello/there/trunk/mydir/mydir/">Read-Only</a>] [<a href="svn+ssh://svnwrite.myhost.mytld/root/myroot/trunk/mydir/mydir/">Write</a>]</li>
</ul>
</body></html>
EOF
    , "Checking for valid output of a dir listing");        
}
1;

