use utf8;
package Canto::TrackDB::Cv;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::TrackDB::Cv

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

Related object: L<Canto::TrackDB::Cvterm>

=cut

__PACKAGE__->has_many(
  "cvterms",
  "Canto::TrackDB::Cvterm",
  { "foreign.cv_id" => "self.cv_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-10-13 23:27:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:greknT9yQgCBmIG8PPnhLw


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
