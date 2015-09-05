use utf8;
package Canto::TrackDB::ExtensionConfiguration;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Canto::TrackDB::ExtensionConfiguration

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<extension_configuration>

=cut

__PACKAGE__->table("extension_configuration");

=head1 ACCESSORS

=head2 extension_configuration_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 domain

  data_type: 'text'
  is_nullable: 0

=head2 extension_relation

  data_type: 'text'
  is_nullable: 0

=head2 range

  data_type: 'text'
  is_nullable: 0

=head2 display_text

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "extension_configuration_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "domain",
  { data_type => "text", is_nullable => 0 },
  "extension_relation",
  { data_type => "text", is_nullable => 0 },
  "range",
  { data_type => "text", is_nullable => 0 },
  "display_text",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</extension_configuration_id>

=back

=cut

__PACKAGE__->set_primary_key("extension_configuration_id");


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-09-05 18:57:17
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:pYOdk7sqpG6LS2uJC/tKsw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
