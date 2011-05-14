package PomCur::UniProt::UniProtUtil;

=head1 NAME

PomCur::UniProt::UniProtUtil - Utilities for accessing UniProt data

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::UniProt::UniProtUtil

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

use XML::Simple;
use LWP::UserAgent;

sub _parse_results
{
  my $xml = shift;

  my $res_hash = XMLin($xml, ForceArray => ['entry', 'accession', 'dbReference']);

  my @ret = ();

  while (my ($name, $details) = each %{$res_hash->{entry}}) {
    my $full_name = $details->{protein}->{recommendedName}->{fullName};
    my @synonyms = map { $_->{content} } @{$details->{gene}->{name}};

    my $accession = $details->{accession}->[0];

    my $organism_full_name = 'Unknown unknown';

    for my $org_details (@{$details->{organism}->{name}}) {
      if ($org_details->{type} eq 'scientific') {
        $organism_full_name = $org_details->{content};
        last;
      }
    }

    my $taxonid = 0;

    for my $org_details (values %{$details->{organism}->{dbReference}}) {
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
      organism_taxonid => $taxonid,
    };
  }

  return @ret;
}

sub retrieve_entries
{
  my $config = shift;
  my $identifiers_ref = shift;

  my @identifiers = @$identifiers_ref;

  my $batch_service_url = $config->{webservices}->{uniprot_batch_lookup_url};

  # copied from http://www.uniprot.org/faq/28#batch_retrieval_of_entries
  my $agent = LWP::UserAgent->new;
  push @{$agent->requests_redirectable}, 'POST';

  my $response = $agent->post($batch_service_url,
                              [
                                'file' => [
                                  undef, 'upload.xml',
                                  Content_Type => 'text/plain',
                                  Content => "@identifiers"
                               ],
                               'format' => 'xml',
                               ],
                               'Content_Type' => 'form-data');

  while (my $wait = $response->header('Retry-After')) {
    print STDERR "Waiting ($wait)...\n";
    sleep $wait;
    $response = $agent->get($response->base);
  }

  if ($response->is_success) {
    my $xml = $response->content();

    return _parse_results($xml);
  } else {
    die 'Failed, got ' . $response->status_line .
      ' for ' . $response->request->uri . "\n";
  }
}

1;
