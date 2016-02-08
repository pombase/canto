package Canto::ExtensionUtil;

=head1 NAME

Canto::ExtensionUtil - Code for parsing extension strings

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::ExtensionUtil

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use charnames ":full";
use Moose::Role;

my $comma_substitute = "<<:COMMA:>>";

sub _replace_commas
{
  my $string = shift;

  $string =~ s/,/$comma_substitute/g;
  return $string;
}

sub _unreplace_commas
{
  my $string = shift;

  $string =~ s/$comma_substitute/,/g;
  return $string;
}


=head2 parse_extension

 Usage   : $ext_data = $extension_parse->parse_extension($extension_string)
 Function: Parse an extension string like:
           "annotation_extension=has_regulation_target(PomBase:pka1),
            happens_during(GO:0042149) |
            annotation_extension=has_regulation_target(PomBase:pka1),
            happens_during(GO:0071472)","
           and return a nested structure like:
             [ [ { relation => "has_regulation_target",
                   rangeValue => "pka1" },
                 { relation => "happens_during",
                   rangeValue => "GO:0042149" }
               ],
               [ { relation => "has_regulation_target",
                   rangeValue => "pka1" },
                  { relation => "happens_during",
                   rangeValue => "GO:0042149" } ] ]
           other possible contents include "qualifier=NOT" and "residue=..."
 Args    : A string

=cut

sub parse_extension
{
  my $extension_string = shift;

  return () unless defined $extension_string;

  # remove some crud
  $extension_string =~ s/[\s\N{ZERO WIDTH SPACE}]/ /g;
  $extension_string =~ s/
                          (
                            \N{ZERO WIDTH SPACE}
                          |
                            \N{LATIN SMALL LETTER A WITH CIRCUMFLEX}
                          |
                            \N{PADDING CHARACTER}
                            \N{PARTIAL LINE FORWARD}
                          |
                            \x{80}
                            \x{8B}
                          )
                          \s*/ /gx;


  chomp $extension_string;

  $extension_string =~ s/\|\s*$//;

  return () unless length $extension_string > 0;

  my @parts = split /\|/, $extension_string;

  my @extension = ();

  for my $part (@parts) {
    my @rest = ();
    my @conditions = ();

    $part =~ s/(\([^\)]+\))/_replace_commas($1)/eg;

    chomp $part;
    $part =~ s/,\s*$//;

    my @bits = split /,/, $part;

    my @extension_part = ();

    for my $bit (@bits) {
      $bit = _unreplace_commas($bit);

      $bit =~ s/^\s+//;
      $bit =~ s/\s+$//;

      $bit =~ s/annotation_extension=//;

      $bit =~ s/residue=(.*)/residue($1)/;
      $bit =~ s/(?:column_17|col17)=(.*)/column_17($1)/;

      if ($bit =~ /^\s*(\S+)=\s*(.+)\s*$/) {
        if ($1 eq 'allele') {
          die "shouldn't have 'allele=' in extension string\n";
        } else {
          if ($1 eq 'allele_type') {
            die "shouldn't have 'allele_type=' in extension string\n";
          } else {
            if ($1 eq 'condition') {
              die "shouldn't have 'conditions=' in extension string\n";
            } else {
              if ($1 eq "qualifier") {
                if ($2 eq "NOT" ||
                    $2 eq "colocalizes_with" ||
                    $2 eq "contributes_to") {
                  $bit = "has_qualifier($2)";
                } else {
                  die "failed to store qualifier with value '$2' in: $extension_string\n";
                }
              } else {
                die "can't parse '$bit', in: $extension_string\n";
              }
            }
          }
        }
      }

      $bit =~ s/^\s+//;
      $bit =~ s/\s+$//;

      if ($bit) {
        if ($bit =~ /^(\S+)\s*\(\s*([^\)]+?\s*)\)$/) {
          # a "relation(id)" without "extension="
          push @extension_part,
            {
              relation => $1,
              rangeValue => $2,
            };
        } else {
          die "can't parse '$bit', in: $extension_string\n";
        }
      }
    }

    push @extension, \@extension_part;
  }

  return @extension;
}

1;
