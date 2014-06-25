package Canto::Curs::ServiceUtils;

=head1 NAME

Canto::Curs::ServiceUtils - Helper functions for returning lists of data to the
                            browser.

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::ServiceUtils

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Moose;

use JSON;

use Canto::Curs::GeneProxy;
use Canto::Curs::Utils;

with 'Canto::Role::Configurable';

has curs_schema => (is => 'ro', isa => 'Canto::CursDB');

sub _get_annotation
{
  my $self = shift;

  my $curs_schema = $self->curs_schema();

  my $pub_rs = $curs_schema->resultset('Pub');

  my @pubs = $pub_rs->all();

  if (@pubs > 1) {
    die "internal error - more than one publication stored in session: ",
      $curs_schema->resultset('Metadata')->find({ key => 'curs_key' })->value();
  }

  if (@pubs == 0) {
    die "internal error - one publications stored in session: ",
      $curs_schema->resultset('Metadata')->find({ key => 'curs_key' })->value();
  }

  my $pub = $pubs[0];
  my $pub_uniquename = $pub->uniquename();

  my @annotation_type_list = @{$self->config()->{annotation_type_list}};

  return
    map {
      my ($completed_count, $rows) =
        Canto::Curs::Utils::get_annotation_table($self->config(),
                                                 $self->curs_schema(),
                                                 $_->{name});
      my @new_annotations = @$rows;

      ($completed_count, $rows) =
        Canto::Curs::Utils::get_existing_annotations($self->config(),
                                                     { pub_uniquename => $pub_uniquename,
                                                       annotation_type_name => $_->{name} });

      (@new_annotations, @$rows);
    } @annotation_type_list,
}

my %list_for_service_subs =
  (
    gene =>
      sub {
        my $self = shift;
        my $curs_schema = $self->curs_schema();
        my $gene_rs = $curs_schema->resultset('Gene');
        my @res = map {
          my $proxy =
            Canto::Curs::GeneProxy->new(config => $self->config(),
                                        cursdb_gene => $_);
          {
            primary_identifier => $proxy->primary_identifier(),
            primary_name => $proxy->primary_name(),
            gene_id => $proxy->gene_id(),
        }
        } $gene_rs->all();
      },
    genotype =>
      sub {
        my $self = shift;
        my $curs_schema = $self->curs_schema();
        my $genotype_rs = $curs_schema->resultset('Genotype');
        my @res = map {
          {
            identifier => $_->identifier(),
            name => $_->name(),
            genotype_id => $_->genotype_id(),
          }
        } $genotype_rs->all();
      },
    annotation => \&_get_annotation,
  );

=head2 list_for_service

 Usage   : my @result = $service_utils->list_for_service('genotype');
 Function: Return a summary list of the given curs data for sending as JSON to
           the browser.
 Args    : $type - the data type: eg. "genotype"
 Return  : a list of hash refs summarising a type.  Example for genotype:
           [ { identifier => 'h+ SPCC63.05-unk ssm4delta' }, { ... }, ... ]

=cut

sub list_for_service
{
  my $self = shift;
  my $type = shift;
  my @args = @_;

  my $proc = $list_for_service_subs{$type};

  if (defined $proc) {
    return [$proc->($self, @args)];
  } else {
    die "unknown list type: $type\n";
  }
}

=head2

 Usage   : $service_utils->change_annotation($annotation_id, 'new'|'existing',
                                             $changes);
 Function: Change an annotation in the Curs database based on the $changes hash.
 Args    : $annotation_id
           $status - 'new' if the annotation ID refers to a user created
                      annotation
                     'existing' if the ID refers to a existing Chado/external
                     ID, probably a feature_id
           $changes - a hash that specifies which parts of the annotation are
                      to change, with these possible keys:
                      comment - set the comment
 Return  :

=cut

sub change_annotation
{
  my $self = shift;
  my $annotation_id = shift;
  my $annotation_status = shift;
  my $changes = shift;

  my $annotation;

  if ($annotation_status eq 'new') {
    $annotation = $self->curs_schema()->resultset('Annotation')->find($annotation_id);
  } else {
    die "annotation status unsupported: $annotation_status\n";
  }

  my $data = $annotation->data();

  for my $key (keys %$changes) {
    $data->{$key} = $changes->{$key};
  }

  $annotation->data($data);
  $annotation->update();
}

1;
