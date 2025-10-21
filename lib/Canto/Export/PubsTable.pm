package Canto::Export::PubsTable;

=head1 NAME

Canto::Export::PubsTable - Code to publication details as a table

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Export::PubsTable

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2025 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use Moose;
use Carp;

use Canto::Track::Serialise;

with 'Canto::Role::Configurable';
with 'Canto::Role::Exporter';

=head2 export

 Usage   : my ($count, $table) = $exporter->export($config);
 Function: Return the publication table
 Args    : $config - a Canto::Config object
 Return  : (count of sessions exported, publication table)
           The publication table is a list (rows) of lists.
           Each row contains the PubMed ID and the triage status.

=cut

sub export
{
  my $self = shift;

  my $config = $self->config();

  my $track_schema = Canto::TrackDB->new(config => $config);

  my $track_dbh = $track_schema->storage()->dbh();

  my $sth =
    $track_dbh->prepare("select uniquename, t.name from pub join cvterm t on t.cvterm_id = pub.triage_status_id;");

  my $pub_triage_mapping = $config->{export}->{pub_triage_mapping};

  $sth->execute();

  my $count = 0;
  my $results = '';

  while (my ($pmid, $triage_status) = $sth->fetchrow_array()) {
    $count++;
    if (exists $pub_triage_mapping->{$triage_status}) {
      $triage_status = $pub_triage_mapping->{$triage_status};
    }
    $results .= "$pmid\t$triage_status\n";
  }

  return ($count, $results);
}

