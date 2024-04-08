package Canto::Track::TrackUtil;

=head1 NAME

Canto::Track::TrackUtil - Miscellaneous utility functions

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::TrackUtil

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;

use Moose;

use Canto::TrackDB;

with 'Canto::Role::Configurable';
with 'Canto::Track::Role::Schema';

sub _get_strain_rs
{
  my $schema = shift;
  my $taxonid = shift;
  my $strain_name = shift;

  return $schema->resultset('Strain')
    ->search({
      'type.name' => 'taxon_id', 'organismprops.value' => $taxonid,
      'me.strain_name' => $strain_name,
    },
    {
      join => { organism => { organismprops => 'type' } }
    });
}

=head2 rename_strain

 Usage   : $track_util->rename_strain($taxonid, $old_name, $new_name);
 Function: Rename a strain of the organism given by $taxonid, fails if there
           is no strain with $old_name or there is an existing strain with
           $new_name.
 Args    : $old_name
           $new_name
 Returns : nothing

=cut

sub rename_strain
{
  my $self = shift;

  my $taxonid = shift;
  my $old_name = shift;
  my $new_name = shift;

  my $schema = $self->schema();

  my $existing_old_rs = _get_strain_rs($schema, $taxonid, $old_name);

  if ($existing_old_rs->count() == 0) {
    die qq|no existing strain found with name "$old_name" for taxon "$taxonid"\n|;
  }

  if ($existing_old_rs->count() > 1) {
    die qq|two or more existing strains found with name "$old_name" for taxon "$taxonid"\n|;
  }

  my $existing_new_rs = _get_strain_rs($schema, $taxonid, $new_name);

  if ($existing_new_rs->count() > 0) {
    die qq|can't rename strain "$old_name" to "$new_name" - a strain with name | .
      qq|"$new_name" already exists for taxon "$taxonid"\n|;
  }

  my $existing_strain = $existing_old_rs->first();

  $existing_strain->strain_name($new_name);
  $existing_strain->update();
}

# change track_strain_id in every session from $old_track_strain_id to
# $new_track_strain_id
sub _change_session_strains
{
  my $self = shift;
  my $old_track_strain_id = shift;
  my $new_track_strain_id = shift;

  my $track_schema = $self->schema();

  my $proc = sub {
    my $curs = shift;
    my $cursdb = shift;

    my $old_strain_rs = $cursdb->resultset('Strain')
      ->search({
        track_strain_id => $old_track_strain_id,
      });

    my $old_strain = $old_strain_rs->first();

    if (defined $old_strain) {
      my $new_strain_rs = $cursdb->resultset('Strain')
        ->search({
          track_strain_id => $new_track_strain_id,
        });

      my $new_strain = $new_strain_rs->first();

      if (defined $new_strain) {
        $cursdb->resultset('Genotype')->search({ strain_id => $old_strain->strain_id() })
          ->update({ strain_id => $new_strain->strain_id() });
        $old_strain->delete();
      } else {
        $old_strain->track_strain_id($new_track_strain_id);
        $old_strain->update();
      }
    }
  };

  Canto::Track::curs_map($self->config(), $track_schema, $proc);
}


=head2 merge_strains

 Usage   : $track_util->merge_strains($taxonid, $old_name, $new_name);
 Function: Merge strains $old_name and $new_name, deleting the strain named
           $old_name.  Any strain in any sessions that uses $old_name will
           be changed to use $new_name.  Fails if either strain doesn't exist.
 Args    : $taxonid
           $old_name
           $new_name
 Returns : nothing

=cut

sub merge_strains
{
  my $self = shift;

  my $taxonid = shift;
  my $old_name = shift;
  my $new_name = shift;

  my $schema = $self->schema();

  my $old_strain_rs = _get_strain_rs($schema, $taxonid, $old_name);

  if ($old_strain_rs->count() == 0) {
    die qq|no strain found with name "$old_name" for taxon "$taxonid"\n|;
  }

  if ($old_strain_rs->count() > 1) {
    die qq|two or more existing strains found with name "$old_name" for taxon "$taxonid"\n|;
  }

  my $old_strain = $old_strain_rs->first();

  my $new_strain_rs = _get_strain_rs($schema, $taxonid, $new_name);

  if ($new_strain_rs->count() == 0) {
    die qq|no strain found with name "$new_name" for taxon "$taxonid"\n|;
  }

  if ($new_strain_rs->count() > 1) {
    die qq|two or more existing strains found with name "$new_name" for taxon "$taxonid"\n|;
  }

  my $new_strain = $new_strain_rs->first();


  $self->_change_session_strains($old_strain->strain_id(), $new_strain->strain_id());

  $old_strain->strainsynonyms()->delete();
  $old_strain->delete();
}

sub _find_used_strains
{
  my $self = shift;

  my $track_schema = $self->schema();

  my %used_strain_ids = ();

  my $proc = sub {
    my $curs = shift;
    my $cursdb = shift;

    my $rs = $cursdb->resultset('Strain');

    while (defined (my $strain = $rs->next())) {
      my $track_strain_id = $strain->track_strain_id();

      if (defined $track_strain_id) {
        $used_strain_ids{$track_strain_id} = 1;
      }
    }
  };

  Canto::Track::curs_map($self->config(), $track_schema, $proc);

  return %used_strain_ids;
}

sub _lookup_by_taxonid
{
  my $schema = shift;
  my $taxonid = shift;

  return $schema->resultset('Organismprop')
    ->search({ 'type.name' => 'taxon_id', value => $taxonid },
             { join => 'type' })
    ->first();
}

