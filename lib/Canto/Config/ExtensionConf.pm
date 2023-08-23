package Canto::Config::ExtensionConf;

=head1 NAME

Canto::Config::ExtensionConf - Code for parsing the extension
                                    configuration table

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Config::ExtensionConf

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;

=head2

 Usage   : my $conf = Canto::Config::ExtensionConf::parse($file_name);
 Function: Read the extension configuration table
 Args    : @conf_file_names
 Return  : Returns a list of hashes like:
           [ { domain => 'GO:0004672',
               subset_rel => ['is_a'], allowed_relation => 'has_substrate',
               range => 'GO:0005575' }, ... ]
           The range can be a term ID, or one of the following strings:
             "FeatureID" - the ID of any annotatable feature is allowed
             "TranscriptID" - only transcript IDs are allowed in the range
             "ProteinID" - only protein IDs are allowed
             "MetagenotypeID" - only metagenotypes are allowed
=cut

sub parse {
  my @extension_conf_files = @_;

  my @res = ();

  for my $extension_conf_file (@extension_conf_files) {
    open my $conf_fh, '<', $extension_conf_file
      or die "can't open $extension_conf_file: $!\n";

    while (defined (my $line = <$conf_fh>)) {
      chomp $line;

      next if $line =~ /^#/;

      my ($domain, $subset_rel, $allowed_relation, $range, $display_text, $help_text,
          $cardinality, $role, $annotation_type_name, $feature_type) =
            split (/\t/, $line);

      if ($domain =~ /^\s*domain/i) {
        # header
        next;
      }

      my @subset_rel_split =
        grep { length $_ > 0 }
        map { s/^\s+//; s/\s+$//; $_; }
        split /\|/, $subset_rel;

      if (!defined $display_text) {
        die "config line $. in $extension_conf_file has too few fields: $line\n";
      }

      my @cardinality = ('*');

      if (defined $cardinality) {
        @cardinality = grep {
          length $_ > 0;
        } map {
          s/^\s+//; s/\s+$//; $_;
        } split /,/, $cardinality;
      }

      map {
        if ($_ ne '*' && !/^\d+$/) {
          die qq|cardinality must be "*" or comma separated integers not "$_" \n| .
            "at config line $. in $extension_conf_file has : $line\n";
        }
      } @cardinality;

      my @range_bits = split /\|/, $range;

      my @new_range_bits = ();
      my @new_ontology_range_scope = ();

      my $range_check = undef;

      map {
        if (m|^/allele_qc/.*|) {
          # nasty special case for now
          $range_check = {
            checker => 'allele_qc',
            url => $_,
          };
          $_ = 'Text';
        }

        if (/:/) {
          push @new_ontology_range_scope, $_;
        } elsif (/^Number$/i) {
          if (!grep { $_->{type} eq 'Number'} @new_range_bits) {
            push @new_range_bits, {
              type => 'Number',
            };
          }
        } elsif (/^text$/i) {
          if (!grep { $_->{type} eq 'Text'} @new_range_bits) {
            push @new_range_bits, {
              type => 'Text',
              input_type => lc $_,
            };
          }
        } elsif (/^(Gene|FeatureID|GeneID|ProteinID|TranscriptID|tRNAID|SP.*)$/i) {
          # hack: treat everything else as a gene (and normalise the case)
          if (!grep { $_->{type} eq 'Gene'} @new_range_bits) {
            push @new_range_bits, {
              type => 'Gene',
            }
          }
        } elsif ($_ eq '%') {
          if (!grep { $_->{type} eq '%'} @new_range_bits) {
            push @new_range_bits, {
              type => '%',
            };
          }
        } elsif (/^metagenotype/i) {
          push @new_range_bits, {
            type => 'Metagenotype',
          }
        } elsif (/^TaxonID$/i) {
          push @new_range_bits, {
            type => 'TaxonID',
          }
        } elsif (/^PathogenTaxonID$/i) {
          push @new_range_bits, {
            type => 'PathogenTaxonID',
          }
        } elsif (/^HostTaxonID$/i) {
          push @new_range_bits, {
            type => 'HostTaxonID',
          }
        } else {
          die "unsupported range part: $_\n";
        }
      } @range_bits;

      if (@new_ontology_range_scope) {
        # put term completion last, see: https://github.com/pombase/canto/issues/2569
        push @new_range_bits,
          {
            type => 'Ontology',
            scope => \@new_ontology_range_scope,
          };
      }

      my %conf = (
        subset_rel => \@subset_rel_split,
        allowed_relation => $allowed_relation,
        range => \@new_range_bits,
        display_text => $display_text,
        help_text => $help_text,
        cardinality => \@cardinality,
        role => $role,
        annotation_type_name => $annotation_type_name,
        feature_type => $feature_type,
        range_check => $range_check,
      );

      if ($domain =~ /(\S+)-(\S+)/) {
        $conf{domain} = $1;
        my $exclude_id_str = $2;
        $conf{exclude_subset_ids} = [split /&/, $exclude_id_str];
      } else {
        $conf{domain} = $domain;
      }

      push @res, \%conf;
    }

    close $conf_fh or die "can't close $extension_conf_file: $!\n";
  }

  return @res;
}

1;
