package PomCur::View::Mason;

use strict;
use warnings;
use base 'Catalyst::View::Mason';

use File::Spec;
use PomCur::Config;

my $app = PomCur::Config::get_application_name();

__PACKAGE__->config(use_match => 0);
__PACKAGE__->config->{data_dir} =
  File::Spec->catdir(
    File::Spec->tmpdir,
    sprintf('%s_%d_mason_data_dir', $app, $<)
  );

=head1 NAME

PomCur::View::Mason - Mason View Component

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
