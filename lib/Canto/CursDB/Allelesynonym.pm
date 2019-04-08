use utf8;
package Canto::CursDB::Allelesynonym;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::CursDB::Allelesynonym

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<allelesynonym>

=cut

__PACKAGE__->table("allelesynonym");

=head1 ACCESSORS

=head2 allelesynonym

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 allele

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 edit_status

  data_type: 'text'
  is_nullable: 0

=head2 synonym

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "allelesynonym",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "allele",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "edit_status",
  { data_type => "text", is_nullable => 0 },
  "synonym",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</allelesynonym>

=back

=cut

__PACKAGE__->set_primary_key("allelesynonym");

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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-04-07 00:11:01
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5KLB/p6QHWuBXA312yYOwg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
