package SVN::RaWeb::Light;

use strict;
use warnings;

use vars qw($VERSION);

$VERSION = '0.5.6_00';

use CGI ();
use IO::Scalar;

require SVN::Core;
require SVN::Ra;

use base 'Class::Accessor';

use SVN::RaWeb::Light::Help;

__PACKAGE__->mk_accessors(qw(cgi dir_contents esc_url_suffix path rev_num), 
    qw(should_be_dir svn_ra url_suffix));

# Preloaded methods go here.

# We alias escape() to CGI::escapeHTML().
*escape = \&CGI::escapeHTML;

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

sub get_mode
{
    my $self = shift;

    my $mode = $self->cgi()->param("mode");

    return (defined($mode) ? $mode : "view");
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
    
    $self->rev_num($rev_num);
    $self->url_suffix($self->get_url_suffix_with_extras());
    $self->esc_url_suffix(escape($self->url_suffix()));
}

# Gets the URL suffix calculated with optional extra components.
sub get_url_suffix_with_extras
{
    my $self = shift;
    my $components = shift;

    my $query_string = $self->cgi->query_string();
    if ($query_string eq "")
    {
        if (defined($components))
        {
            return "?" . $components;
        }
        else
        {
            return "";
        }        
    }
    else
    {
        if (defined($components))
        {
            return "?" . $query_string . ";" . $components;
        }
        else
        {
            return "?" . $query_string;
        }
    }
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

sub get_escaped_path
{
    my $self = shift;
    return escape($self->path());
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

sub get_esc_item_url_translations
{
    my $self = shift;

    if (!exists($self->{'escaped_item_url_translations'}))
    {
        $self->{'escaped_item_url_translations'} = 
        [
        (
            map { 
            +{ 
                'url' => escape($_->{'url'}), 
                'label' => escape($_->{'label'}),
            }
            }
            @{$self->get_url_translations('is_list_item' => 1)}
        )
        ];
    }
    return $self->{'escaped_item_url_translations'};
}

sub render_list_item
{
    my ($self, $args) = (@_);

    return
        qq(<li><a href="$args->{link}) .
        qq(@{[$self->esc_url_suffix()]}">$args->{label}</a>) .
        join("",
        map 
        {
            " [<a href=\"$_->{url}$args->{path_in_repos}\">$_->{label}</a>]"
        }
        @{$self->get_esc_item_url_translations()}
        ) .
        "</li>\n";    
}

sub get_esc_up_path
{
    my $self = shift;

    $self->path() =~ /^(.*?)[^\/]+$/;

    return escape($1);    
}

sub real_render_up_list_item
{
    my $self = shift;
    return $self->render_list_item(
        {
            'link' => "../",
            'label' => "..",
            'path_in_repos' => $self->get_esc_up_path(),
        }
    );
}

# The purpose of this function ios to get the list item of the ".." directory
# that goes one level up in the repository.
sub render_up_list_item
{
    my $self = shift;
    # If the path is the root - then we cannot have an upper directory
    if ($self->path() eq "")
    {
        return ();
    }
    else
    {
        return $self->real_render_up_list_item();
    }
}

# This method gets the escaped path along with a potential trailing slash
# (if it isn't empty)
sub get_normalized_path
{
    my $self = shift;

    my $url = $self->path();
    if ($url ne "")
    {
        $url .= "/";
    }
    return $url;
}

sub render_regular_list_item
{
    my ($self, $entry) = @_;

    my $escaped_name = escape($entry); 
    if ($self->dir_contents->{$entry}->kind() eq $SVN::Node::dir)
    {
        $escaped_name .= "/";
    }

    return $self->render_list_item(
        {
            (map { $_ => $escaped_name } qw(link label)),
            'path_in_repos' => 
                (escape($self->get_normalized_path()).$escaped_name),
        }
    );
}

sub render_top_url_translations_text
{
    my $self = shift;
    
    my $top_url_translations =
        $self->get_url_translations('is_list_item' => 0);
    my $ret = "";
    if (@$top_url_translations)
    {
        $ret .= "<table border=\"1\">\n";
        foreach my $trans (@$top_url_translations)
        {
            my $url = $self->get_normalized_path();
            my $escaped_url = escape($trans->{'url'} . $url);
            my $escaped_label = escape($trans->{'label'});
            $ret .= "<tr><td><a href=\"$escaped_url\">$escaped_label</a></td></tr>\n";
        }
        $ret .= "</table>\n";
    }
    return $ret;
}

sub render_dir_header
{
    my $self = shift;

    my $title = "Revision ". $self->rev_num() . ": /" . 
        $self->get_escaped_path();
    my $ret = "";
    $ret .= $self->cgi()->header();
    $ret .= "<html><head><title>$title</title></head>\n";
    $ret .= "<body>\n";
    $ret .="<h2>$title</h2>\n";

    return $ret;
}

sub get_items_list_items_order
{
    my $self = shift;
    return [ sort { $a cmp $b } keys(%{$self->dir_contents()}) ];
}

sub get_items_list_regular_items
{
    my $self = shift;
    return 
        [map 
        {
            $self->render_regular_list_item($_)
        } 
        (@{$self->get_items_list_items_order()})
        ];
}

sub get_items_list_items
{
    my $self = shift;
    return 
    [
        $self->render_up_list_item(),
        @{$self->get_items_list_regular_items()},
    ];
}

sub print_items_list
{
    my ($self) = @_;
    print "<ul>\n";
    
    print @{$self->get_items_list_items()};
    print "</ul>\n";
}

sub print_control_section
{
    my $self = shift;
    print "<ul>\n" .
        "<li><a href=\"./?mode=help\">Show Help Screen</a></li>\n" .
        "<li><a href=\"./" . escape($self->get_url_suffix_with_extras("panel=1")) . "\">Show Control Panel</a></li>\n" .
        "</ul>\n";
}

sub get_dir
{
    my $self = shift;

    my ($dir_contents, $fetched_rev) =
        $self->svn_ra()->get_dir($self->path(), $self->rev_num());
    $self->dir_contents($dir_contents);
}

sub process_dir
{
    my $self = shift;
    $self->get_dir();
    print $self->render_dir_header();
    print $self->render_top_url_translations_text();
    $self->print_items_list();
    $self->print_control_section();
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

sub process_help
{
    my $self = shift;
    SVN::RaWeb::Light::Help::print_data();
}

sub real_run
{
    my $self = shift;
    my $cgi = $self->cgi();

    if ($self->get_mode() eq "help")
    {
        return $self->process_help();
    }
    $self->calc_rev_num();
    $self->calc_path();

    my $node_kind =
        $self->svn_ra()->check_path($self->path(), $self->rev_num());

    $self->check_node_kind($node_kind);

    if ($node_kind eq $SVN::Node::dir)
    {
        return $self->process_dir();
    }
    # This means $node_kind eq $SVN::Node::file
    else
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
