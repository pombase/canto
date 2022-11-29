package Canto::UniProt::UniProtUtil;

=head1 NAME

Canto::UniProt::UniProtUtil - Utilities for accessing UniProt data

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::UniProt::UniProtUtil

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

use strict;
use warnings;
use Carp;

use XML::Simple;
use LWP::UserAgent;

sub _content
{
  my $data = shift;

  if (ref $data) {
    return $data->{content};
  } else {
    return $data;
  }
}

=head2 parse_results

 Usage   : my @res = Canto::UniProt::UniProtUtil::parse_results($xml);
 Function: Parse UniProt XML entries and return an array of the results

=cut

sub parse_results
{
  my $xml = shift;

  if ($xml =~ /^\s*$/) {
    return ();
  }

  my $res_hash = XMLin($xml, ForceArray => 1, KeyAttr => []);
  my @ret = ();

  for my $entry (@{$res_hash->{entry}}) {
    my $full_name_parent_element;
    if ($entry->{protein}->[0]->{recommendedName}) {
      $full_name_parent_element = $entry->{protein}->[0]->{recommendedName};
    } else {
      $full_name_parent_element = $entry->{protein}->[0]->{submittedName};
    }

    my $full_name = _content($full_name_parent_element->[0]->{fullName}->[0]);

    my @synonyms = ();

    my $name;

    if (defined $entry->{gene}->[0]->{name}) {
      for my $synonym (@{$entry->{gene}->[0]->{name}}) {
        my $synonym_content = _content($synonym);

        if ($synonym->{type} eq 'primary') {
          $name = $synonym_content;
        } else {
          push @synonyms, $synonym_content;
        }
      }

      if (!defined $name) {
        for my $synonym (@{$entry->{gene}->[0]->{name}}) {
          my $synonym_content = _content($synonym);

          if ($synonym->{type} eq 'ordered locus') {
            $name = $synonym_content;
            last;
          }
        }
      }

      if (!defined $name) {
        for my $synonym (@{$entry->{gene}->[0]->{name}}) {
          my $synonym_content = _content($synonym);

          if ($synonym->{type} eq 'ORF') {
            $name = $synonym_content;
            last;
          }
        }
      }
    }

    if (defined $name) {
      @synonyms = grep { $_ ne $name } @synonyms;
    }

    if (!defined $name) {
      $name = _content($entry->{name}->[0]);
    }

    my $accession = _content($entry->{accession}->[0]);

    my $organism_full_name = 'Unknown unknown';
    my $organism_common_name = undef;

    for my $org_details (@{$entry->{organism}->[0]->{name}}) {
      if ($org_details->{type} eq 'scientific') {
        $organism_full_name = _content($org_details);
      }
      if ($org_details->{type} eq 'common') {
        $organism_common_name = _content($org_details);
      }
    }

    my $taxonid = 0;

    for my $org_details (@{$entry->{organism}->[0]->{dbReference}}) {
      if ($org_details->{type} eq 'NCBI Taxonomy') {
        $taxonid = $org_details->{id};
      }
    }

    push @ret, {
      primary_name => $name,
      primary_identifier => $accession,
      product => $full_name,
      synonyms => [@synonyms],
      organism_full_name => $organism_full_name,
      organism_common_name => $organism_common_name,
      organism_taxonid => $taxonid,
    };
  }

  return @ret;
}

=head2 retrieve_entries

 Usage   : my @results =
             Canto::UniProt::UniProtUtil::retrieve_entries($config, [@ids]);
 Function: Return a list of the details from matching entries in this format:
           [ {
                primary_name => "..."
                primary_identifier => "...",  # the UniProt accession
                product => "..."
                synonyms => ["synonym1", ...],
                organism_full_name => "Genus species"
                organism_common_name => "..."
                organism_taxonid => 1234,
             },
             {
                ...
             },
             ...
           ]
 Args    : $config - the Canto::Config object

=cut
sub retrieve_entries
{
  my $config = shift;
  my $identifiers_ref = shift;

  my @identifiers = @$identifiers_ref;

  my $batch_service_url = $config->{webservices}->{uniprot_batch_lookup_url};

  # copied from http://www.uniprot.org/faq/28#batch_retrieval_of_entries
  my $agent = LWP::UserAgent->new;

  my $url = $batch_service_url . join (' OR ', map { "accession:$_" } @identifiers);

  my $response = $agent->get($url, 'Accept-Encoding' => 'gzip, x-gzip, deflate');

  while (my $wait = $response->header('Retry-After')) {
    print STDERR "Waiting ($wait)...\n";
    sleep $wait;
    $response = $agent->get($response->base);
  }

  if ($response->is_success) {
    my $xml = $response->decoded_content();
    return parse_results($xml);
  } else {
    if ($response->status_line() =~ /^400 /) {
      # illegal identifier like "cdc11"
      return ();
    } else {
      die 'Failed, got ' . $response->status_line .
        ' for ' . $response->request->uri .
        " ($batch_service_url + @identifiers)\n";
    }
  }
}

1;
