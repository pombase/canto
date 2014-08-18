package Canto::Track::CurationLoad;

=head1 NAME

Canto::Track::CurationLoad - Code for loading curation data from a flat file

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::CurationLoad

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use Moose;

use Text::CSV;

use Canto::Track::LoadUtil;
use Canto::Track::PubmedUtil;

has 'schema' => (
  is => 'ro',
  isa => 'Canto::TrackDB'
);

has 'load_util' => (
  is => 'ro',
  isa => 'Canto::Track::LoadUtil',
  lazy => 1,
  builder => '_make_load_util'
);

has 'default_db_name' => (
  is => 'ro',
  required => 1,
);

sub _make_load_util
{
  my $self = shift;

  my $schema = $self->schema();

  return Canto::Track::LoadUtil->new(schema => $schema,
                                     default_db_name => $self->default_db_name(),
                                     preload_cache => 1);
}

sub _fix_lab
{
  my ($person, $lab) = @_;

  if (!defined $person->lab()) {
    $person->lab($lab);
    $person->update();
  }
}

sub _process_row
{
  my $self = shift;

  my $schema = $self->schema();

  my $columns_ref = shift;
  my $user_cvterm = shift;

  my ($pubmed_id, $lab_head_name, $submitter_name, $date_sent, $status,
      $lab_head_email, $submitter_email) = @{$columns_ref};

  my $uniquename = $Canto::Track::PubmedUtil::PUBMED_PREFIX . ":$pubmed_id";
  my $pub = $self->load_util()->get_pub($uniquename, 'admin_load');
  my $lab_head = $self->load_util()->get_person($lab_head_name,
                                                $lab_head_email, $user_cvterm,
                                                $lab_head_email);
  my $lab = $self->load_util()->get_lab($lab_head);
  my $submitter = undef;

  if ($submitter_email) {
    $submitter = $self->load_util()->get_person($submitter_name,
                                                $submitter_email, $user_cvterm,
                                                $submitter_email);
  }

  if (!defined ($submitter)) {
    $submitter = $lab_head;
  }

  _fix_lab($lab_head, $lab);
  _fix_lab($submitter, $lab);
}

=head2 load

 Usage:
    my $load_util = Canto::Track::LoadUtil->new(schema => $schema);
    my $loader = Canto::Track::CurationLoad->new(schema => $schema,
                                                  load_util => $load_util);
    $loader->load($file_name);
 Function: Load curation data into the database.  The input is a tab delimited
           file
 Args    : $file_name - the file name
 Returns : nothing

=cut
sub load
{
  my $self = shift;
  my $curation_file = shift;

  my $schema = $self->schema();

  my $user_cvterm = $self->load_util()->get_cvterm(cv_name => 'Canto user types',
                                                   term_name => 'user');
  my $admin_cvterm = $self->load_util()->get_cvterm(cv_name => 'Canto user types',
                                                    term_name => 'admin');

  # get_person() creates the person if not found
  $self->load_util()->get_person('Val Wood', 'val@sanger.ac.uk',
                                 $admin_cvterm, 'val@sanger.ac.uk');
  my $dr_harris =
    $self->load_util()->get_person('Midori Harris', 'mah79@cam.ac.uk',
                                   $admin_cvterm, 'mah79@cam.ac.uk');
  $dr_harris->known_as("Dr Harris");
  $dr_harris->update();

  $self->load_util()->get_person('Antonia Nilsson', 'a.nilsson@warwick.ac.uk',
                                 $admin_cvterm, 'a.nilsson@warwick.ac.uk');

  my $csv = Text::CSV->new({binary => 1});
  open my $curation_io, '<', $curation_file or die;
  $csv->column_names ($csv->getline($curation_io));

  while (my $columns_ref = $csv->getline($curation_io)) {
    $self->_process_row($columns_ref, $user_cvterm);
  }
}

1;
