package PomCur::Track::LoadUtil;

=head1 NAME

PomCur::Track::LoadUtil -

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::LoadUtil

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

has 'schema' => (
  is => 'ro',
  isa => 'PomCur::TrackDB'
);

sub get_organism
{
  my $self = shift;

  my $genus = shift;
  my $species = shift;

  my $schema = $self->schema();

  my $full_name = "$genus $species";

  return $schema->resultset('Organism')->find_or_create(
      {
        genus => $genus,
        species => $species,
      });
}

sub get_cv
{
  my $self = shift;
  my $cv_name = shift;

  my $schema = $self->schema();

  croak unless defined $cv_name;

  return $schema->resultset('Cv')->find_or_create(
      {
        name => $cv_name
      });
}

sub get_db
{
  my $self = shift;
  my $db_name = shift;

  my $schema = $self->schema();

  return $schema->resultset('Db')->find_or_create(
      {
        name => $db_name
      });
}

sub get_dbxref
{
  my $self = shift;
  my $db = shift;
  my $dbxref_acc = shift;

  my $schema = $self->schema();

  return $schema->resultset('Dbxref')->find_or_create(
      {
        accession => $dbxref_acc,
        db => $db
      });
}

sub get_cvterm
{
  my $self = shift;

  my %args = @_;

  my $cv_name = $args{cv_name};
  my $cv = $args{cv};
  if (!defined $cv) {
    $cv = $self->get_cv($cv_name);
  }
  my $term_name = $args{term_name};
  my $ontologyid = $args{ontologyid};
  my $definition = $args{definition};

  my $db_name;
  my $accession;

  if (defined $ontologyid && $ontologyid =~ /(.*):(.*)/) {
    $db_name = $1;
    $accession = $2
  } else {
    $db_name = 'PomCur Track';
    $accession = $term_name;
  }

  my $db = $self->get_db($db_name);
  my $dbxref = $self->get_dbxref($db, $accession);

  my $schema = $self->schema();

  my %create_args = (
    name => $term_name,
    cv => $cv,
    definition => $definition,
    dbxref => $dbxref,
  );

  return $self->schema()->resultset('Cvterm')->find_or_create(
      {
        %create_args
      });
}

sub get_pub
{
  my $self = shift;
  my $pubmed_id = shift;

  my $schema = $self->schema();

  my $pub_type_cv = $self->get_cv('PomBase publication type');
  my $pub_type = $self->get_cvterm(cv => $pub_type_cv,
                                   term_name => 'unknown');

  return $schema->resultset('Pub')->find_or_create(
      {
        pubmedid => $pubmed_id,
        type => $pub_type,
      });
}

sub get_lab
{
  my $self = shift;
  my $lab_head = shift;

  my $schema = $self->schema();

  my $lab_head_name = $lab_head->name();

  (my $lab_head_surname = $lab_head_name) =~ s/.* //;

  return $schema->resultset('Lab')->find_or_create(
      {
        lab_head => $lab_head,
        name => "$lab_head_surname Lab"
      });
}

sub get_person
{
  my $self = shift;
  my $name = shift;
  my $networkaddress = shift;
  my $role_cvterm = shift;

  my $schema = $self->schema();

  if (!defined $networkaddress || length $networkaddress == 0) {
    die "email not set for $name\n";
  }
  if (!defined $name || length $name == 0) {
    die "name not set for $networkaddress\n";
  }

  return $schema->resultset('Person')->find_or_create(
      {
        name => $name,
        networkaddress => $networkaddress,
        password => $networkaddress,
        role => $role_cvterm,
      });
}

1;
