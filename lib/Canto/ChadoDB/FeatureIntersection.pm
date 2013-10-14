package Canto::ChadoDB::FeatureIntersection;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

Canto::ChadoDB::FeatureIntersection

=head1 DESCRIPTION

set-intersection on interval defined by featureloc. featurelocs must meet

=cut

__PACKAGE__->table("feature_intersection");

=head1 ACCESSORS

=head2 subject_id

  data_type: 'integer'
  is_nullable: 1

=head2 object_id

  data_type: 'integer'
  is_nullable: 1

=head2 srcfeature_id

  data_type: 'integer'
  is_nullable: 1

=head2 subject_strand

  data_type: 'smallint'
  is_nullable: 1

=head2 object_strand

  data_type: 'smallint'
  is_nullable: 1

=head2 fmin

  data_type: 'integer'
  is_nullable: 1

=head2 fmax

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "subject_id",
  { data_type => "integer", is_nullable => 1 },
  "object_id",
  { data_type => "integer", is_nullable => 1 },
  "srcfeature_id",
  { data_type => "integer", is_nullable => 1 },
  "subject_strand",
  { data_type => "smallint", is_nullable => 1 },
  "object_strand",
  { data_type => "smallint", is_nullable => 1 },
  "fmin",
  { data_type => "integer", is_nullable => 1 },
  "fmax",
  { data_type => "integer", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:H0x7ND99+kbIvFQMY+RDgg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
