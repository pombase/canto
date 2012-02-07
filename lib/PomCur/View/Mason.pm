package PomCur::View::Mason;

use strict;
use warnings;
use base 'Catalyst::View::Mason';

use File::Spec;
use PomCur::Config;

my $app = PomCur::Config::get_application_name();

__PACKAGE__->config(use_match => 0);
__PACKAGE__->config(escape_flags => {
  html => sub {
    # don't use the Mason HTML escaping because it breaks Unicode text
    ${$_[0]} =~ s/&/&amp;/gs;
    ${$_[0]} =~ s/</&lt;/gs;
    ${$_[0]} =~ s/>/&gt;/gs;
  },
});
__PACKAGE__->config(default_escape_flags => 'html');
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
