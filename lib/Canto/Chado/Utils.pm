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

  my $chado_dbh = $chado_schema->storage()->dbh();
  $chado_dbh->prepare(<<'EOF')->execute();
CREATE TEMP TABLE pub_dates AS
SELECT uniquename,
       regexp_replace(value, '(?:^|.*\s)(\d\d\d\d)', '\1') AS pub_date
FROM pubprop pp
JOIN pub ON pub.pub_id = pp.pub_id
WHERE pp.type_id IN
    (SELECT cvterm_id
     FROM cvterm
     WHERE name = 'pubmed_publication_date')
EOF
}

# returns the number of completed (but not necessarily approved) sessions and the number of
# sessions with a community curator
sub curation_response_rate
{
  my $track_schema = shift;

  my $dbh = $track_schema->storage()->dbh();
  my $query = <<"EOF";

  SELECT count(distinct(outer_curs.curs_id))
FROM curs outer_curs
JOIN curs_curator cc ON cc.curs = curs_id
JOIN person p ON p.person_id = cc.curator
JOIN cvterm ROLE ON p.ROLE = ROLE.cvterm_id
WHERE ROLE.name = 'user'
  AND (curs_curator_id =
         (SELECT max(curs_curator_id)
          FROM curs_curator
          WHERE curs = outer_curs.curs_id))
  AND curs_id IN
    (SELECT curs
     FROM cursprop p, cvterm t
     WHERE t.cvterm_id = p.type
       AND t.name = 'annotation_status'
       AND (p.value = 'NEEDS_APPROVAL' OR p.value = 'APPROVAL_IN_PROGRESS' OR p.value = 'APPROVED'));
EOF

  my $sth = $dbh->prepare($query);
  $sth->execute() or die "Couldn't execute: " . $sth->errstr;

  my ($completed_community_session_count) = $sth->fetchrow_array();

  $query = <<"EOF";
SELECT count(distinct(outer_curs.curs_id))
FROM cursprop cp
JOIN curs outer_curs ON outer_curs.curs_id = cp.curs
JOIN curs_curator cc ON cc.curs = cp.curs
JOIN person p ON p.person_id = cc.curator
JOIN cvterm ROLE ON p.ROLE = ROLE.cvterm_id
WHERE ROLE.name = 'user'
  AND (curs_curator_id =
         (SELECT max(curs_curator_id)
          FROM curs_curator
          WHERE curs = outer_curs.curs_id));
EOF

  $sth = $dbh->prepare($query);
  $sth->execute() or die "Couldn't execute: " . $sth->errstr;

  my ($total_community_session_count) = $sth->fetchrow_array();

  return ($completed_community_session_count, $total_community_session_count);
}

sub new_curators_per_year
{
  my $chado_schema = shift;

  my $chado_dbh = $chado_schema->storage()->dbh();

  my %stats = ();

  my $query = <<'EOF';
WITH pub_curator_roles AS
  (SELECT uniquename,
     (SELECT value
      FROM pubprop
      JOIN cvterm ppt ON ppt.cvterm_id = pubprop.type_id
      WHERE pubprop.pub_id = pub.pub_id
        AND ppt.name = 'canto_curator_role' LIMIT 1) AS ROLE,

     (SELECT value
      FROM pubprop
      JOIN cvterm ppt ON ppt.cvterm_id = pubprop.type_id
      WHERE pubprop.pub_id = pub.pub_id
        AND ppt.name = 'canto_curator_name' LIMIT 1) AS curator,
     extract(YEAR
             FROM
               (SELECT value
                  FROM pubprop
                  JOIN cvterm ppt ON ppt.cvterm_id = pubprop.type_id
                 WHERE pubprop.pub_id = pub.pub_id
                       AND ppt.name = 'canto_session_submitted_date' LIMIT 1)::TIMESTAMP)
     AS approved_year
   FROM pub),
   curator_first_year AS
  (SELECT DISTINCT curator, min(approved_year) AS first_year
   FROM pub_curator_roles
   WHERE ROLE = 'community' AND approved_year IS NOT NULL
   GROUP BY curator)
SELECT count(curator), first_year
FROM curator_first_year
GROUP BY first_year
ORDER BY first_year;
EOF
  my $sth = $chado_dbh->prepare($query);
  $sth->execute() or die "Couldn't execute: " . $sth->errstr;

  my @rows = ();

  while (my ($year, $count) = $sth->fetchrow_array()) {
    push @rows, [$year, $count];
  }

  return @rows;
}

