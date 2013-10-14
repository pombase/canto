package Canto::ChadoDB::Cvtermprop;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

Canto::ChadoDB::Cvtermprop

=head1 DESCRIPTION

Additional extensible properties can be attached to a cvterm using this table. Corresponds to -AnnotationProperty- in W3C OWL format.

=cut

__PACKAGE__->table("cvtermprop");

=head1 ACCESSORS

=head2 cvtermprop_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'cvtermprop_cvtermprop_id_seq'

=head2 cvterm_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The name of the property or slot is a cvterm. The meaning of the property is defined in that cvterm.

=head2 value

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

The value of the property, represented as text. Numeric values are converted to their text representation.

=head2 rank

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

Property-Value ordering. Any
cvterm can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used.

=cut

__PACKAGE__->add_columns(
  "cvtermprop_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "cvtermprop_cvtermprop_id_seq",
  },
  "cvterm_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "rank",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("cvtermprop_id");
__PACKAGE__->add_unique_constraint(
  "cvtermprop_cvterm_id_key",
  ["cvterm_id", "type_id", "value", "rank"],
);

=head1 RELATIONS

=head2 type

Type: belongs_to

Related object: L<Canto::ChadoDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "type",
  "Canto::ChadoDB::Cvterm",
  { cvterm_id => "type_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 cvterm

Type: belongs_to

Related object: L<Canto::ChadoDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "cvterm",
  "Canto::ChadoDB::Cvterm",
  { cvterm_id => "cvterm_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:48aHJvMxr//wdbgcmn7INQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
