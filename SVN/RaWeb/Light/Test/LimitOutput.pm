package SVN::RaWeb::Light::OutputListOnly;

use base 'SVN::RaWeb::Light';

sub process_dir
{
    my $self = shift;
    $self->get_dir();
    $self->print_items_list();
}

1;

package SVN::RaWeb::Light::OutputTransAndList;

use base 'SVN::RaWeb::Light';

sub process_dir
{
    my $self = shift;
    $self->get_dir();

    print $self->render_top_url_translations_text();
    $self->print_items_list();
}

1;

