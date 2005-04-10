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

