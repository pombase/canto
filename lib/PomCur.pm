package PomCur;

use strict;
use warnings;

use feature ':5.10';

use Catalyst::Runtime 5.80;

use parent qw/Catalyst/;
use Catalyst qw/ConfigLoader
                StackTrace
                Authentication
                Session
                Session::State::Cookie
                Session::Store::DBI
                Session::PerUser
                Static::Simple/;

use Moose;
use CatalystX::RoleApplicator;

our $VERSION = '0.01';

__PACKAGE__->config(name => 'PomCur',
                    session => { flash_to_stash => 1 },
                    'Plugin::Session' => {
                      expires   => 3600,
                      dbi_dbh   => 'TrackModel',
                      dbi_table => 'sessions',
                      dbi_id_field => 'id',
                      dbi_data_field => 'session_data',
                      dbi_expires_field => 'expires',
                    },
                    'View::Graphics::Primitive' => {
                      driver => 'Cairo',
                      driver_args => { format => 'pdf' },
                      content_type => 'application/pdf',
                    },
                    static => {
                      dirs => [
                        'static'
                       ],
                    },
                   );



extends 'Catalyst';

__PACKAGE__->apply_request_class_roles(qw/
                                       Catalyst::TraitFor::Request::ProxyBase
                                       /);

sub debug
{
  return $ENV{POMCUR_DEBUG};
}

# Start the application
__PACKAGE__->setup();

my $config = __PACKAGE__->config();

# this is hacky, but allows us to call methods on the config object
bless $config, 'PomCur::Config';

use PomCur::Config;

$config->setup();

my %_model_map = ( manage => "TrackModel",
                   meta => "MetaModel" );

=head2 schema

 Usage   : my $schema = $c->schema();
 Function: Return the appropriate schema object, based on the model parameter
           of the request, or explicitly if a model_name is pass as an argument.
 Args    : $model_name - the name of model to return (optional)

=cut
sub schema
{
  my $self = shift;
  my $model_name = shift || $self->req()->param('model');

  die "no model passed to schema()\n" unless defined $model_name;

  my $model = $_model_map{$model_name};

  die "unknown model ($model_name) passed to schema()\n" unless defined $model;

  return $self->model($model)->schema();
}

1;
