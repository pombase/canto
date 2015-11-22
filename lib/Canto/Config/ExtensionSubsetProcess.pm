package Canto::Config::ExtensionSubsetProcess;

=head1 NAME

Canto::Config::ExtensionSubsetProcess - Read the domains and ranges from the
  extension configuration and use owltools to find the child terms.  Store
  canto_subset cvtermprops to record this.

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Config::ExtensionSubsetProcess

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;

has config => (is => 'ro', isa => 'Canto::Config',
               required => 1);

use File::Temp qw/ tempfile /;
use List::MoreUtils qw(uniq);

sub get_owltools_results
{
  my $self = shift;
  my @obo_file_names = @_;

  my @results = ();

  my ($temp_fh, $temp_filename) = tempfile();

  for my $filename (@obo_file_names) {
    system ("owltools $filename --save-closure-for-chado $temp_filename") == 0
      or die "can't open pipe from owltools: $?";

    open my $owltools_out, '<', $temp_filename
      or die "can't open owltools output from $temp_filename: $!\n";

    while (defined (my $line = <$owltools_out>)) {
      chomp $line;
      push @results, [split (/\t/, $line)];
    }

    close $owltools_out;
  }

  return @results;
}

=head2 get_subset_data

 Usage   : my %subset_data = $self->get_subset_data(@obo_file_names);
 Function: Read the domain and range ontology terms from extension_configuration
           config, then use owtools to find the child terms.
 Args    : @obo_file_names - the OBO files to process with OWLtools
 Return  : A reference to a map from subject ID to object ID to relation.  eg.:
           {
             "GO:0000010" => {
               "GO:0000005" => "is_a",
               "GO:0000006" => "is_a",
             },
             "GO:0000020" => {
               "GO:0000007" => "is_a",
             },
           }
           Here GO:0000010 and GO:0000020 are subject term IDs, GO:0000005,
           GO:0000006 and GO:0000007 are the objects and is_a is the relation
           that connects them.  All the objects are terms IDs mentioned as
           domain or range constraints in the extension config.

=cut

sub get_subset_data
{
  my $self = shift;
  my @obo_file_names = @_;

  my $config = $self->config();

  my $ext_conf = $config->{extension_configuration};

  if (!$ext_conf) {
    die "no extension configuration file set\n";
  }

  my @conf = @{$ext_conf};

  my %domain_subsets_to_store = ();
  my %range_subsets_to_store = ();

  for my $conf (@conf) {
    $domain_subsets_to_store{$conf->{domain}} = $conf->{subset_rel};
    map {
      my $range = $_;

      if ($range->{type} eq 'Ontology') {
        map {
          $range_subsets_to_store{$_} = 1;
        } @{$range->{scope}};
      }
    } @{$conf->{range}};
  }

  my %subsets = map {
    ($_, { $_ => 1 })
  } (keys %domain_subsets_to_store, keys %range_subsets_to_store);

  my @owltools_results = $self->get_owltools_results(@obo_file_names);

  for my $result (@owltools_results) {
    my ($subject, $rel_type, $depth, $object) = @$result;

    $rel_type =~ s/^OBO_REL://;

    if ($domain_subsets_to_store{$object} &&
        $domain_subsets_to_store{$object} eq $rel_type) {
      $subsets{$subject}{$object} = 1;
    }

    if ($range_subsets_to_store{$object}) {
      $subsets{$subject}{$object} = 1;
    }
  }

  return \%subsets;
}

=head2 process_subset_data

 Usage   : my $subset_data = $extension_subset_process->get_subset_data();
           $extension_subset_process->process_subset_data($track_schema, $subset_data);
 Function: Use the results of get_subset_data() to add a canto_subset
           cvtermprop for each config file term it's a child of.  For
           more details see:
           https://github.com/pombase/canto/wiki/AnnotationExtensionConfig
 Args    : $track_schema - the database to load
           $subset_data - A map returned by subset_data()
 Return  : None - dies on failure

=cut

sub process_subset_data
{
  my $self = shift;
  my $schema = shift;
  my $subset_data = shift;

  my %db_names = ();

  map {
    if (/(\w+):/) {
      $db_names{$1} = 1;
    }
  } keys %$subset_data;

  my @db_names = keys %db_names;

  my $cvterm_rs =
    $schema->resultset('Cvterm')->search({
      'db.name' => { -in => \@db_names },
    }, {
      join => { dbxref => 'db' },
      prefetch => { dbxref => 'db' }
    });

  my $canto_subset_term =
    $schema->resultset('Cvterm')->find({ name => 'canto_subset',
                                         'cv.name' => 'cvterm_property_type' },
                                       {
                                         join => 'cv' });

  while (defined (my $cvterm = $cvterm_rs->next())) {
    my $db_accession = $cvterm->db_accession();

    my $prop_rs =
      $cvterm->cvtermprop_cvterms()
      ->search({
        type_id => $canto_subset_term->cvterm_id(),
      });

    $prop_rs->delete();

    my $subset_ids = $subset_data->{$db_accession};

    if ($subset_ids) {
      my @subset_ids = keys %{$subset_ids};

      for (my $rank = 0; $rank < @subset_ids; $rank++) {
        my $subset_id = $subset_ids[$rank];
        $schema->resultset('Cvtermprop')->create({
          cvterm_id => $cvterm->cvterm_id(),
          type_id => $canto_subset_term->cvterm_id(),
          value => $subset_id,
          rank => $rank,
        });
      }
    }
  }
}

1;
