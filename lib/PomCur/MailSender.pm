package PomCur::MailSender;

=head1 NAME

PomCur::MailSender - Code for sending email

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::MailSender

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

use Email::Sender::Simple qw(sendmail);
use Email::MIME;
use Email::Sender::Transport::Sendmail qw();
use Try::Tiny;

with 'PomCur::Role::Configurable';

=head2 send

 Usage   : $mail_sender->send(subject => '...', body => '...',
                              to => '...');
 Function: send an email
 Args    : subject - email subject
           body - email body or undef
           to - email recipient
           from - (optional) the sender - defaults to email->from_address in the
                                          config file
 Return  : nothing, failures are logged

=cut
sub send
{
  my $self = shift;
  my %args = @_;
  my $to = $args{to};
  my $from = $args{from};

  if ($self->config()->{test_mode} || $::test_mode) {
    return;
  }

  my $subject = $args{subject} // 'no_subject';
  my $body = $args{body} // '';

  if (!defined $from) {
    warn "'from' email address not configured - email with subject " .
      "'$subject' not sent";
    return;
  }

  my $email = Email::MIME->create(
    header=>[To=>$to, From=>$from,
             Subject=>$subject],
    body=>$body,
  );

  $email->content_type_set('text/plain');
  $email->header_set('MIME-Version', '1.0');

  my $email_config = $self->config()->{email};
  my $reply_to = $email_config->{reply_to};

  if (defined $reply_to) {
    $email->header_set('Reply-To', $reply_to);
  }

  try {
    sendmail($email,
             {
               from => $from,
               transport => Email::Sender::Transport::Sendmail->new()
             });
  } catch {
    warn qq|Cannot send mail to "$to" with subject "$subject": $_|;
  }
}

=head2 send_to_admin

 Usage   : $mail_sender->send_to_admin(subject => '...', body => '...');
 Function: send an email to the admin user
 Args    : subject - email subject
           body - email body or undef
 Return  : nothing, failures are logged

=cut
sub send_to_admin
{
  my $self = shift;
  my %args = @_;
  my $subject = $args{subject};
  my $body = $args{body};

  my $config = $self->config();

  my $email_config = $config->{email};

  if (!defined $email_config) {
    warn "email not configured - email to admin not sent\n";
    return;
  }

  my $admin_address_key = 'admin_address';
  my $admin_address = $email_config->{$admin_address_key};

  if (!defined $admin_address) {
    warn "admin email address not configured - email with subject " .
      "'$subject' not sent";
    return;
  }

  $self->send(to => $admin_address,
              from => $email_config->{noreply_address},
              subject => $subject,
              body => $body);
}

1;
