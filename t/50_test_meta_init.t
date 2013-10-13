use strict;
use warnings;
use Test::More tests => 1;

use Canto::TestUtil;
use Canto::Meta::Util;
use Canto::Config;

use File::Path qw(remove_tree);

my $config = Canto::Config->new();

my $deploy_dir = 't/scratch';

remove_tree ($deploy_dir, { error => \my $rm_err } );

if (@$rm_err) {
  for my $diag (@$rm_err) {
    my ($file, $message) = %$diag;
    warn "error: $message\n";
  }
  exit (1);
}

Canto::Meta::Util::initialise_app($config, $deploy_dir, 'test');

ok(-f "$deploy_dir/track.sqlite3");
