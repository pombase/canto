use utf8;
package Canto::TrackDB::Curs;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::TrackDB::Curs

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<curs>

=cut

__PACKAGE__->table("curs");

=head1 ACCESSORS

=head2 curs_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 pub

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 curs_key

  data_type: 'text'
  is_nullable: 0

=head2 creation_date

  data_type: 'timestamp'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "curs_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "pub",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "curs_key",
  { data_type => "text", is_nullable => 0 },
  "creation_date",
  { data_type => "timestamp", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</curs_id>

=back

=cut

__PACKAGE__->set_primary_key("curs_id");

=head1 RELATIONS

=head2 curs_curators

Type: has_many

Related object: L<Canto::TrackDB::CursCurator>

=cut

__PACKAGE__->has_many(
  "curs_curators",
  "Canto::TrackDB::CursCurator",
  { "foreign.curs" => "self.curs_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cursprops

Type: has_many

Related object: L<Canto::TrackDB::Cursprop>

=cut

__PACKAGE__->has_many(
  "cursprops",
  "Canto::TrackDB::Cursprop",
  { "foreign.curs" => "self.curs_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub

Type: belongs_to

Related object: L<Canto::TrackDB::Pub>

=cut

__PACKAGE__->belongs_to(
  "pub",
  "Canto::TrackDB::Pub",
  { pub_id => "pub" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-10-13 23:27:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3cOTosKGnlNpCLc37TedyQ


__PACKAGE__->meta->make_immutable(inline_constructor => 0);

__PACKAGE__->many_to_many('curators' => 'curs_curators',
                          'curator');

use Carp;
use Canto::Util;

sub new {
  my ( $class, $attrs ) = @_;

  if (defined $attrs->{creation_date}) {
    croak "don't set creation_date in the constructor - it defaults to now";
  }

  $attrs->{creation_date} = Canto::Util::get_current_datetime();

  my $new = $class->next::method($attrs);

  return $new;
}

=head2 prop_value

 Usage   : $value = $curs->prop_value('some_cursprop_type_name');
 Function: Lookup a Cursprop value by name.  If the property doesn't
           exist return undef.
 Args    : $prop_name
 Return  : The Cursprop value

=cut

sub prop_value
{
  my $self = shift;
  my $prop_name = shift;

  my $prop =
    $self->cursprops()->search({ 'type.name' => $prop_name,
                                 'cv.name' => 'Canto cursprop types' },
                               { join => { type => 'cv' } })->first();

  if (defined $prop) {
    return $prop->value();
  } else {
    return undef;
  }
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
