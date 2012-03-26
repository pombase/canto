use utf8;
package PomCur::TrackDB::CvtermDbxref;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PomCur::TrackDB::CvtermDbxref

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<cvterm_dbxref>

=cut

__PACKAGE__->table("cvterm_dbxref");

=head1 ACCESSORS

=head2 cvterm_dbxref_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 cvterm_id

  data_type: 'integer'
  is_nullable: 0

=head2 dbxref_id

  data_type: 'integer'
  is_nullable: 0

=head2 is_for_definition

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "cvterm_dbxref_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "cvterm_id",
  { data_type => "integer", is_nullable => 0 },
  "dbxref_id",
  { data_type => "integer", is_nullable => 0 },
  "is_for_definition",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</cvterm_dbxref_id>

=back

=cut

__PACKAGE__->set_primary_key("cvterm_dbxref_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<cvterm_id_dbxref_id_unique>

=over 4

=item * L</cvterm_id>

=item * L</dbxref_id>

=back

=cut

__PACKAGE__->add_unique_constraint("cvterm_id_dbxref_id_unique", ["cvterm_id", "dbxref_id"]);


# Created by DBIx::Class::Schema::Loader v0.07017 @ 2012-03-26 04:28:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:nliQ+xPMkpRfxRLkQ1Ioog


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
