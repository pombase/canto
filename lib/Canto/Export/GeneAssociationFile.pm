package Canto::Export::GeneAssociationFile;

=head1 NAME

Canto::Export::GeneAssociationFile - Export annotations in GAF format

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Export::GeneAssociationFile

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;
use Carp;

use Canto::Track::Serialise;

with 'Canto::Role::Configurable';
with 'Canto::Role::Exporter';
with 'Canto::Role::GAFFormatter';

sub _get_cursprops
{
  my $curs = shift;

  my $rs = $curs->cursprops();
  my @ret = ();

  while (defined (my $prop = $rs->next())) {
    push @ret, {
      type => $prop->type()->name(),
      value => $prop->value(),
    };
  }

  return \@ret;
}

sub _get_cursprop
{
  my $curs = shift;
  my $prop_name = shift;

  my $props = _get_cursprops($curs);

  for my $prop (@$props) {
    if ($prop->{type} eq $prop_name) {
      return $prop->{value};
    }
  }

  return undef;
}

=head2 export

 Usage   : my ($count, $gaf) = $exporter->export($config);
 Function: Export annotation in GAF format
 Args    : $config - a Canto::Config object
 Return  : (count of sessions exported, GAF format data)

 The options passed to Canto::Track::Serialise::json() come from the
 parsed_options attribute of Role::Exporter

=cut

sub export
{
  my $self = shift;

  my $config = $self->config();

  my $track_schema = $self->track_schema();

  my $annotation_type = $self->parsed_options()->{annotation_type};
  my $dump_approved = $self->parsed_options()->{dump_approved};

  if (!defined $annotation_type) {
    die "needs --annotation-type=... option\n";
  }

  my $exported_count = 0;
  my $result = '';

  my $proc = sub {
    my $curs = shift;
    my $curs_schema = shift;

    if ($dump_approved) {
      my $curs_status = _get_cursprop($curs, 'annotation_status');

      return unless defined $curs_status && $curs_status eq 'APPROVED';
    }

    $exported_count++;

    my $gaf = $self->get_annotation_table_tsv($config, $curs_schema, $annotation_type);

    $result .= $gaf if length $gaf > 0;
  };

  Canto::Track::curs_map($config, $track_schema, $proc);

  return ($exported_count, $result);
}
1;
