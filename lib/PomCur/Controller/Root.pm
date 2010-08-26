package PomCur::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

__PACKAGE__->config->{namespace} = '';

=head1 NAME

PomCur::Controller::Root - Root Controller for PomCur tracking application

=head1 METHODS

=cut

sub default :Path
{
  my ($self, $c) = @_;

  my $st = $c->stash;

  $st->{title} = "Page not found";
  $st->{template} = 'not_found_404.mhtml';
  $c->response->status(404);
}

=head2 end

 Attempt to render a view, if needed.

=cut

sub end : Private
{
  my $self = shift;
  my $c = shift;

  if (scalar @{ $c->error }) {
    $c->stash->{error} = $c->error;
    $c->stash->{title} = 'Error';
    $c->stash->{template} = 'error.mhtml';
    $c->forward('MyApp::View::TT');
    $c->error(0);
    return 0;
  }


  # copied from RenderView.pm
  if (! $c->response->content_type ) {
    $c->response->content_type( 'text/html; charset=utf-8' );
  }
  return 1 if $c->req->method eq 'HEAD';
  return 1 if length( $c->response->body );
  return 1 if scalar @{ $c->error } && !$c->stash->{template};
  return 1 if $c->response->status =~ /^(?:204|3\d\d)$/;
  $c->forward('PomCur::View::Mason');
}

# In development use, redirect to the tracking application
sub front :Path :Args(0)
{
  my ($self, $c) = @_;

  $c->forward('/track/index');
  $c->detach();
}

=head2 account

 User page for logins

=cut
sub account :Global
{
  my ($self, $c) = @_;

  my $st = $c->stash;

  $st->{title} = "Account details";
  $st->{template} = 'account.mhtml';

  $st->{return_path} = $c->req()->param("return_path");
}

=head2 login

 Try to authenticate a user based on networkaddress and password parameters

=cut
sub login : Global {
  my ( $self, $c ) = @_;
  my $networkaddress = $c->req->param('networkaddress');
  my $password = $c->req->param('password');

  my $return_path = $c->req->param('return_path');

  if ($c->authenticate({networkaddress => $networkaddress, password => $password})) {
    $c->flash->{message} =
      { title => "Login successful" };

    if ($return_path =~ m/logout|login/) {
      $c->forward('/track/index');
      return 0;
    }
  } else {
    $c->flash->{error} =
      { title => "Login error",
        text => "Incorrect email address or password, please try again" };
    $c->forward('account');
    $c->detach();
    return 0;
  }

  $c->res->redirect($return_path, 302);
  $c->detach();
  return 0;
}

=head2 logout

 Log out the user and return to the front page.

=cut

sub logout : Global {
  my ( $self, $c ) = @_;
  $c->logout;

  $c->stash->{message} = "Logged out";
  $c->forward('track/index');
}



=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
