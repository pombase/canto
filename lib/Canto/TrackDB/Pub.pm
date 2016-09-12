use utf8;
package Canto::TrackDB::Pub;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::TrackDB::Pub

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<pub>

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

=head2 corresponding_author

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

=head2 citation

  data_type: 'text'
  is_nullable: 1

=head2 publication_date

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
  "corresponding_author",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "title",
  { data_type => "text", is_nullable => 1 },
  "abstract",
  { data_type => "text", is_nullable => 1 },
  "authors",
  { data_type => "text", is_nullable => 1 },
  "affiliation",
  { data_type => "text", is_nullable => 1 },
  "citation",
  { data_type => "text", is_nullable => 1 },
  "publication_date",
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

=head1 PRIMARY KEY

=over 4

=item * L</pub_id>

=back

=cut

__PACKAGE__->set_primary_key("pub_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<uniquename_unique>

=over 4

=item * L</uniquename>

=back

=cut

__PACKAGE__->add_unique_constraint("uniquename_unique", ["uniquename"]);

=head1 RELATIONS

=head2 corresponding_author

Type: belongs_to

Related object: L<Canto::TrackDB::Person>

=cut

__PACKAGE__->belongs_to(
  "corresponding_author",
  "Canto::TrackDB::Person",
  { person_id => "corresponding_author" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 curation_priority

Type: belongs_to

Related object: L<Canto::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "curation_priority",
  "Canto::TrackDB::Cvterm",
  { cvterm_id => "curation_priority_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 curs

Type: has_many

Related object: L<Canto::TrackDB::Curs>

=cut

__PACKAGE__->has_many(
  "curs",
  "Canto::TrackDB::Curs",
  { "foreign.pub" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 load_type

Type: belongs_to

Related object: L<Canto::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "load_type",
  "Canto::TrackDB::Cvterm",
  { cvterm_id => "load_type_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 pub_curation_statuses

Type: has_many

Related object: L<Canto::TrackDB::PubCurationStatus>

=cut

__PACKAGE__->has_many(
  "pub_curation_statuses",
  "Canto::TrackDB::PubCurationStatus",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_organisms

Type: has_many

Related object: L<Canto::TrackDB::PubOrganism>

=cut

__PACKAGE__->has_many(
  "pub_organisms",
  "Canto::TrackDB::PubOrganism",
  { "foreign.pub" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pubmed_type

Type: belongs_to

Related object: L<Canto::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "pubmed_type",
  "Canto::TrackDB::Cvterm",
  { cvterm_id => "pubmed_type" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 pubprops

Type: has_many

Related object: L<Canto::TrackDB::Pubprop>

=cut

__PACKAGE__->has_many(
  "pubprops",
  "Canto::TrackDB::Pubprop",
  { "foreign.pub_id" => "self.pub_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 triage_status

Type: belongs_to

Related object: L<Canto::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "triage_status",
  "Canto::TrackDB::Cvterm",
  { cvterm_id => "triage_status_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 type

Type: belongs_to

Related object: L<Canto::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "type",
  "Canto::TrackDB::Cvterm",
  { cvterm_id => "type_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07045 @ 2016-09-12 17:08:45
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kV+HI9FlPkYpw49YhcmUNg

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

use Carp;
use Canto::Util;

sub new {
  my ( $class, $attrs ) = @_;

  if (defined $attrs->{added_date}) {
    croak "don't set added_date in the constructor - it defaults to now";
  }

  $attrs->{added_date} = Canto::Util::get_current_datetime();

  my $new = $class->next::method($attrs);

  return $new;
}

# return a ResultSet for the curs objects of this pub that don't have the
# status "EXPORTED"
sub not_exported_curs
{
  my $self = shift;

  my $curs_rs = $self->curs();

  my $where = 'EXISTS (SELECT cursprop_id FROM cursprop p, cvterm t ' .
    'WHERE p.curs = me.curs_id AND ' .
    "t.cvterm_id = p.type AND t.name = 'annotation_status' AND " .
    "p.value <> 'EXPORTED')";

  return $curs_rs->search({}, { where => \$where });
}

# You can replace this text with custom content, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
