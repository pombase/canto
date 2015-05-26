package Canto::EmailUtil;

=head1 NAME

Canto::EmailUtil - Utilities needed for sending email to users

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::EmailUtil

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use Moose;
use Carp;
use feature 'switch';
use File::Spec;

use HTML::Mason;

with 'Canto::Role::Configurable';

use Canto::Curs::Utils;

sub _process_template
{
  my $self = shift;
  my $interp = shift;
  my $component_path = shift;
  my %args = @_;

  my $buffer;
  # This will save the component's output in $buffer
  $interp->out_method(\$buffer);

  $interp->exec("/$component_path", config => $self->config(), %args);

  return $buffer;
}

=head2 make_email

 Usage   : my ($subject, $body, $from) = $email_util->make_email($type, %args);
 Function: Return the subject and body text to send to users in various
           situations
 Args    : $type - the type of email to compose, one of:
                    - session_assigned - a curator has assigned a session to
                                         community user/curator
                    - session_resent - a session link needs to be resent to a
                                       community user/curator who hasn't
                                       started curation
                    - session_reassigned - user has reassigned a session
                    - session_accepted - the user has filled in their name and
                                         email address
                    - reassigner - email sent to a user who reassigns a session
                    - daily_summary - sent once a day to the admins, listing
                                      new sessions, sessions needing approval,
                                      and counts of session statuses
           %args - parameters that can be use in the templates:
                    - track_schema - a TrackDB object
                    - session_link - full URL of the session
                    - curator_name - the name of the user currently curating
                                     the session
                    - curator_known_as - how to address the user, eg. "Dr Smith"
                                         (could be undef)
                    - curator_email - the email of the user - the recipient of
                                      this email
                    - reassigner_name - for the "reassigner" template, the name
                                        of the person doing the reassigning
                    - publication_uniquename - the PMID ID of the publication
                    - publication_title - the title of the publication
                    - help_index - the URL of the documentation
                    - summary_date - date to use in daily_summary template
                    - app_prefix - the base URL of a application
                    - logged_in_user - the current user
 Return  : the subject and body of the email to send

=cut

sub make_email
{
  my $self = shift;
  my $email_type = shift;
  my %args = @_;

  my $root = File::Spec->rel2abs('root');
  my $interp =
    HTML::Mason::Interp->new(comp_root => $root,
                             default_escape_flags => 'n');

  my $type_config = $self->config()->{email}->{templates}->{$email_type};

  my $subject_component_path = $type_config->{subject};
  if (!defined $subject_component_path) {
    croak "can't find a component for subject of: $email_type\n";
  }

  my $body_component_path = $type_config->{body};
  if (!defined $body_component_path) {
    croak "can't find a component for body of: $email_type\n";
  }

  $args{config} = $self->config();

  if (!$type_config->{global}) {
    my %options = ( max_results => 1,
                    pub_uniquename => $args{publication_uniquename} );

    my ($all_existing_annotations_count, $existing_annotations) =
    Canto::Curs::Utils::get_existing_annotation_count($self->config(), undef, \%options);

    $args{existing_annotation_count} = $all_existing_annotations_count;
  }

  my $subject = $self->_process_template($interp, $subject_component_path, %args);
  $subject =~ s/^\n+//g;
  $subject =~ s/\n+$//g;

  my $body = $self->_process_template($interp, $body_component_path, %args);

  $body =~ s/\n\n+/\n\n/g;

  my $from_email_address = undef;

  my $type_from = $type_config->{from_address};

  if (defined $type_from) {
    if ($type_from eq 'CURRENT_USER') {
      my $user = $args{logged_in_user};
      $from_email_address =
        $user->name() . ' <' . $user->email_address() . '>';
    } else {
      $from_email_address = $type_from;
    }
  }

  if (!defined $from_email_address) {
    my $config = $self->config();

    my $email_config = $config->{email};

    if (!defined $email_config) {
      warn "email addresses not configured - email not sent\n";
      return;
    }

    # use the default from address
    $from_email_address = $email_config->{from_address};
  }

  return ($subject, $body, $from_email_address);
}

1;
