package Canto::Curs::ExtensionData;

=head1 NAME

Canto::Curs::ExtensionData - Objects representing GO style annotation extensions

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::ExtensionData

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;
use feature "state";


=head2 as_strings

 Usage   : ($extension_string, $qualifier_list) =
              $extension_data->as_strings($ontology_lookup, $extension_obj);
 Function: Return a string representation of the qualifiers from an annotation
           for exporting to a GAF file.  Also returns any has_qualifier()
           extensions as text in the $qualifier_list.  eg. has_qualifier(PBHQ:002)
           is returned as "NOT" and is removed from the extension string.
 Args    : None

=cut

sub as_strings
{
  my $ontology_lookup = shift;
  my $extension_obj = shift;

  state $term_cache = {};

  my $lookup = sub {
    my $termid = shift;

    if (defined $term_cache->{$termid}) {
      return $term_cache->{$termid}
    }

    my $res = $ontology_lookup->lookup_by_id(id => $termid);

    if (!defined $res) {
      die "failed to find term details for id: $termid\n";
    }

    $term_cache->{$termid} = $res->{name};

    return $term_cache->{$termid};
  };

  my @quals = ();

  my $ext_string = join '|', map {
    my @part = @$_;

    my @filtered_part = grep {
      if ($_->{relation} eq 'has_qualifier') {
        my $termid = $_->{rangeValue};

        my $qual_string;

        if ($termid =~ /:/) {
          # eg. PBHQ:002
          $qual_string = $lookup->($termid);
        } else {
          # eg. "contributes_to"
          $qual_string = $termid;
        }

        if (!grep {
          $_ eq $qual_string;
        } @quals) {
          push @quals, $qual_string;
        }
        0;
      } else {
        1;
      }
    } @part;

    join ',', map {
      $_->{relation} . '(' . $_->{rangeValue} . ')';
    } @filtered_part;
  } @{$extension_obj};

  return ($ext_string, \@quals);
}

1;
