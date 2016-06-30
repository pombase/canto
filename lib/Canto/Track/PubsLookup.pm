package Canto::Track::PubsLookup;

=head1 NAME

Canto::Track::PubsAdapator - Look up publications from Curs code

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::PubsAdapator

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;

with 'Canto::Role::Configurable';
with 'Canto::Track::TrackAdaptor';

use Canto::Util qw(trim);
use Canto::Track::CuratorManager;

=head2 lookup()

 Usage   : my $pubs_lookup = Canto::Track::get_adaptor($config, 'pubs');
           my $res = $pubs_lookup->lookup_by_curator_email('test@example.com');
 Function: Lookup publications in the TrackDB by curator email address
           $email_address - email address

=cut

sub lookup_by_curator_email
{
  my $self = shift;

  my $email_address = trim(shift);

  my $config = $self->config();

  my $curator_manager = Canto::Track::CuratorManager->new(config => $config);

  my $rs = $curator_manager->sessions_by_curator_email($email_address);

  $rs = $rs->search({ 'type.name' => 'annotation_status' },
                    { join => { cursprops => 'type' },
                      '+columns' => ['cursprops.value'] });

  my $count = $rs->count();

  return
    {
      results => [
        map {
          {
            curs_key => $_->curs_key(),
            pub_uniquename => $_->pub()->uniquename(),
            status => $_->cursprops()->first()->value(),
          };
        } $rs->search({}, { rows => 100 })->all()
      ],
      count => $count,
    };
}

1;
