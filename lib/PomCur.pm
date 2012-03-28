package PomCur;

use strict;
use warnings;

use feature ':5.10';

use Catalyst::Runtime 5.80;

use parent qw/Catalyst/;
use Catalyst qw/ConfigLoader
                StackTrace
                Authentication
                Authorization::Roles
                Authorization::ACL
                Session
                Session::State::Cookie
                Session::Store::DBI
                Session::PerUser
                Static::Simple/;

use Moose;
use CatalystX::RoleApplicator;

our $VERSION = '0.01';

__PACKAGE__->config(name => 'PomCur',
                    'Plugin::Session' => {
                      expires   => 86400,
                      dbi_dbh   => 'TrackModel',
                      dbi_table => 'sessions',
                      dbi_id_field => 'id',
                      dbi_data_field => 'session_data',
                      dbi_expires_field => 'expires',
                      flash_to_stash => 1,
                    },
                    'View::Graphics::Primitive' => {
                      driver => 'Cairo',
                      driver_args => { format => 'pdf' },
                      content_type => 'application/pdf',
                    },
                    'View::JSON' => {
                      expose_stash => 'json_data',
                    },
                    static => {
                      ignore_extensions => [ qw/html xhtml mhtml tt tt2 tmpl/ ],
                      dirs => [
                        'static'
                      ],
                    },
                   );



extends 'Catalyst';

__PACKAGE__->apply_request_class_roles(qw/
                                       Catalyst::TraitFor::Request::ProxyBase
                                       /);

# this variable exists only so the tests can disable access control
our $access_control_enabled //= 1;

sub debug
{
  return $ENV{POMCUR_DEBUG};
}

# Start the application
__PACKAGE__->setup();

__PACKAGE__->deny_access_unless(
  '/',
  sub {
    my $c = shift;
    return $c->user_exists() || $c->config()->{public_mode} ||
      !$access_control_enabled;
  },
);
__PACKAGE__->allow_access('/end');
__PACKAGE__->allow_access('/account');
__PACKAGE__->allow_access('/login');
__PACKAGE__->allow_access('/curs');

my $config = __PACKAGE__->config();

# this is hacky, but allows us to call methods on the config object
bless $config, 'PomCur::Config';

use PomCur::Config;

$config->setup();

my %_schema_map = ( track => "TrackDB",
                    meta => "MetaDB",
                    chado => "ChadoDB" );

before 'prepare_action' => sub {
  my $self = shift;

  my $base_path = $self->request_base_path() // '/root';
  (my $cookie_path = $base_path) =~ s:/:_:g;

  # make sure the cookie name is unique if there are multiple
  # instances on one server
  $self->config()->{'Plugin::Session'}->{cookie_name} =
    $self->config()->{name} . "${cookie_path}_session";
};

=head2 schema

 Usage   : my $schema = $c->schema();
 Function: Return the appropriate schema object, based on the model parameter
           of the request, or explicitly if a model_name is pass as an argument.
 Args    : $model_name - the name of schema to return (optional)

=cut
sub schema
{
  my $self = shift;
  my $model_name = shift || $self->req()->param('model');

  die "no model passed to schema()\n" unless defined $model_name;

  my $schema_class_name = "PomCur::$_schema_map{$model_name}";

  die "unknown model ($model_name) passed to schema()\n"
    unless defined $schema_class_name;

  eval "require $schema_class_name";

  return $schema_class_name->new(config => $self->config());
}

=head2

 Usage   : my $local_path = $c->local_path();
 Function: If Catalyst::TraitFor::Request::ProxyBase is enabled use the
           'X-Request-Base' header to find the base path, remove it from
           the request path, then return the result.  If ProxyBase isn't
           enabled, just return the path from the URI of the current request
 Args    : None
 Return  : The local path

=cut
sub local_path
{
  my $self = shift;

  my $path = $self->req->uri()->path();
  my $base = $self->request_base_path();

  if ($base) {
    $path =~ s/\Q$base//;
  }

  return $path;
}

=head2 request_base_path

 Usage   : $base_path = $c->request_base_path();
 Function: Return the value of the X-Request-Base header.

=cut
sub request_base_path
{
  my $self = shift;

  return $self->req()->header('X-Request-Base');
}

# this code adds the application version to the paths of all static content so
# we can use a far future expires header in safety
around 'uri_for' => sub {
  my $orig = shift;
  my $self = shift;

  my $path = shift;

  my $config = $self->config();
  my $version = $config->{app_version};

  if (defined $ENV{PLACK_ENV}) {
    $path =~ s:/static/(.*):/static/$version/$1:;
  }

  $self->$orig($path, @_);
};

1;
