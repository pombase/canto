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

sub _annotator_pub_counts
{
  my $track_schema = shift;
  my $curator_emails = shift;

  my %annual_community_pub_counts = ();
  my %annual_curator_pub_counts = ();

  my $dbh = $track_schema->storage()->dbh();
  my $query = <<"EOF";
SELECT curator.email_address, p.value
FROM curs_curator me
JOIN curs curs ON curs.curs_id = me.curs
JOIN pub pub ON pub.pub_id = curs.pub
JOIN person curator ON curator.person_id = me.curator
JOIN cursprop p ON p.curs = curs.curs_id
JOIN cvterm pt ON p.type = pt.cvterm_id
WHERE (curs_curator_id =
         (SELECT max(curs_curator_id)
          FROM curs_curator
          WHERE curs = me.curs))
  AND pt.name = 'annotation_status_datestamp'
  AND curs.curs_id IN
    (SELECT curs
     FROM cursprop p2
     JOIN cvterm pt2 ON p2.type = pt2.cvterm_id
     WHERE pt2.name = 'annotation_status'
       AND p2.value = 'APPROVED')
EOF

  my $sth = $dbh->prepare($query);
  $sth->execute() or die "Couldn't execute: " . $sth->errstr;

  while (my ($email_address, $approval_date) = $sth->fetchrow_array()) {
    if ($approval_date =~ /^(\d\d\d\d)-\d\d-\d\d/) {
      my $year = $1;
      if ($curator_emails->{$email_address}) {
        $annual_curator_pub_counts{$year}++;
      } else {
        $annual_community_pub_counts{$year}++;
      }
    }
  }

  return (\%annual_community_pub_counts, \%annual_curator_pub_counts);
}

sub _annotator_annotation_counts
{
  my $chado_schema = shift;
  my $curator_emails = shift;

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
      if ($curator_emails->{$email}) {
        $annual_curator_annotation_counts{$year}++;
      } else {
        $annual_community_annotation_counts{$year}++;
      }
    }
  }

  return (\%annual_community_annotation_counts,
          \%annual_curator_annotation_counts);
}

sub annotation_stats_table
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

  my ($annual_community_pub_counts, $annual_curator_pub_counts) =
    _annotator_pub_counts($track_schema, \%curator_emails);

  my ($annual_community_annotation_counts,
      $annual_curator_annotation_counts) =
    _annotator_annotation_counts($chado_schema, \%curator_emails);

  my $first_year = 9999;

  map {
    $first_year = $_ if $_ < $first_year
  } (keys %$annual_community_pub_counts,
     keys %$annual_curator_pub_counts,
     keys %$annual_community_annotation_counts,
     keys %$annual_curator_annotation_counts);

  my @rows = ();

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  my $current_year = $year + 1900;

  for (my $year = $first_year; $year <= $current_year; $year++) {
    push @rows, [$year, $annual_curator_pub_counts->{$year} // 0,
                 $annual_community_pub_counts->{$year} // 0,
                 $annual_curator_annotation_counts->{$year} // 0,
                 $annual_community_annotation_counts->{$year} // 0];
  }

  return @rows;
}


1;