=head2 change_taxonid

 Usage   : $track_util->change_taxonid($old_taxonid, $new_taxonid);
 Function: Change $old_taxonid to $new_taxonid in the track and session
           databases
 Returns : Nothing, but dies if there is no organism with the old taxon ID
           or there is an existing organism with the new taxond ID

=cut

sub change_taxonid
{
  my $self = shift;

  my $old_taxonid = shift;
  my $new_taxonid = shift;

  my $track_schema = $self->schema();

  my $new_taxonid_prop = _lookup_by_taxonid($track_schema, $new_taxonid);

  if (defined $new_taxonid_prop) {
    die qq|an organism with taxon ID "$new_taxonid" already exists\n|;
  }

  my $old_taxonid_prop = _lookup_by_taxonid($track_schema, $old_taxonid);

  if (!defined $old_taxonid_prop) {
    die qq|can't find an organism with taxon ID "$old_taxonid" in the database\n|;
  }

  $old_taxonid_prop->value($new_taxonid);
  $old_taxonid_prop->update();

  my $proc = sub {
    my $curs = shift;
    my $cursdb = shift;

    my $old_organism = $cursdb->resultset('Organism')
      ->search({
        taxonid => $old_taxonid,
      })->first();

    if (defined $old_organism) {
      $old_organism->taxonid($new_taxonid);
      $old_organism->update();
    }
  };

  Canto::Track::curs_map($self->config(), $track_schema, $proc);
}

=head2 delete_unused_strains

 Usage   : $track_util->delete_unused_strains();
 Function: Delete all strains that aren't used in a session.
 Args    : None
 Returns : The number of strains deleted

=cut

sub delete_unused_strains
{
  my $self = shift;

  my $track_schema = $self->schema();

  my %used_strain_ids = $self->_find_used_strains();

  my $count = 0;

  my $rs = $track_schema->resultset('Strain');

  while (defined (my $strain = $rs->next())) {
    if (!exists $used_strain_ids{$strain->strain_id()}) {
      $strain->strainsynonyms()->delete();
      $strain->delete();
      $count++;
    }
  }

  return $count;
}

sub _get_track_people_map
{
  my $self = shift;

  my $track_schema = $self->schema();

  my %people = ();

  my $people_rs = $track_schema->resultset('Person');

  while (defined (my $person = $people_rs->next())) {
    $people{$person->email_address()} = {
      name => $person->name(),
      orcid => $person->orcid(),
    };
  }

  return %people;
}


sub _get_curs_metadata
{
  my $self = shift;

  my $cursdb = shift;

  my %metadata = ();

  my $metadata_rs = $cursdb->resultset('Metadata');

  while (defined (my $md_row = $metadata_rs->next())) {
    my $key = $md_row->key();
    my $value = $md_row->value();

    $metadata{$key} = $value;
  }

  return %metadata;
}


=head2 update_annotation_curators

 Usage   : $self->update_annotation_curators();
 Function: Set the curator_orcid field of the annotations
           if available in the person table

=cut

sub update_annotation_curators
{
  my $self = shift;

  my $track_schema = $self->schema();

  my %people_map = $self->_get_track_people_map();

  my $proc = sub {
    my $curs = shift;
    my $cursdb = shift;

    my $annotation_rs = $cursdb->resultset('Annotation');

    my $updated_count = 0;

    while (defined (my $annotation = $annotation_rs->next())) {
      my $data = $annotation->data();

      my $curator = $data->{curator};
      my $curator_email = $curator->{email};

      my $curator_orcid = $people_map{$curator_email}->{orcid};

      if (!defined $curator->{curator_orcid} &&
          defined $curator_orcid ||
          defined $curator_orcid &&
          defined $curator->{curator_orcid} &&
          $curator_orcid ne $curator->{curator_orcid}) {
        $curator->{curator_orcid} = $curator_orcid;

        $annotation->data($data);
        $annotation->update();

        $updated_count++;
      }
    }

    if ($updated_count > 0) {
      my $curs_key = $curs->curs_key();

      warn "$curs_key: updated $updated_count\n";
    }
  };

  Canto::Track::curs_map($self->config(), $track_schema, $proc);
}

=head2 change_gene_id

 Usage   : $util->change_gene_id($from_id, $to_id)
 Function: Change a gene ID (primary_identifier) in every session.
           Also change allele IDs containing the $from_id.
 Args    : $from_id - an existing primary_identifier
           $to_id
 Returns : nothing - dies on failures

=cut

sub change_gene_id
{
  my $self = shift;

  my $from_id = shift;
  my $to_id = shift;

  my $track_schema = $self->schema();

  my $proc = sub {
    my $curs = shift;
    my $cursdb = shift;

    my $gene_rs = $cursdb->resultset('Gene');

    while (defined (my $gene = $gene_rs->next())) {
      if ($gene->primary_identifier() eq $from_id) {
        print $curs->curs_key(), "\n";
        $gene->primary_identifier($to_id);
        $gene->update();
      }
    }

    my $allele_rs = $cursdb->resultset('Allele');

    while (defined (my $allele = $allele_rs->next())) {
      my $primary_identifier = $allele->primary_identifier();
      if ($primary_identifier =~ /^$from_id:/) {
        $primary_identifier =~ s/^$from_id:/$to_id:/;
        $allele->primary_identifier($primary_identifier);
        $allele->update();
      }
    }
  };

  Canto::Track::curs_map($self->config(), $track_schema, $proc);
}

1;
