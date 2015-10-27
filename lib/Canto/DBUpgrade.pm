package Canto::DBUpgrade;

=head1 NAME

Canto::DBUpgrade - Code for upgrading Track and Curs databases

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::DBUpgrade

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;
use Try::Tiny;

use Canto::Track;
use Canto::ExtensionUtil;

has config => (is => 'ro', required => 1);

my %procs = (
  10 => sub {
    my $config = shift;
    my $track_schema = shift;
    my $load_util = shift;

    $load_util->get_cvterm(cv_name => 'cvterm_property_type',
                           term_name => 'canto_subset',
                           ontologyid => 'Canto:canto_subset');


    my $update_proc = sub {
      my $curs = shift;
      my $curs_key = $curs->curs_key();
      my $curs_schema = shift;

      my $rs = $curs_schema->resultset('Annotation');

      for my $an ($rs->all()) {
        my $data = $an->data();

        my $extension_string = delete $data->{annotation_extension};

        try {
          if ($extension_string) {
            my $extension = Canto::ExtensionUtil::parse_extension($extension_string);
            $data->{extension} = $extension;
            $an->data($data);
            $an->update();
          }
        } catch {
          warn qq(failed to store extension in $curs_key: $_);
        };
      }
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);

  },
);

sub upgrade_to
{
  my $self = shift;
  my $version = shift;

  my $track_schema = Canto::TrackDB->new(config => $self->config());
  my $load_util = Canto::Track::LoadUtil->new(schema => $track_schema);

  if (exists $procs{$version}) {
    $procs{$version}->($self->config(), $track_schema, $load_util);
  } else {
    die "don't know how to upgrade to $version\n";
  }
}

1;
