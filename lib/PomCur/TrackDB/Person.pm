use utf8;
package PomCur::TrackDB::Person;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PomCur::TrackDB::Person

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<person>

=cut

__PACKAGE__->table("person");

=head1 ACCESSORS

=head2 person_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 email_address

  data_type: 'text'
  is_nullable: 0

=head2 role

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 lab

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 session_data

  data_type: 'text'
  is_nullable: 1

=head2 password

  data_type: 'text'
  is_nullable: 1

=head2 added_date

  data_type: 'timestamp'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "person_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "email_address",
  { data_type => "text", is_nullable => 0 },
  "role",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "lab",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "session_data",
  { data_type => "text", is_nullable => 1 },
  "password",
  { data_type => "text", is_nullable => 1 },
  "added_date",
  { data_type => "timestamp", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</person_id>

=back

=cut

__PACKAGE__->set_primary_key("person_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<email_address_unique>

=over 4

=item * L</email_address>

=back

=cut

__PACKAGE__->add_unique_constraint("email_address_unique", ["email_address"]);

=head1 RELATIONS

=head2 curs

Type: has_many

Related object: L<PomCur::TrackDB::Curs>

=cut

__PACKAGE__->has_many(
  "curs",
  "PomCur::TrackDB::Curs",
  { "foreign.assigned_curator" => "self.person_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 lab

Type: belongs_to

Related object: L<PomCur::TrackDB::Lab>

=cut

__PACKAGE__->belongs_to(
  "lab",
  "PomCur::TrackDB::Lab",
  { lab_id => "lab" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 labs

Type: has_many

Related object: L<PomCur::TrackDB::Lab>

=cut

__PACKAGE__->has_many(
  "labs",
  "PomCur::TrackDB::Lab",
  { "foreign.lab_head" => "self.person_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pubs

Type: has_many

Related object: L<PomCur::TrackDB::Pub>

=cut

__PACKAGE__->has_many(
  "pubs",
  "PomCur::TrackDB::Pub",
  { "foreign.assigned_curator" => "self.person_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 role

Type: belongs_to

Related object: L<PomCur::TrackDB::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "role",
  "PomCur::TrackDB::Cvterm",
  { cvterm_id => "role" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07017 @ 2012-03-26 04:28:51
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:itxL224SFYB29BV2KzlNsA

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

=head2 is_admin

 Usage   : if ($person->is_admin()) { ...}
 Function: Return true if this person has the admin role

=cut
sub is_admin
{
  my $self = shift;

  if (defined $self->role() && $self->role()->name() eq 'admin') {
    return 1;
  } else {
    return 0;
  }
}

1;


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
