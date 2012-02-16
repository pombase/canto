package PomCur::TrackDB::Pub;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::TrackDB::Pub

=cut

__PACKAGE__->table("pub");

=head1 ACCESSORS

=head2 pub_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 uniquename

  data_type: 'text'
  is_nullable: 0

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 assigned_curator

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 title

  data_type: 'text'
  is_nullable: 1

=head2 abstract

  data_type: 'text'
  is_nullable: 1

=head2 authors

  data_type: 'text'
  is_nullable: 1

=head2 affiliation

  data_type: 'text'
  is_nullable: 1

=head2 pubmed_type

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 triage_status_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 load_type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 curation_priority_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 added_date

  data_type: 'timestamp'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "pub_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "uniquename",
  { data_type => "text", is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "assigned_curator",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "title",
  { data_type => "text", is_nullable => 1 },
  "abstract",
  { data_type => "text", is_nullable => 1 },
  "authors",
  { data_type => "text", is_nullable => 1 },
  "affiliation",
  { data_type => "text", is_nullable => 1 },
  "pubmed_type",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "triage_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "load_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "curation_priority_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "added_date",
  { data_type => "timestamp", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("pub_id");
__PACKAGE__->add_unique_constraint("uniquename_unique", ["uniquename"]);

=head1 RELATIONS

=head2 curation_priority

Type: belongs_to

Related object: L<PomCur::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "curation_priority",
  "PomCur::TrackDB::Cvterm",
  { cvterm_id => "curation_priority_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 load_type

Type: belongs_to

Related object: L<PomCur::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "load_type",
  "PomCur::TrackDB::Cvterm",
  { cvterm_id => "load_type_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 triage_status

Type: belongs_to

Related object: L<PomCur::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "triage_status",
  "PomCur::TrackDB::Cvterm",
  { cvterm_id => "triage_status_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 pubmed_type

Type: belongs_to

Related object: L<PomCur::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "pubmed_type",
  "PomCur::TrackDB::Cvterm",
  { cvterm_id => "pubmed_type" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 assigned_curator

Type: belongs_to

Related object: L<PomCur::TrackDB::Person>

=cut

__PACKAGE__->belongs_to(
  "assigned_curator",
  "PomCur::TrackDB::Person",
  { person_id => "assigned_curator" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 type

Type: belongs_to

Related object: L<PomCur::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "type",
  "PomCur::TrackDB::Cvterm",
  { cvterm_id => "type_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 pubprops

Type: has_many

Related object: L<PomCur::TrackDB::Pubprop>

=cut

__PACKAGE__->has_many(
  "pubprops",
  "PomCur::TrackDB::Pubprop",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_curation_statuses

Type: has_many

Related object: L<PomCur::TrackDB::PubCurationStatus>

=cut

__PACKAGE__->has_many(
  "pub_curation_statuses",
  "PomCur::TrackDB::PubCurationStatus",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_organisms

Type: has_many

Related object: L<PomCur::TrackDB::PubOrganism>

=cut

__PACKAGE__->has_many(
  "pub_organisms",
  "PomCur::TrackDB::PubOrganism",
  { "foreign.pub" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 curs

Type: has_many

Related object: L<PomCur::TrackDB::Curs>

=cut

__PACKAGE__->has_many(
  "curs",
  "PomCur::TrackDB::Curs",
  { "foreign.pub" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2012-02-16 09:45:18
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Gx+zkWm1egEQ5efA2x2mMQ

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

use Carp;
use PomCur::Util;

sub new {
  my ( $class, $attrs ) = @_;

  if (defined $attrs->{added_date}) {
    croak "don't set added_date in the constructor - it defaults to now";
  }

  $attrs->{added_date} = PomCur::Util::get_current_datetime();

  my $new = $class->next::method($attrs);

  return $new;
}

1;


# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
