package Canto::View::Mason;

use strict;
use warnings;
use base 'Catalyst::View::Mason';

use File::Spec;
use Canto::Config;

my $app = Canto::Config::get_application_name();
my $inst_name = Canto::Config::get_instance_name();

# add job name from Jenkins
if ($ENV{JOB_NAME}) {
  $inst_name .= '_' . $ENV{JOB_NAME};
}

__PACKAGE__->config(use_match => 0);
__PACKAGE__->config(escape_flags => {
  html => \&HTML::Mason::Escapes::basic_html_escape,
});
__PACKAGE__->config(default_escape_flags => 'html');
__PACKAGE__->config->{data_dir} =
  File::Spec->catdir(
    File::Spec->tmpdir,
    sprintf('%s_%d_%s_mason_data_dir', $app, $<, $inst_name)
  );

=head1 NAME

Canto::View::Mason - Mason View Component

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
