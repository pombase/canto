package Canto::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use Text::MultiMarkdown qw(markdown);
use IO::All;
use Digest::SHA;
use LWP::UserAgent;
use URI;
use JSON::Any;

__PACKAGE__->config->{namespace} = '';

=head1 NAME

Canto::Controller::Root - Root Controller for Canto tracking application

=head1 METHODS

=cut

=head2 default

 Return the page not found message

=cut
sub default :Path
{
  my ($self, $c) = @_;

  my $st = $c->stash;

  $st->{title} = "Page not found";
  $st->{show_title} = 0;
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

  my $is_admin = $c->user_exists() && $c->user()->role()->name() eq 'admin';
  $c->stash()->{is_admin_user} = $is_admin;

  if (scalar @{ $c->error }) {
    my @canto_errors =
      map {
        use Data::Dumper;
        warn 'internal error: ', Dumper($_);
            {
              title => 'Internal error',
              text => $_
            }
          } @{$c->error()};
    $st->{error} = \@canto_errors;
    $st->{title} = 'Error';
    $st->{template} = $st->{error_template} // 'error.mhtml';
    $c->response()->status(500);
    $c->forward('Canto::View::Mason');
    $c->error(0);
    return 0;
  }

  if (delete $st->{cache_this_link} && !$ENV{CANTO_DEBUG}) {
    $c->cache_page(99999);
  }

  # copied from RenderView.pm
  if (! $c->response->content_type) {
    $c->response->content_type( 'text/html; charset=utf-8');
  }
  return 1 if $c->req->method eq 'HEAD';
  return 1 if defined $c->response->body && length($c->response->body);
  return 1 if scalar @{ $c->error } && !$st->{template};
  return 1 if $c->response->status =~ /^(?:204|3\d\d)$/;
  $c->forward('Canto::View::Mason');
}

# go to the "local" front page
sub local_front : Global
{
  my ($self, $c) = @_;

  $c->forward($c->config()->{local_front_page});
  $c->detach();
}

# redirect to the tracking application
sub front :Path :Args(0)
{
  my ($self, $c) = @_;

  $c->forward($c->config()->{instance_front_path});
  $c->detach();
}


sub _do_local_and_docs
{
  my ($docs_path, $self, $c, @page_path) = @_;

  my $config = $c->config();

  my $st = $c->stash();

  $st->{title} = $config->{long_name};
  $st->{show_title} = 1;

  if (!@page_path) {
    my $default_page = $config->{"default_${docs_path}_page"};
    if (defined $default_page) {
      push @page_path, $default_page;
    } else {
      push @page_path, 'index';
    }
  }

  my $template_file_name;
  my @page_path_with_suffix = @page_path;
  $page_path_with_suffix[-1] .= '.mhtml';
  my $template_file = $c->path_to('root', $docs_path, @page_path_with_suffix);

  my @doc_path = @page_path;

  if (@doc_path > 1 || $doc_path[0] ne "index") {
    unshift @doc_path, "index";
  }

  if (-f $template_file) {
    $template_file_name = "$docs_path/" . join "/", @page_path_with_suffix;
  } else {
    my @page_path_with_suffix = @page_path;
    $page_path_with_suffix[-1] .= '.md';

    my $markdown_file = $c->path_to('root', $docs_path, 'md', @page_path_with_suffix);

    if (-f $markdown_file) {
      my $markdown_text = io($markdown_file)->slurp;
      $markdown_text =~ s/^#\w*([^\n]+)\n(.*)/$2/;
      my $page_title = $1;
      $st->{title} = $page_title;
      $st->{rendered_markdown_html} = markdown($markdown_text);

      $template_file_name = "docs/render_markdown.mhtml";
      $template_file = $c->path_to('root', $template_file_name);
    }
  }

  my $hide_header = 0;
  my $hide_footer = 0;
  my $hide_breadcrumbs = 0;
  my $static_page = 0;
  my $use_bootstrap = 0;

  if (-f $template_file) {
    my $template_contents = io($template_file)->slurp();

    if ($template_contents =~ /<!--\s*PAGE_TITLE:\s*(.*?)\s*-->/) {
      my $title = Canto::WebUtil::substitute_paths($1, $config);
      $st->{title} = $title;
    }
    if ($template_contents =~ /<!--\s*PAGE_SUBTITLE:\s*(.*?)\s*-->/) {
      my $sub_title = Canto::WebUtil::substitute_paths($1, $config);
      $st->{sub_title} = $sub_title;
    }

    if ($template_contents =~ /<!--\s*FLAGS:\s*(.*?)\s*-->/) {
      my $all_flags = $1;
      my @flags = split /\s+/, $all_flags;
      if (grep { $_ eq 'hide_header' } @flags) {
        $hide_header = 1;
        $static_page = 1;
      }
      if (grep { $_ eq 'hide_footer' } @flags) {
        $hide_footer = 1;
      }
      if (grep { $_ eq 'hide_breadcrumbs' } @flags) {
        $hide_breadcrumbs = 1;
      }
      if (grep { $_ eq 'use_bootstrap' } @flags) {
        $use_bootstrap = 1;
      }
      if (grep { $_ eq 'static_page' } @flags) {
        $static_page = 1;
      }
    }

    $st->{hide_header} = $hide_header;
    $st->{static_page} = $static_page;
    if ($static_page && !$ENV{CANTO_DEBUG}) {
      # no login button, so we can cache it
      $c->cache_page(300);
    }
    $st->{hide_footer} = $hide_footer;
    $st->{hide_breadcrumbs} = $hide_breadcrumbs;
    $st->{use_bootstrap} = $use_bootstrap;
    $st->{template} = $template_file_name;

    $st->{doc_path} = [map {
      my $el = $_;
      (my $description = ucfirst $_) =~ s/_/ /g;
      {
        el => $el,
        description => $description,
      };
    } @doc_path];
  } else {
    $c->stash()->{error} =
      { title => "No such page",
        text => (join "/", @page_path) . " doesn't exist" };
    $c->forward('/default');
    $c->detach();
  }
}

