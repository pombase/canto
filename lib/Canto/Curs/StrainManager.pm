package Canto::Curs::StrainManager;

=head1 NAME

Canto::Curs::StrainManager - Manage strains in a session

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::StrainManager

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2018 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

use Canto::Track;
use Canto::CursDB::Organism;

has curs_schema => (is => 'rw', isa => 'Canto::CursDB', required => 1);
has strain_lookup => (is => 'ro', init_arg => undef, lazy_build => 1);
has organism_manager => (is => 'ro', init_arg => undef, lazy_build => 1);

with 'Canto::Role::Configurable';

sub _build_strain_lookup
{
  my $self = shift;

  return Canto::Track::get_adaptor($self->config(), 'strain');
}

sub _build_organism_manager
{
  my $self = shift;

  return Canto::Curs::OrganismManager->new(config => $self->config(),
                                           curs_schema => $self->curs_schema());
}

=head2 add_strain_by_id

 Usage   : $strain_manager->add_strain_by_id($strain_id);
 Function: Adds the given strain to the current session
 Returns : the new Strain object

=cut

sub add_strain_by_id
{
  my $self = shift;

  my $track_strain_id = shift;

  my $curs_schema = $self->curs_schema();
  my $strain_rs = $curs_schema->resultset('Strain');

  my $strain = $strain_rs->find({ track_strain_id => $track_strain_id });

  if ($strain) {
    return $strain;
  } else {
    my @track_strain_details =
      $self->strain_lookup()->lookup_by_strain_ids($track_strain_id);

    my $taxon_id = $track_strain_details[0]->{taxon_id};

    my $organism = $self->organism_manager()->add_organism_by_taxonid($taxon_id);

    return $curs_schema->create_with_type('Strain',
                                          {
                                            track_strain_id => $track_strain_id,
                                            organism_id => $organism->organism_id(),
                                          });
  }
}

=head2 add_strain_by_name

 Usage   : $strain_manager->add_strain_by_name($taxon_id, $strain_name);
 Function: Adds the given strain to the current session
 Returns : the new Strain object

=cut

sub add_strain_by_name
{
  my $self = shift;

  my $taxon_id = shift;
  my $strain_name = shift;

  my $curs_schema = $self->curs_schema();
  my $strain_rs = $curs_schema->resultset('Strain');

  my $organism = $self->organism_manager()->add_organism_by_taxonid($taxon_id);

  my $strain = $strain_rs->find({
    strain_name => $strain_name,
    organism_id => $organism->organism_id(),
  });

  if ($strain) {
    return $strain;
  }

  my $track_strain_details =
    $self->strain_lookup()->lookup_by_strain_name($taxon_id, $strain_name);

  if ($track_strain_details) {
    return $strain_rs ->find_or_create({
      organism_id => $organism->organism_id(),
      track_strain_id => $track_strain_details->{strain_id},
    });
  }

  return $curs_schema->create_with_type('Strain',
                                        {
                                          organism_id => $organism->organism_id(),
                                          strain_name => $strain_name,
                                        });
}

=head2 find_strain_by_name

 Usage   : $strain_manager->find_strain_by_name($taxon_id, $strain_name);
 Function: Return the strain with the given name.  The strain must be
           in the session.
 Returns : the strain or undef if not found

=cut

sub find_strain_by_name
{
  my $self = shift;

  my $taxon_id = shift;
  my $strain_name = shift;

  if (!defined $strain_name) {
    die "no strain name passed to find_strain_by_name()";
  }

  my $curs_schema = $self->curs_schema();
  my $strain_rs = $curs_schema->resultset('Strain');

  my $organism = $self->organism_manager()->add_organism_by_taxonid($taxon_id);

  my $strain = $strain_rs->find({
    strain_name => $strain_name,
    organism_id => $organism->organism_id(),
  });

  if ($strain) {
    return $strain;
  }

  my $track_strain_details =
    $self->strain_lookup()->lookup_by_strain_name($taxon_id, $strain_name);

  if ($track_strain_details) {
    return $strain_rs->find({
      organism_id => $organism->organism_id(),
      track_strain_id => $track_strain_details->{strain_id},
    });
  }

  return undef;
}

=head2 delete_strain_by_id

 Usage   : $strain_manager->delete_strain_by_id($strain_id);
 Function: Delete a strain using its strain ID from the TrackDB
 Returns : The deleted strain but dies if the strain is referenced by any
           genotypes

=cut

sub delete_strain_by_id
{
  my $self = shift;

  my $track_strain_id = shift;

  my $strain_rs = $self->curs_schema()->resultset('Strain');

  my $strain = $strain_rs->find({ track_strain_id => $track_strain_id });

  if ($strain) {
    if ($strain->genotypes()->count() > 0) {
      die "can't delete strain with ID $track_strain_id as there are genotypes " .
        "in the session that reference that strain\n";
    } else {
      $strain->delete();
      return $strain;
    }
  } else {
    die "can't find strain with ID $track_strain_id\n"
  }
}


=head2 delete_strain_by_name

 Usage   : $strain_manager->delete_strain_by_name($taxon_id, $strain_name);
 Function: Delete a strain using its strain ID from the TrackDB
 Returns : The deleted strain but dies if the strain is referenced by any
           genotypes

=cut

sub delete_strain_by_name
{
  my $self = shift;

  my $taxon_id = shift;
  my $strain_name = shift;

  die "no strain_name passed to delete_strain_by_name()\n"
    unless defined $strain_name;

  my $strain_rs = $self->curs_schema()->resultset('Strain');

  my $strain = $strain_rs->find({
    strain_name => $strain_name,
    'organism.taxonid' => $taxon_id,
  }, {
    join => 'organism',
  });

  if (!$strain) {
    my $track_strain_details =
      $self->strain_lookup()->lookup_by_strain_name($taxon_id, $strain_name);

    if ($track_strain_details) {
      $strain = $strain_rs->find({
        track_strain_id => $track_strain_details->{strain_id},
      });
    }
  }

  if ($strain) {
    if ($strain->genotypes()->count() > 0) {
      die "can't delete strain with name $strain_name as there are genotypes " .
        "in the session that reference that strain\n";
    } else {
      $strain->delete();
      return $strain;
    }
  } else {
    die "can't find strain with name $strain_name for taxon ID $taxon_id\n"
  }
}

=head2 delete_strains_by_taxon_id

 Usage   : $strain_manager->delete_strains_by_taxon_id($taxonid);
 Function: Delete all the strains of the organism given by the argument
 Returns : Nothing, but dies if any strain is referenced by a genotype

=cut

sub delete_strains_by_taxon_id
{
  my $self = shift;
  my $taxon_id = shift;

  die "no taxon_id passed to delete_strains_by_taxon_id()\n"
    unless defined $taxon_id;

  my @strains = $self->curs_schema()->resultset('Strain')
    ->search({
      'organism.taxonid' => $taxon_id,
    }, {
      join => 'organism',
    })
    ->all();

  for my $strain (@strains) {
    if ($strain->genotypes()->count() > 0) {
      die "can't delete strain for taxon ID $taxon_id as there are genotypes " .
        "in the session that reference that strain\n";
    }
  }

  for my $strain (@strains) {
    $strain->delete();
  }
}

1;
