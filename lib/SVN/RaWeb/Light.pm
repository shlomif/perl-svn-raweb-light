package SVN::RaWeb::Light;

use strict;
use warnings;

use vars qw($VERSION);

$VERSION = '0.5.6_00';

use CGI;
use IO::Scalar;

require SVN::Core;
require SVN::Ra;

use base 'Class::Accessor';

__PACKAGE__->mk_accessors(qw(cgi path rev_num should_be_dir svn_ra url_suffix));

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
    $self->cgi($cgi);

    my $svn_ra =
        SVN::Ra->new(
            'url' => $args{'url'},
        );

    $self->svn_ra($svn_ra);

    my $url_translations = $args{'url_translations'} || [];
    $self->{'url_translations'} = $url_translations;

    return $self;
}

sub get_user_url_translations
{
    my $self = shift;

    my @transes = $self->cgi()->param('trans_user');

    my @ret;
    for my $i (0 .. $#transes)
    {
        my $elem = $transes[$i];
        push @ret, 
            (($elem =~ /^([^:,]*),(.*)$/) ? 
                { 'label' => $1, 'url' => $2, } :
                { 'label' => ("UserDef" . ($i+1)), 'url' => $elem, }
            );
    }
    return \@ret;
}

# TODO :
# Create a way for the user to specify one extra url translation of his own.
sub get_url_translations
{
    my $self = shift;

    my (%args) = (@_);

    my $cgi = $self->cgi();

    my $is_list_item = $args{'is_list_item'};

    if ($is_list_item && $cgi->param('trans_no_list'))
    {
        return [];
    }

    return [
        ($cgi->param('trans_hide_all') ?
            () :
            (@{$self->{'url_translations'}})
        ),
        @{$self->get_user_url_translations()},
    ];
}

# This function must be called before rev_num() and url_suffix() are valid.
sub calc_rev_num
{
    my $self = shift;

    my $rev_param = $self->cgi()->param('rev');

    my ($rev_num, $url_suffix);

    # If a revision is specified - get the tree out of it, and persist with
    # it throughout the browsing session. Otherwise, get the latest revision.
    if (defined($rev_param))
    {
        $rev_num = abs(int($rev_param));
    }
    else
    {
        $rev_num = $self->svn_ra()->get_latest_revnum();
    }
    {
        my $query_string = $self->cgi->query_string();
        if ($query_string eq "")
        {
            $url_suffix = "";
        }
        else
        {
            $url_suffix = "?" . $query_string;
        }
    }
    
    $self->rev_num($rev_num);
    $self->url_suffix($url_suffix);
}

sub calc_path
{
    my $self = shift;

    my $path = $self->cgi()->path_info();
    if ($path eq "")
    {
        die +{
            'callback' =>
            sub {
                $self->cgi()->script_name() =~ m{([^/]+)$};
                print $self->cgi()->redirect("./$1/");
            },
        };
    }
    if ($path =~ /\/\//)
    {
        die +{ 'callback' => sub { $self->multi_slashes(); } };
    }

    $path =~ s!^/!!;

    $self->should_be_dir(($path eq "") || ($path =~ s{/$}{}));
    $self->path($path);
}

sub get_correct_node_kind
{
    my $self = shift;
    return $self->should_be_dir() ? $SVN::Node::dir : $SVN::Node::file;
}

sub check_node_kind
{
    my $self = shift;
    my $node_kind = shift;

    if (($node_kind eq $SVN::Node::none) || ($node_kind eq $SVN::Node::unknown))
    {
        die +{
            'callback' =>
                sub {
                    print $self->cgi()->header();
                    print "<html><head><title>Does not exist!</title></head>";
                    print "<body><h1>Does not exist!</h1></body></html>";
                },
        };        
    }
    elsif ($node_kind ne $self->get_correct_node_kind())
    {
        die +{
            'callback' =>
                sub {
                    $self->path() =~ m{([^/]+)$};
                    print $self->cgi()->redirect(
                        ($node_kind eq $SVN::Node::dir) ? 
                            "./$1/" :
                            "../$1"
                        );
                },
        };
    }
}

sub process_dir
{
    my $self = shift;
    my ($dir_contents, $fetched_rev) = 
        $self->svn_ra()->get_dir($self->path(), $self->rev_num());
    my $escaped_path = CGI::escapeHTML($self->path());
    my $title = "Revision ". $self->rev_num() . ": /" . 
        $escaped_path;
    print $self->cgi()->header();
    print "<html><head><title>$title</title></head>\n";
    print "<body>\n";
    print "<h2>$title</h2>\n";
    my $top_url_translations =
        $self->get_url_translations('is_list_item' => 0);
    my @escaped_item_url_translations =
        (map { 
            +{ 
                'url' => CGI::escapeHTML($_->{'url'}), 
                'label' => CGI::escapeHTML($_->{'label'}),
            }
            }
            @{$self->get_url_translations('is_list_item' => 1)}
        );
    if (@$top_url_translations)
    {
        print "<table border=\"1\">\n";
        foreach my $trans (@$top_url_translations)
        {
            my $url = $self->path();
            if ($url ne "")
            {
                $url .= "/";
            }
            
            my $escaped_url = CGI::escapeHTML($trans->{'url'} . $url);
            my $escaped_label = CGI::escapeHTML($trans->{'label'});
            print "<tr><td><a href=\"$escaped_url\">$escaped_label</a></td></tr>\n";
        }
        print "</table>\n";
    }
    print "<ul>\n";
    # If the path is the root - then we cannot have an upper directory
    if ($self->path() ne "")
    {
        $escaped_path =~ /^(.*?)[^\/]+$/;
        my $up_path = $1;
        print "<li><a href=\"../" . $self->url_suffix() . "\">..</a>" . 
                join("", map 
                    { 
                        " [<a href=\"" . $_->{'url'} . 
                        "$up_path\">". 
                        $_->{'label'} . 
                        "</a>]" 
                    }
                @escaped_item_url_translations) . 
                "</li>\n";
    }
    print map { my $escaped_name = CGI::escapeHTML($_); 
        if ($dir_contents->{$_}->kind() eq $SVN::Node::dir)
        {
            $escaped_name .= "/";
        }
        my $escaped_path_prefix = $escaped_path;
        if ($escaped_path_prefix ne "")
        {
            $escaped_path_prefix .= "/";
        }
        my $ret = "<li><a href=\"$escaped_name" . $self->url_suffix() . "\">$escaped_name</a>";
        $ret .= join("", map 
            { " [<a href=\"" . $_->{'url'} . 
                "$escaped_path_prefix$escaped_name\">". 
                $_->{'label'} . 
                "</a>]" 
            } 
            @escaped_item_url_translations);
        $ret .= "</li>\n";
        $ret;
        } sort { $a cmp $b } keys(%$dir_contents);
    print "</ul>\n";
    print "</body></html>\n";
}

sub process_file
{
    my $self = shift;

    my $buffer = "";
    my $fh = IO::Scalar->new(\$buffer);
    my ($fetched_rev, $props)
        = $self->svn_ra()->get_file($self->path(), $self->rev_num(), $fh);
    print $self->cgi()->header( 
        -type => ($props->{'svn:mime-type'} || 'text/plain')
        );
    print $buffer;
}

sub real_run
{
    my $self = shift;
    my $cgi = $self->cgi();
    $self->calc_rev_num();
    $self->calc_path();

    my $node_kind =
        $self->svn_ra()->check_path($self->path(), $self->rev_num());

    $self->check_node_kind($node_kind);

    if ($node_kind eq $SVN::Node::dir)
    {
        return $self->process_dir();
    }
    elsif ($node_kind eq $SVN::Node::file)
    {
        return $self->process_file();
    }
}

sub run
{
    my $self = shift;

    my @ret;
    eval {
        @ret = $self->real_run();
    };

    if ($@)
    {
        if ((ref($@) eq "HASH") && (exists($@->{'callback'})))
        {
            return $@->{'callback'}->();
        }
        else
        {
            die $@;
        }
    }
    else
    {
        return @ret;
    }
}

sub multi_slashes
{
    my $self = shift;
    print $self->cgi()->header();
    print "<html><head><title>Wrong URL!</title></head>";
    print "<body><h1>Wrong URL - Multiple Adjacent Slashes (//) in the URL." . 
        "</h1></body></html>";
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;


__END__


=head1 NAME

SVN::RaWeb::Light - Lightweight and Fast Browser for a URLed Subversion 
repository similar to the default Subversion http:// hosting.

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
Repository-Access layer. Its interface emulates that of the default
Subversion http://-interface, only with the improvement of a C<rev> CGI 
parameter to specify the revision of the repository.

To use it, install the module (using CPAN or by copying it to your path) and 
write the CGI script given in the SYNOPSIS with the URL to the repository 
passed as the C<'url'> parameter to the constructor.

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
