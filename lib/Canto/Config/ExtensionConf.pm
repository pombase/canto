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
               subset_rel => 'is_a', allowed_relation => 'has_substrate',
               range => 'GO:0005575' }, ... ]
           The range can be a term ID, or one of the following strings:
             "FeatureID" - the ID of any annotatable feature is allowed
             "TranscriptID" - only transcript IDs are allowed in the range
             "ProteinID" - only protein IDs are allowed
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

      my ($domain, $subset_rel, $allowed_relation, $range, $display_text,
          $cardinality, $role) =
            split (/\t/, $line);

      if ($domain =~ /^\s*domain/i) {
        # header
        next;
      }

      if ($subset_rel !~ /^\w+$/) {
        die qq("$subset_rel" does not look like a relation on line: $line\n");
      }

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

      my @range_bits = split /\|/, $range;

      my @new_range_bits = ();
      my @new_ontology_range_scope = ();

      map {
        if (/:/) {
          push @new_ontology_range_scope, $_;
        } else {
          if (lc $_ eq 'number') {
            if (!grep { $_->{type} eq 'Number'} @new_range_bits) {
              push @new_range_bits, {
                type => 'Number',
              };
            }
          } else {
            if (/^(text|\%)$/i) {
              if (!grep { $_->{type} eq 'Text'} @new_range_bits) {
                push @new_range_bits, {
                  type => 'Text',
                  input_type => lc $_,
                };
              }
            } else {
              if (/^(Gene|FeatureID|GeneID|ProteinID|TranscriptID|tRNAID|SP.*)$/i) {
                # hack: treat everything else as a gene (and normalise the case)
                if (!grep { $_->{type} eq 'Gene'} @new_range_bits) {
                  push @new_range_bits, {
                    type => 'Gene',
                  }
                }
              } else {
                die "unsupported range part: $_\n";
              }
            }
          }
        }
      } @range_bits;

      if (@new_ontology_range_scope) {
        unshift @new_range_bits,
          {
            type => 'Ontology',
            scope => \@new_ontology_range_scope,
          };
      }

      push @res, {
        domain => $domain,
        subset_rel => $subset_rel,
        allowed_relation => $allowed_relation,
        range => \@new_range_bits,
        display_text => $display_text,
        cardinality => \@cardinality,
        role => $role,
      };
    }

    close $conf_fh or die "can't close $extension_conf_file: $!\n";
  }

  return @res;
}

1;
