package Canto::Track::PersonLookup;

=head1 NAME

Canto::Track::PersonLookup - An adaptor for retrieve user information

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::PersonLookup

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

=head2 lookup()

 Usage   : my $person_lookup = Canto::Track::get_adaptor($config, 'person');
 Function: Lookup user information in TrackDB
 Args    : $lookup_type - 'name': find users by an exact name match
                          'email': find user by email match
           $search_string - a name or email address
 Return  : For the 'name' lookup type, a list of person detail hashes like this
           (assuming 'Fred Smith' as the search_string) or an empty list:
           [ { name => 'Fred Smith', role => 'admin',
               email => 'fred@biguniversity.edu' },
             { name => 'Fred Smith', role => 'user',
               email => 'fred@otheruniversity.ac.uk' } ]
           The 'email' lookup type can only return a single user or undef:
             { name => 'Fred Smith', role => 'user',
               email => 'fred@otheruniversity.ac.uk' }

=cut

sub lookup
{
  my $self = shift;

  my $lookup_type = shift;
  my $search_string = trim(shift);

  if (!defined $search_string || length $search_string == 0) {
    return {
      error => 'No search string given for person lookup',
    };
  }

  $search_string =~ s/\*\s*$/\%/;

  my $schema = $self->schema();

  my $person_rs =
    $schema->resultset('Person')->search({}, { prefetch => 'role' });

  if ($lookup_type eq 'name') {
    return map {
      { name => $_->name(), email => $_->email_address(),
        role => $_->role()->name(), id => $_->person_id(), };
    } $person_rs->search({ 'me.name' => {  -like => $search_string } })->all();
  } else {
    if ($lookup_type eq 'email') {
      my $person =
        $person_rs->find({ 'me.email_address' => $search_string });
      return {
        name => $person->name(),
        email => $person->email_address(),
        role => $person->role()->name(),
        id => $person->person_id(),
      };
    } else {
      return {
        error => 'No search string given for person lookup',
      };
    }
  }
}

1;
