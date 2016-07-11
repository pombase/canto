package Canto::Chado::Utils;

=head1 NAME

Canto::Chado::Utils -

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Chado::Utils

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use warnings;
use strict;

sub curation_stats_table
{
  my $chado_schema = shift;
  my $track_schema = shift;

  my %curator_emails = ();

  my $curator_rs =
    $track_schema->resultset('Person')
      ->search({ 'role.name' => 'admin' }, { join => 'role' });

  while (defined (my $curator = $curator_rs->next())) {
    $curator_emails{$curator->email_address()} = 1;
  }

  my %annual_community_annotation_counts = ();
  my %annual_curator_annotation_counts = ();

  my $dbh = $chado_schema->storage()->dbh();
  my $query = <<"EOF";
SELECT fc.feature_cvterm_id, emailprop.value, dateprop.value
  FROM feature_cvterm fc
  JOIN feature_cvtermprop emailprop
    ON fc.feature_cvterm_id = emailprop.feature_cvterm_id
  JOIN feature_cvtermprop dateprop
    ON fc.feature_cvterm_id = dateprop.feature_cvterm_id
 WHERE emailprop.type_id
       IN (SELECT cvterm_id FROM cvterm WHERE name = 'curator_email')
   AND dateprop.type_id
       IN (SELECT cvterm_id FROM cvterm WHERE name = 'date')
EOF

  my $sth = $dbh->prepare($query);
  $sth->execute() or die "Couldn't execute: " . $sth->errstr;

  while (my ($id, $email, $date) = $sth->fetchrow_array()) {
    if ($date =~ /(\d\d\d\d)-?(\d\d)-?(\d\d)/) {
      my $year = $1;
      if ($curator_emails{$email}) {
        $annual_curator_annotation_counts{$year}++;
      } else {
        $annual_community_annotation_counts{$year}++;
      }
    }
  }

  my $first_year = 9999;

  map {
    $first_year = $_ if $_ < $first_year
  } (keys %annual_community_annotation_counts,
     keys %annual_curator_annotation_counts);

  my @rows = ();

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  my $current_year = $year + 1900;

  for (my $year = $first_year; $year <= $current_year; $year++) {
    push @rows, [$year, $annual_curator_annotation_counts{$year} // 0,
                 $annual_community_annotation_counts{$year} // 0];
  }

  return @rows;
}


1;
