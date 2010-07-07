package PomCur;

use strict;
use warnings;

use Catalyst::Runtime 5.80;

use parent qw/Catalyst/;
use Catalyst qw/-Debug
                ConfigLoader
                StackTrace
                Authentication
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
                      content_type => 'application/pdf'
                   }
                   );

# Start the application
__PACKAGE__->setup();

my $config = __PACKAGE__->config();

# this is hacky, but allow us to call methods on the config object
bless $config, 'PomCur::Config';

use PomCur::Config;

$config->setup();

1;
