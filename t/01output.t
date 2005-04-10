#!/usr/bin/perl

use warnings;
use strict;

package CGI;

# The purpose of this package is to mock the CGI object.

our @new_params;

sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    
    $self->initialize(@new_params);
    
    return $self;
}

sub initialize
{
    my $self = shift;

    my (%args) = (@_);

    $self->{'params'} = $args{'params'};
    $self->{'path_info'} = $args{'path_info'};

    $self->{'out'} = "";
}

sub param
{
    my $self = shift;
    my $param_id = shift;

    return $self->{'params'}->{$param_id};
}

sub path_info
{
    my $self = shift;
    return $self->{'path_info'};
}

sub redirect
{
    my $self = shift;
    my $where = shift;
    die +{
        'type' => "redirect",
        'redirect_to' => $where,
    };
}

sub header
{
    my $self = shift;
    
    print "Content-Type: text/html\n\n";
}

sub escapeHTML
{
    my $string = shift;
    $string =~ s{&}{&amp;}gso;
    $string =~ s{<}{&lt;}gso;
    $string =~ s{>}{&gt;}gso;
    $string =~ s{"}{&quot;}gso;
    return $string;
}

BEGIN
{
    $INC{'CGI.pm'} = "/usr/lib/perl5/site_perl/5.8.6/CGI.pm",
}

1;

package SVN::Ra;

our @new_params;
sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    
    $self->initialize('orig_params' => [@_], @new_params);
    
    return $self;
}

sub initialize
{
    my $self = shift;

    my (%args) = (@_);

    $self->{'orig_params'} = $args{'orig_params'};

    $self->{'get_latest_revnum'} = $args{'get_latest_revnum'} ||
        sub {
            return 100;
        }
        ;

    $self->{'check_path'} = $args{'check_path'} || 
        sub {
            my $self = shift;
            my $path = shift;
            my $rev_num = shift;

            if (($path =~ /NA\{\}/) || ($path =~ /NA\{$rev_num\}/))
            {
                return undef;
            }
            elsif ($path =~ m{\.[^/]*$})
            {
                return $SVN::Node::file;
            }
            else
            {
                return $SVN::Node::dir;
            }
        };

    $self->{'get_dir'} = $args{'get_dir'} || sub {
        my $self = shift;
        my $path = shift;
        my $rev_num = shift;

        return 
            (
                {
                    'Hello.pm' => 
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
    };

    $self->{'get_file'} = $args{'get_file'};
}

sub get_latest_revnum
{
    my $self = shift;
    return $self->{'get_latest_revnum'}->($self, @_);
}

sub check_path
{
    my $self = shift;
    return $self->{'check_path'}->($self, @_);
}

sub get_dir
{
    my $self = shift;
    my ($dir_contents, $fetched_rev) = $self->{'get_dir'}->($self, @_);
    return 
        (+{ 
            map 
            { 
                $_ => 
                    SVN::Mock::DirEntry->new($_, $dir_contents->{$_}) 
            }
            keys(%$dir_contents)
        }, $fetched_rev);
}

BEGIN
{
    $INC{'SVN/Ra.pm'} = '/usr/lib/perl5/site_perl/5.8.6/i386-linux/SVN/Ra.pm';
    $INC{'SVN/Core.pm'} = '/usr/lib/perl5/site_perl/5.8.6/i386-linux/SVN/Core.pm';
}

$SVN::Node::dir = "dir";
$SVN::Node::file = "file";

1;

package SVN::Mock::DirEntry;

sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->initialize(@_);
    return $self;
}

sub initialize
{
    my $self = shift;
    my $filename = shift;
    my $params = shift;
    $self->{'filename'} = $filename;
    $self->{'kind'} = $params->{'kind'};
    return 0;
}

sub kind
{
    my $self = shift;
    return $self->{'kind'};
}

1;

package main;

use Test::More tests => 1;

use SVN::RaWeb::Light;

{
    @CGI::new_params = ('path_info' => "");

    my $svn_ra_web = SVN::RaWeb::Light->new('url' => "http://svn-non-existentent.shlomifish.org/svn/myrepos");

    # TEST
    ok($svn_ra_web, "Object Initialization Succeeded");
    $svn_ra_web->run();
}

1;