sub annotation_types_by_year
{
  my $chado_schema = shift;

  my $chado_dbh = $chado_schema->storage()->dbh();

  my %stats = ();

  my $query = <<"EOF";
SELECT annotation_year, annotation_type, count(distinct id)
FROM pombase_genes_annotations_dates
WHERE (evidence_code IS NULL OR evidence_code <> 'Inferred from Electronic Annotation')
  AND (annotation_type NOT IN ('cat_act', 'subunit_composition', 'external_link', 'pathway'))
  AND (annotation_source IS NULL OR annotation_source <> 'BIOGRID')
GROUP BY annotation_type, annotation_year;
EOF

  my $sth = $chado_dbh->prepare($query);
  $sth->execute() or die "Couldn't execute: " . $sth->errstr;

  my $first_year = 2004;

  while (my ($year, $type, $count) = $sth->fetchrow_array()) {
    if (!$year || $year < $first_year) {
      $year = "<$first_year";
    }

    if (!$stats{$year}) {
      $stats{$year} = {};
    }

    if (defined $stats{$year}->{$type} && $year eq "<$first_year") {
      $stats{$year}->{$type} += $count;
    } else {
      $stats{$year}->{$type} = $count;
    }
  }

  my @rows = ();

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  my $current_year = $year + 1900;

  push @rows, ["<$first_year", $stats{"<$first_year"}];

  for (my $year = $first_year; $year <= $current_year; $year++) {
    my $year_stats = $stats{$year};
    push @rows, [$year, $year_stats];
  }

  return @rows;
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

  my $first_year = 1980;

  for my $curation_status ('admin', 'community', 'uncurated-admin',
                           'uncurated-community', 'uncurated-unassigned',) {
    my $where;

    if ($curation_status =~ /^uncurated/) {
      $where = q|canto_approved_year IS NULL AND canto_triage_status = 'Curatable' |;

      if ($curation_status =~ /unassigned/) {
        $where .= q|AND canto_curator_role IS NULL|;
      } else {
        if ($curation_status =~ /admin/) {
          $where .= q|AND canto_curator_role IS NOT NULL AND canto_curator_role <> 'community'|;
        } else {
          $where .= q|AND canto_curator_role = 'community'|;
        }
      }
    } else {
      if ($curation_status eq 'community') {
        $where = q|canto_curator_role = 'community' AND canto_approved_year IS NOT NULL|;
      } else {
        $where = q|canto_curator_role IS NOT NULL AND canto_curator_role <> 'community' AND canto_approved_year IS NOT NULL|;
      }
    }

    my $query = <<"EOF";
SELECT pubmed_publication_year AS year, count(pmid)
  FROM pombase_publication_curation_summary
 WHERE ($where) AND pubmed_publication_year IS NOT NULL
 GROUP BY pubmed_publication_year;
EOF

    my $sth = $chado_dbh->prepare($query);
    $sth->execute() or die "Couldn't execute: " . $sth->errstr;

    while (my ($year, $count) = $sth->fetchrow_array()) {
      $year = $first_year - 1 unless $year >= $first_year;
      $stats{$year}->{$curation_status} //= 0;
      $stats{$year}->{$curation_status} += $count;
    }
  }

  my @rows = ();

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  my $current_year = $year + 1900;

  for (my $year = $first_year - 1; $year <= $current_year; $year++) {
    my $year_stats = $stats{$year};
    my $fixed_year;
    if ($year >= $first_year) {
      $fixed_year = $year;
    } else {
      $fixed_year = "<$first_year";
    }
    if (defined $year_stats) {
      push @rows, [$fixed_year, $year_stats->{admin} // 0, $year_stats->{community} //0,
                   $year_stats->{'uncurated-admin'} // 0,
                   $year_stats->{'uncurated-community'} // 0,
                   $year_stats->{'uncurated-unassigned'} // 0];
    } else {
      push @rows, [$fixed_year, 0, 0, 0, 0, 0];
    }
  }

  return @rows;
}

sub per_publication_stats
{
  my $chado_schema = shift;
  my $use_5_year_bins = shift // 0;
  my $throughput = shift;

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

  my $throughput_constraint = "annotation_throughput_type = '$throughput throughput'";

  my $annotation_query = <<"EOF";
 WITH counts AS
  (SELECT pubmed_publication_year AS year, pub_summ.pmid, count(distinct id)
    FROM pombase_annotation_summary ann_summ
    JOIN pombase_publication_curation_summary pub_summ on ann_summ.pmid = pub_summ.pmid
   WHERE pubmed_publication_year IS NOT NULL
     AND $throughput_constraint
   GROUP BY year, pub_summ.pmid ORDER BY year)
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
  my $curator_names = shift;

  my %annual_community_pub_counts = ();
  my %annual_curator_pub_counts = ();

  my $dbh = $track_schema->storage()->dbh();
  my $query = <<"EOF";
SELECT curator.name, p.value
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
  AND pt.name = 'needs_approval_timestamp'
  AND curs.curs_id IN
    (SELECT curs
     FROM cursprop p2
     JOIN cvterm pt2 ON p2.type = pt2.cvterm_id
     WHERE pt2.name = 'annotation_status'
       AND p2.value = 'APPROVED')
EOF

  my $sth = $dbh->prepare($query);
  $sth->execute() or die "Couldn't execute: " . $sth->errstr;

  while (my ($curator_name, $approval_date) = $sth->fetchrow_array()) {
    if ($approval_date =~ /^(\d\d\d\d)-\d\d-\d\d/) {
      my $year = $1;
      if ($curator_names->{$curator_name}) {
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
  my $curator_names = shift;

  my %annual_community_annotation_counts = ();
  my %annual_curator_annotation_counts = ();

  my $dbh = $chado_schema->storage()->dbh();
  my $query = <<"EOF";
CREATE TEMP TABLE session_submitted_dates AS
SELECT pub.pub_id, pp.value AS submitted_date
FROM pub
JOIN pubprop pp ON pub.pub_id = pp.pub_id
JOIN cvterm ppt ON ppt.cvterm_id = pp.type_id
JOIN cv ON ppt.cv_id = cv.cv_id
WHERE ppt.name = 'canto_session_submitted_date'
  AND cv.name = 'pubprop_type';
EOF
  my $sth = $dbh->prepare($query);
  $sth->execute() or die "Couldn't execute: " . $sth->errstr;

  $query = <<"EOF";
CREATE INDEX session_submitted_dates_idx ON session_submitted_dates (pub_id);
EOF
  $sth = $dbh->prepare($query);
  $sth->execute() or die "Couldn't execute: " . $sth->errstr;

  $query = <<"EOF";
SELECT nameprop.value,
       ssd.submitted_date
FROM feature_cvterm fc
JOIN feature_cvtermprop nameprop ON fc.feature_cvterm_id = nameprop.feature_cvterm_id
JOIN session_submitted_dates ssd ON ssd.pub_id = fc.pub_id
WHERE nameprop.type_id IN
    (SELECT cvterm_id
     FROM cvterm
     WHERE name = 'curator_name')
UNION ALL
SELECT nameprop.value,
       ssd.submitted_date
FROM feature_relationship fr
JOIN feature_relationship_pub frpub ON frpub.feature_relationship_id = fr.feature_relationship_id
JOIN feature_relationshipprop nameprop ON nameprop.feature_relationship_id = fr.feature_relationship_id
JOIN session_submitted_dates ssd ON ssd.pub_id = frpub.pub_id
WHERE fr.type_id IN
    (SELECT cvterm_id
     FROM cvterm
     WHERE name = 'interacts_genetically'
       OR name = 'interacts_physically')
  AND nameprop.type_id IN
    (SELECT cvterm_id
     FROM cvterm
     WHERE name = 'curator_name')
  AND fr.feature_relationship_id IN
    (SELECT inferredprop.feature_relationship_id
     FROM feature_relationshipprop inferredprop
     WHERE inferredprop.type_id IN
         (SELECT cvterm_id
          FROM cvterm
          WHERE name = 'is_inferred')
       AND value = 'no');
EOF

  $sth = $dbh->prepare($query);
  $sth->execute() or die "Couldn't execute: " . $sth->errstr;

  while (my ($name, $date) = $sth->fetchrow_array()) {
    if ($date =~ /(\d\d\d\d)-?(\d\d)-?(\d\d)/) {
      my $year = $1;
      if ($curator_names->{$name}) {
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

  my %curator_names = ();

  my $curator_rs =
    $track_schema->resultset('Person')
      ->search({ 'role.name' => 'admin' }, { join => 'role' });

  while (defined (my $curator = $curator_rs->next())) {
    $curator_names{$curator->name()} = 1;
  }

  my ($annual_community_pub_counts, $annual_curator_pub_counts) =
    _annotator_pub_counts($track_schema, \%curator_names);

  my ($annual_community_annotation_counts,
      $annual_curator_annotation_counts) =
    _annotator_annotation_counts($chado_schema, \%curator_names);

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

  my $chado_dbh = $chado_schema->storage()->dbh();

  $chado_dbh->prepare('drop table pub_dates')->execute();
}

1;
