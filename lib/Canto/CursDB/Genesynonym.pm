use utf8;
package Canto::CursDB::Genesynonym;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::CursDB::Genesynonym

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<genesynonym>

=cut

__PACKAGE__->table("genesynonym");

=head1 ACCESSORS

=head2 genesynonym_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 gene_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 identifier

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "genesynonym_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "gene_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "identifier",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</genesynonym_id>

=back

=cut

__PACKAGE__->set_primary_key("genesynonym_id");

=head1 RELATIONS

=head2 gene

Type: belongs_to

Related object: L<Canto::CursDB::Gene>

=cut

__PACKAGE__->belongs_to(
  "gene",
  "Canto::CursDB::Gene",
  { gene_id => "gene_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07017 @ 2012-03-26 04:28:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:P5Ao2w0MIBiuVGLHsr5uSg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
