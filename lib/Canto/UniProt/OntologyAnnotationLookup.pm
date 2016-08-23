package Canto::UniProt::OntologyAnnotationLookup;

=head1 NAME

Canto::UniProt::OntologyAnnotationLookup - Code for looking up ontology
    annotation via the QuickGO web service

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::UniProt::OntologyAnnotationLookup

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

use LWP::UserAgent;

with 'Canto::Role::Configurable';

use YAML qw(Load Dump);
use IO::String;

use Memoize;
use Memoize::Expire;

use Canto::Track;

tie my %cache => 'Memoize::Expire', LIFETIME => 60*60*2;

# this might help a little bit, but as there is more than one server,
# the cache is mostly not going to be hit - need to use memcached
memoize '_cached_lookup', SCALAR_CACHE => [HASH => \%cache];

sub _cached_lookup
{
  my $config = shift;
  my $pub_uniquename = shift;
  my $gene_identifier = shift;
  my $wanted_ontology_name = shift;

  my $ontology_lookup = Canto::Track::get_adaptor($config, 'ontology');

  my $url =
    $config->{webservices}->{quickgo_annotation_lookup_url} . $pub_uniquename;

  my $ua = LWP::UserAgent->new;
  my $res = $ua->get($url);
  my $content = $res->decoded_content();

  my %ontology_name_lookup = (C => 'cellular_component',
                              P => 'biological_process',
                              F => 'molecular_function');

  my @ret = ();

  my $io = IO::String->new($content);

  while (my $line = <$io>) {
    next if $line =~ /^!/;

    my @vals = split(/\t/, $line);

    my ($proddb,
        $prodacc,
        $prodsymbol,
        $qualifier,
        $termacc,
        $ref,
        $evcode,
        $with,
        $aspect,
        $prodname,
        $prodsyn,
        $prodtype,
        $prodtaxa,
        $assocdate,
        $source_db,
        $properties,            # GAF2.0
        $isoform) = @vals;      # GAF2.0

    if (defined $gene_identifier && $gene_identifier ne $prodacc) {
      next;
    }

    # backward compatibility GAF2.0 -> GAF1.0
    $properties = '' unless defined $properties;
    $isoform = '' unless defined $isoform;
    $assocdate = '' unless defined $assocdate;
    $source_db = '' unless defined $source_db;

    my $returned_ontology_name = $ontology_name_lookup{$aspect};

    next unless defined $returned_ontology_name;

    next unless $returned_ontology_name eq $wanted_ontology_name;

    my @ids = split (/\|/, $prodsyn);

    my $entry_name = $ids[0];

    (my $taxonid = $prodtaxa) =~ s/taxon://;

    my $term_name = '';

    my $result = $ontology_lookup->lookup_by_id(id => $termacc);

    if (defined $result) {
      $term_name = $result->{name};
    }

    push @ret, {
      gene => {
        identifier => $prodacc,
        name => $entry_name,
        organism_taxonid => $taxonid,
      },
      ontology_term => {
        ontology_name => $returned_ontology_name,
        term_name => $term_name,
        ontid => $termacc,
      },
      publication => $pub_uniquename,
      evidence_code => $evcode,
    };
  }

  return Dump(scalar(@ret), [@ret]);
}

=head2

 Usage   : my $res = Canto::Chado::OntologyAnnotationLookup($options);
 Function: lookup ontology annotation in a Chado database
 Args    : $options->{pub_uniquename} - the identifier of the publication,
               usually the PubMed ID to get annotations for
           $options->{gene_identifier} - the gene identifier to constraint the
               search with; only annotations for the gene are returned
           $options->{ontology_name} - the ontology name to use to restrict the
               search; only annotations from this ontology are returned
 Returns : An array reference of annotation results:
            [ {
              gene => {
                identifier => "SPAC22F3.13",
                name => 'tsc1',
                organism_taxonid => 4896
              },
              ontology_term => {
                ontology_name => 'molecular_function',
                term_name => 'regulation of conjugation ...',
                ontid => 'GO:0031137',
              },
              publication => {
                uniquename => 'PMID:10467002',
              },
              evidence_code => 'IMP',
            }, ... ]

=cut
sub lookup
{
  my $self = shift;
  my $args_ref = shift;
  my %args = %{$args_ref};

  my $pub_uniquename = $args{pub_uniquename};
  my $gene_identifier = $args{gene_identifier};
  my $ontology_name = $args{ontology_name};

  die "no ontology_name" unless defined $ontology_name;

  return Load(_cached_lookup($self->config(), $pub_uniquename,
                             $gene_identifier, $ontology_name));
}
1;
