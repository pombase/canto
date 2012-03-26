use utf8;
package PomCur::CursDB::Organism;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PomCur::CursDB::Organism

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

=head2 full_name

  data_type: 'text'
  is_nullable: 0

=head2 taxonid

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "organism_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "full_name",
  { data_type => "text", is_nullable => 0 },
  "taxonid",
  { data_type => "integer", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</organism_id>

=back

=cut

__PACKAGE__->set_primary_key("organism_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<full_name_unique>

=over 4

=item * L</full_name>

=back

=cut

__PACKAGE__->add_unique_constraint("full_name_unique", ["full_name"]);

=head1 RELATIONS

=head2 genes

Type: has_many

Related object: L<PomCur::CursDB::Gene>

=cut

__PACKAGE__->has_many(
  "genes",
  "PomCur::CursDB::Gene",
  { "foreign.organism" => "self.organism_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07017 @ 2012-03-26 04:28:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:po5paj+wyCSMSn0sklh2sQ


use Carp;

sub get_organism
{
  my $schema = shift;
  my $name = shift;
  my $taxonid = shift;

  croak "taxonid argument undefined" unless defined $taxonid;

  return $schema->find_or_create_with_type('Organism',
                                           { full_name => $name,
                                             taxonid => $taxonid });
}


__PACKAGE__->meta->make_immutable;

1;
