package SVN::RaWeb::Light;

use strict;
use warnings;

use vars qw($VERSION);

$VERSION = '0.2.0';

use CGI;

require SVN::Core;
require SVN::Ra;

# Preloaded methods go here.

sub new
{
    my $self = {};
    my $class = shift;
    bless $self, $class;
    $self->initialize(@_);
    return $self;
}

sub initialize
{
    my $self = shift;
    
    my %args = (@_);
    
    my $cgi = CGI->new();
    $self->{'cgi'} = $cgi;

    my $svn_ra =
        SVN::Ra->new(
            'url' => $args{'url'},
        );

    $self->{'svn_ra'} = $svn_ra;

    return $self;
}

sub run
{
    my $self = shift;
    my $cgi = $self->{'cgi'};
    my $svn_ra = $self->{'svn_ra'};
    my $path_info = $cgi->path_info();
    my $path = $path_info;
    if ($path =~ /\/\//)
    {
        return $self->multi_slashes();
    }

    $path =~ s!^/!!;
    my $should_be_dir = (($path eq "") || ($path =~ s{/$}{}));

    my $latest_rev = $svn_ra->get_latest_revnum();

    my $rev_num = (abs(int($cgi->param('rev'))) || $latest_rev);

    my $url_suffix = (($rev_num == $latest_rev) ? "" : "?rev=$rev_num");

    my $node_kind = $svn_ra->check_path($path, $rev_num);

    if ($node_kind eq $SVN::Node::dir)
    {
        if (! $should_be_dir)
        {
            $path =~ m{([^/]+)$};
            print $cgi->redirect("./$1/");
            return;
        }
        my ($dir_contents, $fetched_rev) = $svn_ra->get_dir($path, $rev_num);
        my $title = "Revision $rev_num: /" . CGI::escapeHTML($path);
        print $cgi->header();
        print "<html><head><title>$title</title></head>\n";
        print "<body>\n";
        print "<h2>$title</h2>\n";
        print "<ul>\n";
        print "<li><a href=\"../$url_suffix\">..</a></li>\n";
        print map { my $escaped_name = CGI::escapeHTML($_); 
            if ($dir_contents->{$_}->kind() eq $SVN::Node::dir)
            {
                $escaped_name .= "/";
            }
            "<li><a href=\"$escaped_name$url_suffix\">$escaped_name</a></li>\n"
            } sort { $a cmp $b } keys(%$dir_contents);
        print "</ul>\n";
        print "</body></html>\n";
    }
    elsif ($node_kind eq $SVN::Node::file)
    {
        if ($should_be_dir)
        {
            $path =~ m{([^/]+)$};
            print $cgi->redirect("../$1");
            return;
        }
        
        my $buffer = "";
        open my $fh, ">", \$buffer;
        my ($fetched_rev, $props)
            = $svn_ra->get_file($path, $rev_num, $fh);
        print $cgi->header( 
            -type => ($props->{'svn:mime-type'} || 'text/plain')
            );
        print $buffer;
        close($fh);
    }
    else
    {
        print $cgi->header();
        print "<html><head><title>Does not exist!</title></head>";
        print "<body><h1>Does not exist!</h1></body></html>";
    }
}

sub multi_slashes
{
    my $self = shift;
    my $cgi = $self->{'cgi'};
    print $cgi->header();
    print "<html><head><title>Wrong URL!</title></head>";
    print "<body><h1>Wrong URL - Multiple Slashes in the URL." . 
        "</h1></body></html>";
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;


__END__


=head1 NAME

SVN::RaWeb::Light - Lightweight and Fast Browser for a URLed Subversion 
repository.

=head1 SYNOPSIS

    #!/usr/bin/perl

    use SVN::RaWeb::Light;

    my $app = SVN::RaWeb::Light->new(
        'url' => "svn://myhost.net/my-repos-path/",
    );

    $app->run();

=head1 DESCRIPTION

SVN::RaWeb::Light is a class implementing a CGI script for browsing
a Subversion repository given as a URL, and accessed through the Subversion
Repository-Access layer. To use it, install the module (using CPAN or by
copying it to your path) and write the CGI script given in the SYNOPSIS
with the URL to the repository passed as the C<'url'> parameter to 
the constructor.

To use it just fire up a web-browser to the URL of the script. Note that
you can pass the rev CGI parameter to designate a revision of the repository
to browse instead of HEAD. This rev will be preserved to subsequent URLs
that you browse. For example:

    http://www.myhost.net/ra-web-light/web-cpan/trunk/?rev=20
 
will browse the trunk in revision 20.

=head1 AUTHOR

Shlomi Fish, E<lt>shlomif@iglu.org.ilE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Shlomi Fish

This library is free software; you can redistribute it and/or modify
it under the terms of the MIT/X11 license.

=cut
