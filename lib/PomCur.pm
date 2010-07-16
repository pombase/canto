package PomCur;

use strict;
use warnings;

use Catalyst::Runtime 5.80;

use parent qw/Catalyst/;
use Catalyst qw/-Debug
                ConfigLoader
                StackTrace
                Authentication
                Config::Multi
                Session
                Session::State::Cookie
                Session::Store::DBI
                Session::PerUser
                Static::Simple/;
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
                    'Plugin::Config::Multi' => {
                      dir => __PACKAGE__->path_to("./"),
                      app_name => 'pomcur',
                    },
                    static => {
                      dirs => [
                        'static'
                       ],
                    },
                   );

# Start the application
__PACKAGE__->setup();

my $config = __PACKAGE__->config();

# this is hacky, but allows us to call methods on the config object
bless $config, 'PomCur::Config';

use PomCur::Config;

$config->setup();

my %_model_map = ( manage => "TrackModel",
                   meta => "MetaModel" );

# shortcut to the schema
sub schema
{
  my $self = shift;
  my $model_name = shift || $self->req()->param('model');

  return $self->model($_model_map{$model_name})->schema();
}

1;
