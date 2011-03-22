package PomCur::Track::CurationLoad;

=head1 NAME

PomCur::Track::CurationLoad - Code for loading curation data from a flat file

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::CurationLoad

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use Moose;

use Text::CSV;

use PomCur::Track::LoadUtil;
use PomCur::Track::PubmedUtil;

has 'schema' => (
  is => 'ro',
  isa => 'PomCur::TrackDB'
);

has 'load_util' => (
  is => 'ro',
  isa => 'PomCur::Track::LoadUtil',
  lazy => 1,
  builder => '_make_load_util'
);

sub _make_load_util
{
  my $self = shift;

  my $schema = $self->schema();

  return PomCur::Track::LoadUtil->new(schema => $schema);
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

  my $uniquename = $PomCur::Track::PubmedUtil::PUBMED_PREFIX . ":$pubmed_id";
  my $pub = $self->load_util()->get_pub($uniquename);
  my $lab_head = $self->load_util()->get_person($lab_head_name,
                                                $lab_head_email, $user_cvterm);
  my $lab = $self->load_util()->get_lab($lab_head);
  my $submitter = undef;

  if ($submitter_email) {
    $submitter = $self->load_util()->get_person($submitter_name,
                                                $submitter_email, $user_cvterm);
  }

  if (!defined ($submitter)) {
    $submitter = $lab_head;
  }

  _fix_lab($lab_head, $lab);
  _fix_lab($submitter, $lab);
}

sub load
{
  my $self = shift;
  my $curation_file = shift;

  my $schema = $self->schema();

  my $cv = $self->load_util()->find_cv('PomCur user types');

  my $user_cvterm = $self->load_util()->get_cvterm(cv => $cv,
                                                   term_name => 'user');
  my $admin_cvterm = $self->load_util()->get_cvterm(cv => $cv,
                                                    term_name => 'admin');

  my $admin = $self->load_util()->get_person('Val Wood', 'val@sanger.ac.uk',
                                             $admin_cvterm);

  my $csv = Text::CSV->new({binary => 1});
  open my $curation_io, '<', $curation_file or die;
  $csv->column_names ($csv->getline($curation_io));

  while (my $columns_ref = $csv->getline($curation_io)) {
    $self->_process_row($columns_ref, $user_cvterm);
  }
}

1;
