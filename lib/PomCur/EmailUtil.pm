package PomCur::EmailUtil;

=head1 NAME

PomCur::EmailUtil - Utilities needed for sending email to users

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::EmailUtil

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;
use Carp;
use feature 'switch';
use File::Spec;

use HTML::Mason;

with 'PomCur::Role::Configurable';

use PomCur::Curs::Utils;

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

=head2 make_email_contents

 Usage   : my ($subject, $body) = $email_util->make_email_contents($type, %args);
 Function: Return the subject and body text to send to users in various
           situations
 Args    : $type - the type of email to compose, one of:
                    - session_assigned - the curators has assigned a session to
                                         community user/curator
                    - session_reassigned - user has reassigned a session
                    - session_accepted - the user has filled in their name and
                                         email address
           %args - parameters that can be use in the templates:
                    - session_link - full URL of the session
                    - curator_name - the user currently curating that session
                    - publication_uniquename - the PMID ID of the publication
                    - publication_title - the title of the publication
                    - help_index - the URL of the documentation
 Return  : the subject and body of the email to send

=cut

sub make_email_contents
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

  my %options = ( max_results => 1,
                  pub_uniquename => $args{publication_uniquename} );

  my ($all_existing_annotations_count, $existing_annotations) =
    PomCur::Curs::Utils::get_existing_annotation_count($self->config(), \%options);

  $args{existing_annotation_count} = $all_existing_annotations_count;

  my $subject = $self->_process_template($interp, $subject_component_path, %args);
  $subject =~ s/^\n+//g;
  $subject =~ s/\n+$//g;

  my $body = $self->_process_template($interp, $body_component_path, %args);

  $body =~ s/\n\n+/\n\n/g;

  return ($subject, $body);
}

1;
