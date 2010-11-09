package PomCur::Curs::Utils;

=head1 NAME

PomCur::Curs::Utils - Utilities for Curs code

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Curs::Utils

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use Moose;

=head2 get_annotation_table

 Usage   : my @annotations =
             PomCur::Curs::Utils::get_annotation_table($config, $schema);
 Function: Return a table of the current annotations
 Args    : $config - the PomCur::Config object
           $schema - a PomCur::CursDB object
 Returns : An array of hashes containing the annotation in the form:
           [ { gene_identifier => 'SPCC1739.11c', gene_name => 'cdc11',
               annotation_type => 'molecular_function',
               annotation_id => 1234, term_ontid => 'GO:0055085',
               term_name => 'transmembrane transport',
               evidence_code => 'IDA',
               evidence_type_name => 'Inferred from direct assay' },
             { gene_identifier => '...', ... }, ]
           where annotation_id is the id of the Annotation object for this
           annotation

=cut
sub get_annotation_table
{
  my $config = shift;
  my $schema = shift;

  my @annotations = ();

  my $gene_rs = $schema->resultset('Gene');

  my %evidence_types = %{$config->{evidence_types}};
  my %annotation_types_config = %{$config->{annotation_types}};

  my $lookup = PomCur::Track::get_lookup($config, 'go');

  while (defined (my $gene = $gene_rs->next())) {
    my $an_rs = $gene->annotations();

    my %gene_annotations = ();

    while (defined (my $annotation = $an_rs->next())) {
      my $data = $annotation->data();
      my $term_ontid = $data->{term_ontid};
      next unless defined $term_ontid and length $term_ontid > 0;

      my $annotation_type = $annotation->type();
      my $annotation_type_config = $annotation_types_config{$annotation_type};
      my $annotation_type_display_name =
        $annotation_type_config->{display_name};
      my $annotation_type_abbreviation =
        $annotation_type_config->{abbreviation};

      my $pubmedid = $annotation->pub()->pubmedid();
      my $result =
        $lookup->web_service_lookup(ontology_name => $annotation_type,
                                    search_string => $term_ontid);

      my $term_name = $result->[0]->{name};
      my $evidence_code = $data->{evidence_code};
      my $evidence_type_name = $evidence_types{$evidence_code};

      (my $short_date = $annotation->creation_date()) =~ s/-//g;

      push @{$gene_annotations{$annotation_type}}, {
        gene_identifier => $gene->primary_identifier(),
        gene_name => $gene->primary_name() || '',
        gene_product => $gene->product(),
        annotation_type => $annotation_type,
        annotation_type_display_name => $annotation_type_display_name,
        annotation_type_abbreviation => $annotation_type_abbreviation,
        annotation_id => $annotation->annotation_id(),
        pubmedid => $pubmedid,
        term_ontid => $term_ontid,
        term_name => $term_name,
        evidence_code => $evidence_code,
        evidence_type_name => $evidence_type_name,
        creation_date => $annotation->creation_date(),
        creation_date_short => $short_date,
        taxonid => $gene->organism()->taxonid(),
      };
    }

    for my $annotation_type_config (@{$config->{annotation_type_list}}) {
      my $annotation_type_name = $annotation_type_config->{name};

      for my $annotation_data (@{$gene_annotations{$annotation_type_name}}) {
        push @annotations, $annotation_data;
      }
    }
  }

  return @annotations;
}

1;