=head2 local

 Function: Render an HTML template from the local directory
 Args    : $name - page name

=cut
sub local : Global('local')  # local, Global, local ... oh dear
{
  _do_local_and_docs('local', @_);
}

=head2 docs

 Function: Render an HTML template from the docs directory
 Args    : $name - page name

=cut
sub docs : Global('docs')
{
  my ($self, $c) = @_;

  my $base_docs_path = $c->config()->{base_docs_path};

  _do_local_and_docs($base_docs_path, @_);
}

=head2 login_needed



=cut
sub login_needed :Global
{
  my ($self, $c) = @_;

  my $st = $c->stash;

  $st->{title} = "Log in to continue";
  $st->{template} = 'login_needed.mhtml';
}

my $json = JSON::Any->new;

sub request_access_token
{
  my ($self, $c, $callback_uri, $code, $auth_info) = @_;

  my $oauth_config = $c->config()->{oauth};
  my $token_uri = $oauth_config->{token_uri};
  my $client_id = $oauth_config->{client_id};
  my $client_secret = $oauth_config->{client_secret};

  my $uri = URI->new($token_uri);
  my $query = {
    client_id => $client_id,
    client_secret => $client_secret,
    redirect_uri => $callback_uri,
    code => $code,
    grant_type => 'authorization_code'
  };

  my $response = LWP::UserAgent->new()->post($uri, $query);

  return unless $response->is_success;
  return $json->jsonToObj($response->decoded_content());
}

sub _build_callback_uri {
  my ($self, $c) = @_;
  my $uri = $c->request->uri->clone();
  $uri->query(undef);
  return $uri;
}

sub authenticate
{
  my ($self, $c, $auth_info) = @_;
  my $callback_uri = $self->_build_callback_uri($c);

  if (!defined(my $code = $c->req()->params->{code})) {
    my $oauth_config = $c->config()->{oauth};
    my $grant_uri = $oauth_config->{grant_uri};
    my $client_id = $oauth_config->{client_id};
    my $scope = $oauth_config->{scope};
    my $uri = URI->new($grant_uri);
    my $query = {
      response_type => 'code',
      client_id => $client_id,
      redirect_uri => $callback_uri,
      state => $auth_info->{state},
      scope => $scope,
    };
    $uri->query_form($query);
    $c->response->redirect($uri);

    return;
  } else {
    my $token =
      $self->request_access_token($c, $callback_uri, $code, $auth_info);

    die 'Error validating verification code' unless $token;

    if (length $token->{orcid}) {
      $c->authenticate({orcid => $token->{orcid}});
    }
  }
}

=head2 oauth

 Authenticate using OAuth2

=cut

sub oauth :Global
{
  my ($self, $c) = @_;

  if (exists $c->request->params->{error}) {
    $c->stash(template => "login_failed.mhtml");
    $c->stash(title => "Failed to authenticate using " . $c->config()->{oauth}->{authenticator});
    $c->stash()->{oauth_error} = $c->request->params->{error_description};
    $c->detach();
    return;
  }

  my $return_uri = $c->req()->params()->{return_path};

  if ($return_uri) {
    $c->flash()->{oauth_return_uri} = $return_uri;
  }

  my $sha1 = undef;
  if (exists $c->request->params->{state}) {
    $sha1 = $c->request->params->{state};

    if ($sha1 ne $c->session->{oauth_state}) {
      $c->log->debug("state doesn't match $sha1 vs " . $c->session->{oauth_state});
    }
  } else {
    $sha1 = Digest::SHA->new(512)->add($$, "Auth for login",
                                       Time::HiRes::time(), rand()*10000)->hexdigest();
    $sha1 = substr($sha1, 4, 16);
    $c->session(oauth_state => $sha1);
  }

  if ($self->authenticate($c, {
    state => $sha1,
  })) {
    $c->log->debug("Authenticated!");

    my $return_uri = $c->stash()->{oauth_return_uri};
    if ($return_uri) {
      $c->response->redirect($return_uri);
    } else {
      $c->response->redirect($c->uri_for("/"));
    }
    $c->detach();
  } elsif (exists $c->req->params->{ code }) {
    $c->stash()->{error} = "Login failed - no such user";
    $c->forward('front');
  }
}

=head2 logout

 Log out the user and return to the front page.

=cut

sub logout : Global {
  my ($self, $c) = @_;

  $c->logout();

  $c->flash()->{message} = "You have been logged out";
  $c->response->redirect($c->uri_for("/"));
}

=head2 access_denied

 Usage   : Called by Catalyst
 Function: Redirect to account page if the user isn't logged in
 Args    : none
 Returns : redirects and then detaches

=cut
sub access_denied : Private {
  my ($self, $c, $action) = @_;

  $c->res->redirect($c->uri_for('/login_needed',
                                { return_path => $c->req()->uri() }));
  $c->detach();
}

=head1 LICENSE

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=cut

1;
