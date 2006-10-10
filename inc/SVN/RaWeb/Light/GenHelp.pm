use strict;
use warnings;

sub _gen_help
{
open O, ">", "lib/SVN/RaWeb/Light/Help.pm";
print O <<"EOF";
package SVN::RaWeb::Light::Help;

use strict;
use warnings;

\=head1 NAME

SVN::RaWeb::Light::Help - Generate the Help HTML for SVN::RaWeb::Light.

\=head1 SYNOPSIS

Warning! This moduls is auto-generated.

\=head1 FUNCTIONS

\=head2 print_data()

Prints the HTML data to the standard output.

\=head1 AUTHOR

Shlomi Fish, E<lt>shlomif\@iglu.org.ilE<gt>

\=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Shlomi Fish

This library is free software; you can redistribute it and/or modify
it under the terms of the MIT/X11 license.

\=cut

sub print_data
{
    local \$/;
    print <DATA>;
}

1;
EOF

print O "__DATA__\n";

{
    local $/;
    open I, "<", "docs/Help.html";
    print O <I>;
    close(I);
}
close(O);
}

1;

