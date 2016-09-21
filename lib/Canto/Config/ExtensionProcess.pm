package Canto::Config::ExtensionProcess;

=head1 NAME

Canto::Config::ExtensionProcess - Read the domains and ranges from the
  extension configuration and use owltools to find the child terms.

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Config::ExtensionProcess

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
      or die "can't open pipe from owltools: $!";

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
           my $subset_process = Canto::Chado::SubsetProcess->new();
           $subset_process->process_subset_data($track_schema, $subset_data);
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
  my %exclude_subsets_to_store = ();

  for my $conf (@conf) {
    $domain_subsets_to_store{$conf->{domain}} = $conf->{subset_rel};

    if ($conf->{exclude_subset_ids}) {
      map {
        $exclude_subsets_to_store{$_} = 1;
      } @{$conf->{exclude_subset_ids}};
    }

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
    ($_, { $_ => { is_a => 1 } })
  } (keys %domain_subsets_to_store, keys %range_subsets_to_store,
     keys %exclude_subsets_to_store);

  my @owltools_results = $self->get_owltools_results(@obo_file_names);

  for my $result (@owltools_results) {
    my ($subject, $rel_type, $depth, $object) = @$result;

    $rel_type =~ s/^OBO_REL://;

    if ($domain_subsets_to_store{$object} &&
        grep { $_ eq $rel_type } @{$domain_subsets_to_store{$object}}) {
      $subsets{$subject}{$object}{$rel_type} = 1;
    }

    if ($range_subsets_to_store{$object}) {
      $subsets{$subject}{$object}{$rel_type} = 1;
    }

    if ($exclude_subsets_to_store{$object}) {
      $subsets{$subject}{$object}{$rel_type} = 1;
    }
  }

  return \%subsets;
}


1;
