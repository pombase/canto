package Canto::Export::AlleleTable;

=head1 NAME

Canto::Export::AlleleTable - Export a table of all alleles from all sessions

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Export::AlleleTable

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2022 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

with 'Canto::Role::Configurable';
with 'Canto::Role::Exporter';

sub _annotation_count {
  my $allele = shift;

  my $annotation_count = 0;

  my @genotypes = $allele->genotypes()->all();

  map {
    my $genotype = $_;

    $annotation_count += $genotype->annotations();
  } @genotypes;

  return $annotation_count;
}

=head2 export

 Usage   : my ($count, $tsv_table) = $exporter->export($config);
 Function: Export a table of alleles
 Args    : $config - a Canto::Config object
 Return  : (count of sessions with alleles,
            allele TSV table as a string)

=cut

sub export
{
  my $self = shift;

  my $config = $self->config();
  my $track_schema = $self->track_schema();

  my $session_count = 0;
  my %alleles = ();

  my $allele_collect = sub {
    my $curs = shift;
    my $session = $curs->curs_key();

    my $curs_schema = shift;

    my $seen_allele = 0;

    my $allele_rs = $curs_schema->resultset('Allele')
      ->search({}, { prefetch => ['gene'] });

    for my $al ($allele_rs->all()) {
      my $gene = $al->gene();
      my $gene_systematic_id = $gene->primary_identifier();

      my $gene_proxy = Canto::Curs::GeneProxy->new(config => $config,
                                                   cursdb_gene => $gene);
      my $gene_name = $gene_proxy->primary_name() // '';

      my $allele_name = $al->name() // '';
      my $allele_type = $al->type() // '';
      my $allele_description = $al->description() // '';

      my @allele_synonyms = map {
        $_->synonym();
      } $al->allelesynonyms();

      my $reference = $curs->pub()->uniquename();

      my $annotation_count = _annotation_count($al);

      my $key = join "-:-", $allele_name, $allele_description, $allele_type;

      my $data = $alleles{$key};

      if (defined $data) {
        push @{$data->{allele_synonyms}}, @allele_synonyms;
        push @{$data->{references}}, $reference;
        push @{$data->{sessions}}, $session;
        $data->{annotation_count} += $annotation_count;
      } else {
        $data = {
          gene_systematic_id => $gene_systematic_id,
          gene_name => $gene_name,
          allele_name => $allele_name,
          allele_description => $allele_description,
          allele_type => $allele_type,
          allele_synonyms => [@allele_synonyms],
          references => [$reference],
          annotation_count => $annotation_count,
          sessions => [$session],
        };
        $alleles{$key} = $data;
      };

      $seen_allele = 1;
    }

    if ($seen_allele) {
      $session_count++;
    }
  };

  Canto::Track::curs_map($config, $track_schema, $allele_collect);

  my $result_table = join "\t", qw(
    gene_systematic_id
    allele_description
    gene_name
    allele_name
    allele_synonyms
    allele_type
    references
    annotation_count
    curation_sessions);

  $result_table .= "\n";

  map {
    my $data = $_;

    $result_table .= join "\t",
      $data->{gene_systematic_id},
      $data->{allele_description},
      $data->{gene_name},
      $data->{allele_name},
      (join "|", @{$data->{allele_synonyms}}),
      $data->{allele_type},
      (join ",", @{$data->{references}}),
      $data->{annotation_count},
      (join ",", @{$data->{sessions}});

    $result_table .= "\n";

  } values(%alleles);

  return ($session_count, $result_table);
}

1;
