package Canto;

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
                Cache
                PageCache
                Session
                Session::State::Cookie
                Session::Store::DBI
                Session::PerUser
                Static::Simple/;
use Moose;
use CatalystX::RoleApplicator;

our $VERSION = '0.01';

__PACKAGE__->config(name => 'Canto',
                    'Plugin::Session' => {
                      expires   => 620000,
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
                    'Plugin::Static::Simple' => {
                      dirs => [
                        'static'
                      ],
                    },
                    'Plugin::PageCache' => {
                      set_http_headers => 1,
                      disable_index => 1,
                    },
                    using_frontend_proxy => 1,
                    encoding => 'utf8',
                   );


__PACKAGE__->config->{'Plugin::Cache'}{backend} = {
  class => "Cache::Memory",
};

extends 'Catalyst';

__PACKAGE__->apply_request_class_roles(qw/
                                       Catalyst::TraitFor::Request::ProxyBase
                                       /);

# this variable exists only so the tests can disable access control
our $access_control_enabled //= 1;

sub debug
{
  return $ENV{CANTO_DEBUG};
}

# Start the application
__PACKAGE__->setup();

__PACKAGE__->deny_access_unless(
  '/',
  sub {
    my ($c, $action) = @_;

    return $c->user_exists() || $c->config()->{public_mode} ||
      !$access_control_enabled || $action eq 'front' || $action eq 'begin';
  },
);
__PACKAGE__->allow_access('/default');
__PACKAGE__->allow_access('/end');
__PACKAGE__->allow_access('/oauth');
__PACKAGE__->allow_access('/login_needed');
__PACKAGE__->allow_access('/curs');
__PACKAGE__->allow_access('/ws');
__PACKAGE__->allow_access('/tools/pubmed_id_lookup');
__PACKAGE__->allow_access('/tools/start');
__PACKAGE__->allow_access('/local');
__PACKAGE__->allow_access('/docs');
__PACKAGE__->allow_access('/stats');

my $config = __PACKAGE__->config();

# this is hacky, but allows us to call methods on the config object
bless $config, 'Canto::Config';

use Canto::Config;

$config->setup();

my %_schema_map = ( track => "TrackDB",
                    meta => "MetaDB",
                    chado => "ChadoDB" );

before 'prepare_action' => sub {
  my $self = shift;

  my $base_path = $self->uri_for('/')->path() || 'root';

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

  my $schema_class_name = "Canto::$_schema_map{$model_name}";

  die "unknown model ($model_name) passed to schema()\n"
    unless defined $schema_class_name;

  state $schema_cache = {};

  my $schema;

  if (exists $schema_cache->{$schema_class_name}) {
    $schema = $schema_cache->{$schema_class_name};
  } else {
    eval "require $schema_class_name;";

    $schema = $schema_class_name->new(config => $self->config());

    if ($model_name eq 'track') {
      Canto::DBUtil::check_schema_version($config, $schema);
    }

    $schema_cache->{$schema_class_name} = $schema;
  }

  return $schema;
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

Canto::DBUtil::check_schema_version($config, schema(__PACKAGE__, 'track'));
Canto::DBUtil::check_db_organism($config, schema(__PACKAGE__, 'track'));

1;
