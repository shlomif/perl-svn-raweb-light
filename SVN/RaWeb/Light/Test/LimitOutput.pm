package SVN::RaWeb::Light::OutputListOnly;

use base 'SVN::RaWeb::Light';

sub process_dir
{
    my $self = shift;
    $self->get_dir();
    $self->print_items_list();
}

1;

