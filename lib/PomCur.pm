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
                Session::Store::FastMmap
                Session::State::Cookie
                Static::Simple/;
our $VERSION = '0.01';

__PACKAGE__->config(name => 'PomCur',
                    session => { flash_to_stash => 1 },
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

# shortcut to the schema
sub schema
{
  my $self = shift;
  return $self->model($self->model_name())->schema();
}

sub model_name {
  my $self = shift;
  return "TrackModel";
}

1;
