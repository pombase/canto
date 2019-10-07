use utf8;
package Canto::CursDB::AlleleNote;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::CursDB::AlleleNote

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<allele_note>

=cut

__PACKAGE__->table("allele_note");

=head1 ACCESSORS

=head2 allele_note_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 allele

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 key

  data_type: 'text'
  is_nullable: 0

=head2 value

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "allele_note_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "allele",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "key",
  { data_type => "text", is_nullable => 0 },
  "value",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</allele_note_id>

=back

=cut

__PACKAGE__->set_primary_key("allele_note_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<key_unique>

=over 4

=item * L</key>

=back

=cut

__PACKAGE__->add_unique_constraint("key_unique", ["key"]);

=head1 RELATIONS

=head2 allele

Type: belongs_to

Related object: L<Canto::CursDB::Allele>

=cut

__PACKAGE__->belongs_to(
  "allele",
  "Canto::CursDB::Allele",
  { allele_id => "allele" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-10-08 11:24:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HJEN6jNVmeIZJWAOSzs3RA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
