package PomCur::Controller::Curs;

use parent 'Catalyst::Controller';

=head1 NAME

PomCur::Controller::Curs - curs (curation session) controller

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Controller::Curs

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;

use PomCur::Curs::Util;

=head2 begin

 Action to set up stash contents for curs

=cut
sub dispatch : LocalRegex('^([0-9a-f]{8})(:?/([^/]+)?)?')
{
  my ($self, $c) = @_;
  my ($curs_key, $module_name) = @{$c->req->captures()};

  my $path = $c->req->uri()->path();
  (my $controller_name = __PACKAGE__) =~ s/.*::(.*)/\L$1/;
  $c->stash->{curs_key} = $1;
  $c->stash->{controller_name} = $controller_name;

  my $start_path = $c->uri_for("/$controller_name/$curs_key");
  $c->stash->{curs_start_path} = $start_path;

  @{$c->stash->{module_names}} = keys %{$c->config()->{annotation_modules}};

  if (!defined $module_name || $module_name eq 'start') {
    $c->stash->{title} = 'Start';
    $c->stash->{template} = 'curs/main.mhtml';
  } else {
    my $module_display_name =
      PomCur::Curs::Util::module_display_name($module_name);
    $c->stash->{title} = 'TEST ' . $module_display_name;
    $c->stash->{template} = "curs/modules/$module_name.mhtml";
  }
}


1;
