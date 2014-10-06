package Canto::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use Text::MultiMarkdown qw(markdown);
use IO::All;

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
            warn 'internal error: ', $_;
            {
              title => 'Internal error',
              text => $_
            }
          } @{$c->error()};
    $st->{error} = \@canto_errors;
    $st->{title} = 'Error';
    $st->{template} = $st->{error_template} // 'error.mhtml';
    $c->forward('Canto::View::Mason');
    $c->error(0);
    return 0;
  }

  # copied from RenderView.pm
  if (! $c->response->content_type ) {
    $c->response->content_type( 'text/html; charset=utf-8' );
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
    if ($static_page) {
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
  _do_local_and_docs('docs', @_);
}

=head2 account

 User page for logins

=cut
sub account :Global
{
  my ($self, $c) = @_;

  my $st = $c->stash;

  $st->{title} = "Log in to continue";
  $st->{template} = 'account.mhtml';

  $st->{return_path} = $c->req()->param("return_path");
}

=head2 login

 Try to authenticate a user based on email_address and password parameters

=cut
sub login : Global {
  my ( $self, $c ) = @_;
  my $email_address = $c->req->param('email_address');
  my $password = $c->req->param('password');

  my $return_path = $c->req->param('return_path');

  if (!defined $password || length $password == 0) {
    $c->stash()->{error} =
      { title => "Login error",
        text => "No password given, please try again" };
    $c->forward('account');
    $c->detach();
    return 0;
  }

  if ($c->authenticate({email_address => $email_address,
                        password => $password})) {
    $c->flash->{message} =
      { title => "Login successful" };

    if ($return_path =~ m/logout|login/) {
      $c->forward($c->config()->{instance_front_path});
      return 0;
    }
  } else {
    $c->stash()->{error} =
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

  $c->stash()->{message} = "You have been logged out";
  $c->forward('front');
}

=head2 access_denied

 Usage   : Called by Catalyst
 Function: Redirect to account page if the user isn't logged in
 Args    : none
 Returns : redirects and then detaches

=cut
sub access_denied : Private {
  my ($self, $c, $action) = @_;

  $c->res->redirect($c->uri_for('/account',
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
