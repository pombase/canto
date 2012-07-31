use utf8;
package PomCur::TrackDB::Allele;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PomCur::TrackDB::Allele

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<allele>

=cut

__PACKAGE__->table("allele");

=head1 ACCESSORS

=head2 allele_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 primary_identifier

  data_type: 'text'
  is_nullable: 0

=head2 primary_name

  data_type: 'text'
  is_nullable: 1

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 gene

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "allele_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "primary_identifier",
  { data_type => "text", is_nullable => 0 },
  "primary_name",
  { data_type => "text", is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "gene",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</allele_id>

=back

=cut

__PACKAGE__->set_primary_key("allele_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<primary_identifier_unique>

=over 4

=item * L</primary_identifier>

=back

=cut

__PACKAGE__->add_unique_constraint("primary_identifier_unique", ["primary_identifier"]);

=head1 RELATIONS

=head2 gene

Type: belongs_to

Related object: L<PomCur::TrackDB::Gene>

=cut

__PACKAGE__->belongs_to(
  "gene",
  "PomCur::TrackDB::Gene",
  { gene_id => "gene" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07017 @ 2012-04-23 03:55:13
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WBYeFJGM2uNPtJvwXEdtkw

=head2 display_name

 Usage   : my $allele_display_name = $allele->display_name();
 Function: Return the user friendly name of this allele like:
           "name(description)"
 Args    : none

=cut
sub display_name
{
  my $self = shift;

  return PomCur::Curs::Utils::make_allele_display_name($self->name(),
                                                       $self->description());
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
