package PomCur::Controller::Local;

=head1 NAME

PomCur::Controller::Local - Controller for pages needed only for a
                            particular instance of the curation tool

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Controller::Local

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use base 'Catalyst::Controller';

use IO::All;

=head2 page

 Function: Render an HTML template from the local_templates directory
 Args    : $name - page name

=cut
sub local : Path :Args(1)
{
  my ($self, $c, $page_name) = @_;

  my $config = $c->config();

  my $st = $c->stash();

  $st->{title} = $config->{long_name};
  $st->{show_title} = 1;

  my $local_templates_dir_name = "local_templates";
  my $template_file_name = "$page_name.mhtml";

  my $template_file =
    $c->path_to('root', $local_templates_dir_name, $template_file_name);

  if (-f $template_file) {
    my @lines = io($template_file)->slurp;
    for my $line (@lines) {
      if ($line =~ /<!--\s*PAGE_TITLE:\s*(.*?)\s*-->/) {
        $st->{title} = $1;
      }
    }
    $st->{template} = "$local_templates_dir_name/$template_file_name";
  } else {
    $c->stash()->{error} =
      { title => "No such page",
        text => "$page_name doesn't exist" };
    $c->forward($c->config()->{home_path});
    $c->detach();
  }
}

1;
