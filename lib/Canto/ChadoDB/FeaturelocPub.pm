package Canto::ChadoDB::FeaturelocPub;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

Canto::ChadoDB::FeaturelocPub

=head1 DESCRIPTION

Provenance of featureloc. Linking table between featurelocs and publications that mention them.

=cut

__PACKAGE__->table("featureloc_pub");

=head1 ACCESSORS

=head2 featureloc_pub_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'featureloc_pub_featureloc_pub_id_seq'

=head2 featureloc_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 pub_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "featureloc_pub_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "featureloc_pub_featureloc_pub_id_seq",
  },
  "featureloc_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pub_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("featureloc_pub_id");
__PACKAGE__->add_unique_constraint("featureloc_pub_c1", ["featureloc_id", "pub_id"]);

=head1 RELATIONS

=head2 featureloc

Type: belongs_to

Related object: L<Canto::ChadoDB::Featureloc>

=cut

__PACKAGE__->belongs_to(
  "featureloc",
  "Canto::ChadoDB::Featureloc",
  { featureloc_id => "featureloc_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

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


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qZZh+tGx0+brjtMj1KgLEA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
