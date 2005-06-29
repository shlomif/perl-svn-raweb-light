#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 2;

# We need to load the mocking modules first because they fill the 
# namespaces and %INC. Otherwise, "use CGI" and "use SVN::*" will cause
# the real modules to be loaded.
use SVN::RaWeb::Light::Mock::CGI;
use SVN::RaWeb::Light::Mock::Svn;
use SVN::RaWeb::Light::Mock::Stdout;

use SVN::RaWeb::Light;

sub mytest
{
    my (%args) = (@_);
    my $cgi_params = $args{'cgi'} || {};
    my $is_list_item = $args{'is_list_item'};
    my $url_trans = $args{'url_translations'};
    my $results = $args{'results'};
    my $msg = $args{'msg'};

    @CGI::new_params = 
    (
        'path_info' => "/trunk/hello/",
        'params' => $cgi_params,
    );

    my $svn_raweb = 
        SVN::RaWeb::Light->new(
            'url_translations' => $url_trans
        );

    is_deeply(
        $svn_raweb->get_url_translations(
            'is_list_item' => $is_list_item,
        ),
        $results,
        $msg
    );    
}

# TEST
mytest(
    'is_list_item' => 0,
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
    'msg' => "Basic Test - No CGI",
    'results' =>
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

# TEST
mytest(
    'msg' => "Basic Test - With trans_hide_all CGI",
    'cgi' => { 'trans_hide_all' => 1, },
    'is_list_item' => 0,
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
    'results' =>
    [
    ],
);
