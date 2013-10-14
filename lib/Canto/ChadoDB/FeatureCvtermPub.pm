package Canto::ChadoDB::FeatureCvtermPub;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

Canto::ChadoDB::FeatureCvtermPub

=head1 DESCRIPTION

Secondary pubs for an
association. Each feature_cvterm association is supported by a single
primary publication. Additional secondary pubs can be added using this
linking table (in a GO gene association file, these corresponding to
any IDs after the pipe symbol in the publications column.

=cut

__PACKAGE__->table("feature_cvterm_pub");

=head1 ACCESSORS

=head2 feature_cvterm_pub_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_cvterm_pub_feature_cvterm_pub_id_seq'

=head2 feature_cvterm_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 pub_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "feature_cvterm_pub_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_cvterm_pub_feature_cvterm_pub_id_seq",
  },
  "feature_cvterm_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pub_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("feature_cvterm_pub_id");
__PACKAGE__->add_unique_constraint("feature_cvterm_pub_c1", ["feature_cvterm_id", "pub_id"]);

=head1 RELATIONS

=head2 pub

Type: belongs_to

Related object: L<Canto::ChadoDB::Pub>

=cut

__PACKAGE__->belongs_to(
  "pub",
  "Canto::ChadoDB::Pub",
  { pub_id => "pub_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 feature_cvterm

Type: belongs_to

Related object: L<Canto::ChadoDB::FeatureCvterm>

=cut

__PACKAGE__->belongs_to(
  "feature_cvterm",
  "Canto::ChadoDB::FeatureCvterm",
  { feature_cvterm_id => "feature_cvterm_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ux0UM6962MR1VJCtTLc+og


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
