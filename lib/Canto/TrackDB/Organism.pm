use utf8;
package Canto::TrackDB::Organism;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::TrackDB::Organism

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<organism>

=cut

__PACKAGE__->table("organism");

=head1 ACCESSORS

=head2 organism_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 abbreviation

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 genus

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 species

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 common_name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 comment

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "organism_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "abbreviation",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "genus",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "species",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "common_name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "comment",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</organism_id>

=back

=cut

__PACKAGE__->set_primary_key("organism_id");

=head1 RELATIONS

=head2 genes

Type: has_many

Related object: L<Canto::TrackDB::Gene>

=cut

__PACKAGE__->has_many(
  "genes",
  "Canto::TrackDB::Gene",
  { "foreign.organism" => "self.organism_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 organismprops

Type: has_many

Related object: L<Canto::TrackDB::Organismprop>

=cut

__PACKAGE__->has_many(
  "organismprops",
  "Canto::TrackDB::Organismprop",
  { "foreign.organism_id" => "self.organism_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_organisms

Type: has_many

Related object: L<Canto::TrackDB::PubOrganism>

=cut

__PACKAGE__->has_many(
  "pub_organisms",
  "Canto::TrackDB::PubOrganism",
  { "foreign.organism" => "self.organism_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-10-13 23:27:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wk36EYv283I8VuQo781Otg

use Carp;

# the genus and species, used when displaying organisms
sub full_name {
  my $self = shift;

  return $self->genus() . ' ' . $self->species();
}

# return the taxon ID of this organism, from the organismprop table
sub taxonid {
  my $self = shift;

  if (! defined $self->{_taxonid}) {
    my $prop = $self->organismprops()
      ->search({ 'type.name' => 'taxon_id' }, { join => 'type' })->first();
    croak "expected organismprop not found" unless defined $prop;
    $self->{_taxonid} = $prop->value();
  }

  return $self->{_taxonid};
}

# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
