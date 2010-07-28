package PomCur::Track;

=head1 NAME

PomCur::Track - Utilities for the tracking database

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use Moose;

use PomCur::Config;

=head2

 Usage   : PomCur::Track::create_template_dbs();
 Function: create empty databases in the template directory and load them with
           the appropriate schemas

=cut
sub create_template_dbs
{
  my $config = PomCur::Config::get_config();

  my %model_files = (
    track => $config->{track_db_template_file},
    curs => $config->{curs_db_template_file}
  );

  for my $model_name (keys %model_files) {
        unlink $model_files{$model_name};

    my $sql = "etc/$model_name.sql";

    print "Creating: $model_files{$model_name} from $sql\n";
    system "sqlite3 $model_files{$model_name} < etc/$model_name.sql";
  }

}

1;
