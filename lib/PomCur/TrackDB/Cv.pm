use utf8;
package PomCur::TrackDB::Cv;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PomCur::TrackDB::Cv

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<cv>

=cut

__PACKAGE__->table("cv");

=head1 ACCESSORS

=head2 cv_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 definition

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "cv_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "definition",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</cv_id>

=back

=cut

__PACKAGE__->set_primary_key("cv_id");

=head1 RELATIONS

=head2 cvterms

Type: has_many

Related object: L<PomCur::TrackDB::Cvterm>

=cut

__PACKAGE__->has_many(
  "cvterms",
  "PomCur::TrackDB::Cvterm",
  { "foreign.cv_id" => "self.cv_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07017 @ 2012-04-12 03:42:23
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ohkpdW4XrNJ1TmMZPxJ6ZA


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
