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

sub stats_init
{
  my $chado_schema = shift;
  my $track_schema = shift;

  my $track_dbh = $track_schema->storage()->dbh();
  my $pub_date_query = 'SELECT uniquename, publication_date FROM pub;';

  my $chado_dbh = $chado_schema->storage()->dbh();
  $chado_dbh->prepare('CREATE TEMP TABLE pub_dates(uniquename TEXT, pub_date TEXT)')->execute();

  my $track_sth = $track_dbh->prepare($pub_date_query);
  $track_sth->execute() or die "Couldn't execute: " . $track_sth->errstr;

  my $chado_sth =
    $chado_dbh->prepare('insert into pub_dates(uniquename, pub_date) values (?, ?)');

  while (my ($pub_uniquename, $publication_date) = $track_sth->fetchrow_array()) {
    if ($publication_date =~ /((19|20)\d\d)$/) {
      my $publication_year = $1;

      $chado_sth->execute($pub_uniquename, $publication_year)
        or die "Couldn't execute: " . $chado_sth->errstr;
    }
  }

  $chado_dbh->prepare(<<'EOF')->execute();
CREATE TEMP TABLE pub_canto_curator_roles AS
  SELECT pub.uniquename, pp.value AS status
    FROM pub
    LEFT OUTER JOIN pubprop pp
                 ON pp.pub_id = pub.pub_id AND pp.type_id IN
                   (SELECT cvterm_id FROM cvterm WHERE name = 'canto_curator_role')
WHERE pub.pub_id IN
    (SELECT pub_id FROM pubprop pp
       JOIN cvterm pt ON pt.cvterm_id = pp.type_id
        AND pt.name = 'canto_triage_status'
        AND (pp.value LIKE 'Curatable%' OR pp.value LIKE 'curatable%'));
EOF
}

=head2 curated_stats

 Function: Return a table of counts of uncurated (but curatable), admin curated
           and community curated publications per year

=cut

sub curated_stats
{
  my $chado_schema = shift;

  my $chado_dbh = $chado_schema->storage()->dbh();

  my %stats = ();

  for my $curation_status ('uncurated', 'community', 'admin') {
    my $where;

    if ($curation_status eq 'uncurated') {
      $where = 'status is null';
    } else {
      if ($curation_status eq 'community') {
        $where = q|status = 'community'|;
      } else {
        $where = q|status IS NOT NULL and status <> 'community'|;
      }
    }

    my $query = <<"EOF";
SELECT substring(pub_date FROM '^(\\d\\d\\d\\d)') AS year, count(roles.uniquename)
   FROM pub_canto_curator_roles roles
   JOIN pub_dates ON pub_dates.uniquename = roles.uniquename
  WHERE $where
   GROUP BY year
EOF

    my $sth = $chado_dbh->prepare($query);
    $sth->execute() or die "Couldn't execute: " . $sth->errstr;

    while (my ($year, $count) = $sth->fetchrow_array()) {
      $stats{$year}->{$curation_status} = $count;
    }
  }

  my @rows = ();

  my $first_year = 9999;

  map {
    $first_year = $_ if $_ < $first_year
  } keys %stats;

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  my $current_year = $year + 1900;

  for (my $year = $first_year; $year <= $current_year; $year++) {
    my $year_stats = $stats{$year};
    if (defined $year_stats) {
      push @rows, [$year, $year_stats->{uncurated} // 0,
                   $year_stats->{admin} // 0, $year_stats->{community} //0];
    } else {
      push @rows, [$year, 0, 0, 0];
    }
  }

  return @rows;
}

sub per_publication_stats
{
  my $chado_schema = shift;
  my $track_schema = shift;
  my $use_5_year_bins = shift // 0;

  my $chado_dbh = $chado_schema->storage()->dbh();

  my $select_sql;

if ($use_5_year_bins) {
  $select_sql = <<'EOF';
SELECT floor((year::float - 1)/5)::int * 5 + 1, round(avg(COUNT),2)
FROM counts
GROUP BY floor((year::float - 1)/5)::int * 5 + 1
ORDER BY floor((year::float - 1)/5)::int * 5 + 1;
EOF
  } else {
  $select_sql = <<'EOF';
 SELECT year, round(avg(COUNT),2)
 FROM counts
 GROUP BY year
 ORDER BY year
EOF
  }

  my $annotation_query = <<"EOF";
 WITH counts AS
  (SELECT substring(pub_date FROM '^(\\d\\d\\d\\d)') AS year, pmid, count(id)
   FROM pombase_genes_annotations_dates
   JOIN pub_dates ON uniquename = pmid
  WHERE session IS NOT NULL
   GROUP BY year, pmid
   ORDER BY year)
$select_sql;
EOF

  my $annotation_sth = $chado_dbh->prepare($annotation_query);
  $annotation_sth->execute() or die "Couldn't execute: " . $annotation_sth->errstr;

  my %publication_stats = ();

  while (my ($pub_date, $avg_count) = $annotation_sth->fetchrow_array()) {
    $publication_stats{$pub_date}->{annotation} = $avg_count;
  }

  my $gene_query = <<"EOF";
 WITH counts AS
  (SELECT substring(pub_date FROM '^(\\d\\d\\d\\d)') AS year, pmid, count(gene_uniquename)
   FROM pombase_annotated_gene_features_per_publication
   JOIN pub_dates ON uniquename = pmid
  WHERE session IS NOT NULL
   GROUP BY year, pmid
   ORDER BY year)
$select_sql;
EOF

  my $gene_sth = $chado_dbh->prepare($gene_query);
  $gene_sth->execute() or die "Couldn't execute: " . $gene_sth->errstr;

  while (my ($pub_date, $avg_count) = $gene_sth->fetchrow_array()) {
    $publication_stats{$pub_date}->{gene} = $avg_count;
  }

  my @rows = ();

  if ($use_5_year_bins) {
    my @bins = sort {
      $a <=> $b;
    } keys %publication_stats;

    for my $bin (@bins) {
      my $bin_stats = $publication_stats{$bin};

      push @rows, [$bin, $bin_stats->{gene} // 0, $bin_stats->{annotation} // 0];
    }
  } else {
    my $first_year = 9999;

    map {
      $first_year = $_ if $_ < $first_year
    } keys %publication_stats;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    my $current_year = $year + 1900;

    for (my $year = $first_year; $year <= $current_year; $year++) {
      my $year_stats = $publication_stats{$year};
      if (defined $year_stats) {
        push @rows, [$year, $year_stats->{gene} // 0, $year_stats->{annotation} // 0];
      } else {
        push @rows, [$year, 0, 0];
      }
    }
  }

  return @rows;
}

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

sub stats_finish
{
  my $chado_schema = shift;
  my $track_schema = shift;

  my $chado_dbh = $chado_schema->storage()->dbh();

  $chado_dbh->prepare('drop table pub_dates')->execute();
  $chado_dbh->prepare('drop table pub_canto_curator_roles')->execute();
}

1;
