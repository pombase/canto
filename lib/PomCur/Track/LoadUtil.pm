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

sub _empty_hash
{
  return {};
}
has 'people' => ( is => 'ro', builder => '_empty_hash' );
has 'labs' => ( is => 'ro', builder => '_empty_hash' );
has 'pubs' => ( is => 'ro', builder => '_empty_hash' );
has 'organisms' => ( is => 'ro', builder => '_empty_hash' );
has 'cvs' => ( is => 'ro', builder => '_empty_hash' );
has 'cvterms' => ( is => 'ro', builder => '_empty_hash' );

sub get_organism
{
  my $self = shift;

  my $genus = shift;
  my $species = shift;

  my $schema = $self->schema();

  my $full_name = "$genus $species";

  if (!exists $self->{organisms}->{$full_name}) {
    my $organism = $schema->create_with_type('Organism',
                                             {
                                               genus => $genus,
                                               species => $species,
                                             });

    $self->{organisms}->{$full_name} = $organism;
  }

  return $self->{organisms}->{$full_name};
}

sub get_cv
{
  my $self = shift;
  my $cv_name = shift;

  my $schema = $self->schema();

  if (!exists $self->{cvs}->{$cv_name}) {
    my $cv = $schema->create_with_type('Cv',
                                       {
                                         name => $cv_name
                                       });

    $self->{cvs}->{$cv_name} = $cv;
  }

  return $self->{cvs}->{$cv_name};
}

sub get_cvterm
{
  my $self = shift;

  my $cv = shift;
  my $cvterm_name = shift;

  my $schema = $self->schema();

  if (!exists $self->{cvterms}->{$cvterm_name}) {
    my $cvterm = $schema->create_with_type('Cvterm',
                                           {
                                             name => $cvterm_name,
                                             cv => $cv,
                                           });

    $self->{cvterms}->{$cvterm_name} = $cvterm;
  }

  return $self->{cvterms}->{$cvterm_name};
}

sub get_pub
{
  my $self = shift;
  my $pubmed_id = shift;

  my $schema = $self->schema();

  my $pub_type_cv = $self->get_cv('PomBase publication type');
  my $pub_type = $self->get_cvterm($pub_type_cv, 'unknown');

  if (!exists $self->{pubs}->{$pubmed_id}) {
    my $pub = $schema->create_with_type('Pub',
                                        {
                                          pubmedid => $pubmed_id,
                                          type => $pub_type,
                                        });

    $self->{pubs}->{$pubmed_id} = $pub;
  }

  return $self->{pubs}->{$pubmed_id};
}

sub get_lab
{
  my $self = shift;
  my $lab_head = shift;

  my $schema = $self->schema();

  my $lab_head_name = $lab_head->longname();

  (my $lab_head_surname = $lab_head_name) =~ s/.* //;

  if (!exists $self->{labs}->{$lab_head_name}) {
    my $lab = $schema->create_with_type('Lab',
                                        {
                                          lab_head => $lab_head,
                                          name => "$lab_head_surname Lab"
                                         });

    $self->{labs}->{$lab_head_name} = $lab;
  }

  return $self->{labs}->{$lab_head_name};
}

sub get_person
{
  my $self = shift;
  my $longname = shift;
  my $networkaddress = shift;
  my $role_cvterm = shift;

  my $schema = $self->schema();

  if (!defined $networkaddress || length $networkaddress == 0) {
    die "email not set for $longname\n";
  }
  if (!defined $longname || length $longname == 0) {
    die "name not set for $networkaddress\n";
  }

  if (!exists $self->{people}->{$longname}) {
    my $person = $schema->create_with_type('Person',
                                           {
                                             longname => $longname,
                                             networkaddress => $networkaddress,
                                             password => $networkaddress,
                                             role => $role_cvterm,
                                           });

    $self->{people}->{$longname} = $person;
  }

  return $self->{people}->{$longname};
}

1;
