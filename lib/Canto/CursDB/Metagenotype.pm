use utf8;
package Canto::CursDB::Metagenotype;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::CursDB::Metagenotype

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<metagenotype>

=cut

__PACKAGE__->table("metagenotype");

=head1 ACCESSORS

=head2 metagenotype_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 identifier

  data_type: 'text'
  is_nullable: 0

=head2 type

  data_type: 'text'
  is_nullable: 0

=head2 first_genotype_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 second_genotype_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "metagenotype_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "identifier",
  { data_type => "text", is_nullable => 0 },
  "type",
  { data_type => "text", is_nullable => 0 },
  "first_genotype_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "second_genotype_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</metagenotype_id>

=back

=cut

__PACKAGE__->set_primary_key("metagenotype_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<identifier_unique>

=over 4

=item * L</identifier>

=back

=cut

__PACKAGE__->add_unique_constraint("identifier_unique", ["identifier"]);

=head1 RELATIONS

=head2 first_genotype

Type: belongs_to

Related object: L<Canto::CursDB::Genotype>

=cut

__PACKAGE__->belongs_to(
  "first_genotype",
  "Canto::CursDB::Genotype",
  { genotype_id => "first_genotype_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 metagenotype_annotations

Type: has_many

Related object: L<Canto::CursDB::MetagenotypeAnnotation>

=cut

__PACKAGE__->has_many(
  "metagenotype_annotations",
  "Canto::CursDB::MetagenotypeAnnotation",
  { "foreign.metagenotype" => "self.metagenotype_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 second_genotype

Type: belongs_to

Related object: L<Canto::CursDB::Genotype>

=cut

__PACKAGE__->belongs_to(
  "second_genotype",
  "Canto::CursDB::Genotype",
  { genotype_id => "second_genotype_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-06-17 20:56:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RGUJg0lswFUky3cqCtnF5w

=head2 annotations

 Usage   : my $annotation_rs = $metagenotype->annotations();
 Function: Return the Annotations object related to this metagenotype via the
           metagenotype_annotations table
 Args    : None
 Returns : An Annotation ResultSet

=cut

__PACKAGE__->many_to_many('annotations' => 'metagenotype_annotations',
                          'annotation');

# an alias to make the calling code more readable
sub pathogen_genotype {
  my $self = shift;
  my $arg = shift;

  if ($arg) {
    return $self->first_genotype($arg);
  } else {
    return $self->first_genotype();
  }
}

# an alias to make the calling code more readable
sub host_genotype {
  my $self = shift;
  my $arg = shift;

  if ($arg) {
    return $self->second_genotype($arg);
  } else {
    return $self->second_genotype();
  }
}


=head2 feature_id

 Usage   : $metagenotype->feature_id()
 Function: Return the metagenotype_id of this genotype.  This is an alias for
           metagenotype_id() that exists to make gene and genotype handling easier.

=cut

sub feature_id
{
  my $self = shift;

  return $self->metagenotype_id();
}

=head2 feature_type

 Usage   : $metagenotype->feature_type();
 Function: Return 'metagenotype'.  This exists to make gene and genotype handling
           easier.

=cut

sub feature_type
{
  return 'metagenotype';
}

# aliases to make Metagenotype act a bit like a Gene
sub all_annotations
{
  my $self = shift;

  return $self->annotations();
}

sub display_name
{
  my $self = shift;
  my $config = shift;

  return 'pathogen: ' .$self->pathogen_genotype->display_name($config) . ' / host: ' .
    $self->host_genotype->display_name($config);
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
