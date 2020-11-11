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
              $extension_data->as_strings($ontology_lookup, $curs_schema, $database_prefix,
                                          $extension_obj);
 Function: Return a string representation of the qualifiers from an annotation
           for exporting to a GAF file.  Also returns any has_qualifier()
           extensions as text in the $qualifier_list.  eg. has_qualifier(PBHQ:002)
           is returned as "NOT" and is removed from the extension string.
 Args    : $ontology_lookup - An OntologyLookup object
           $curs_schema     - the schema of the session containing this extension
           $database_prefix - the prefix to add to gene IDs
           $extension_obj   - the extension in the form stored in the database

=cut

sub as_strings
{
  my $ontology_lookup = shift;
  my $curs_schema = shift;
  my $db_prefix = shift;
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

  my $ext_string = join '|',
    grep {
      length s/^\s+$//r > 0;
    }
    map {
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

    my $_process_value = sub {
      my $val = shift;

      if ($val !~ /:/) {
        my $gene = $curs_schema->resultset('Gene')->find({ primary_identifier => $val });

        if (defined $gene) {
          return "$db_prefix:$val";
        }
      }

      return $val;
    };

    join ',', map {
      $_->{relation} . '(' . $_process_value->($_->{rangeValue}) . ')';
    } @filtered_part;
  } @{$extension_obj};

  return ($ext_string, \@quals);
}

1;
