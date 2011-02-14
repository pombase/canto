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

  my $st = $c->stash();

  if (exists $c->request()->parameters()->{testmode}) {
    $c->session()->{testmode} = $c->request()->parameters()->{testmode};
  }

  if (scalar @{ $c->error }) {
    my @pomcur_errors =
      map {
            {
              title => 'Internal error',
              text => $_
            }
          } @{$c->error()};
    $st->{error} = \@pomcur_errors;
    $st->{title} = 'Error';
    $st->{template} = 'error.mhtml';
    $c->forward('PomCur::View::Mason');
    $c->error(0);
    return 0;
  }

  $st->{app_version} = $c->config()->{app_version};

  # copied from RenderView.pm
  if (! $c->response->content_type ) {
    $c->response->content_type( 'text/html; charset=utf-8' );
  }
  return 1 if $c->req->method eq 'HEAD';
  return 1 if length( $c->response->body );
  return 1 if scalar @{ $c->error } && !$st->{template};
  return 1 if $c->response->status =~ /^(?:204|3\d\d)$/;
  $c->forward('PomCur::View::Mason');
}

# In development use, redirect to the tracking application
sub front :Path :Args(0)
{
  my ($self, $c) = @_;

  $c->forward('/track/track');
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


=head2

 Usage   : Called by Catalyst
 Function: Create a new curation session for testing, then redirect to a page
           that links to it

=cut
sub test_curs :Global {
  my ($self, $c, $arg) = @_;

  my $st = $c->stash();

  $st->{template} = 'view_curs_test.mhtml';

  my $schema = $c->schema('track');
  my $config = $c->config();

  my $pub = $schema->resultset('Pub')->first();
  my $curs_key = PomCur::Curs::make_curs_key();

  $st->{title} = "Link to new test curation session " . $curs_key;

  my $person = $schema->resultset('Person')->first();
  my $curs = $schema->create_with_type('Curs',
                                       {
                                         pub => $pub,
                                         community_curator => $person,
                                         curs_key => $curs_key,
                                       });

  my $curs_schema = PomCur::Track::create_curs_db($config, $curs);

  $st->{curs_key} = $curs_key;

  if (defined $arg) {
    if ($arg >= 1) {
      $curs_schema->create_with_type('Metadata', { key => 'submitter_email',
                                                   value => 'test@test.com' });

      $curs_schema->create_with_type('Metadata', { key => 'submitter_name',
                                                   value => 'Dr T. Tester' });
    }
    if ($arg >= 2) {
      my $gene_track_rs = $schema->resultset('Gene');
      my $gene1 = $gene_track_rs->next();
      my $gene2 = $gene_track_rs->next();

      my $gene1_identifier = $gene1->primary_identifier();
      my $gene2_identifier = $gene2->primary_identifier();
      use PomCur::Controller::Curs;
      PomCur::Controller::Curs::_find_and_create_genes($curs_schema, $config,
                                                       [$gene1_identifier,
                                                        $gene2_identifier]);
      my $gene_rs = PomCur::Controller::Curs::_get_gene_resultset($curs_schema);
      my $first_curs_gene = $gene_rs->first();

      PomCur::Controller::Curs::_set_new_gene($curs_schema);
    }
  }
}


=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
