use strict;
use warnings;
use Test::More tests => 1;

use PomCur::TestUtil;

BEGIN {
  unshift @INC, 't';
  use_ok 'PomCur::Meta::Util';
}

use PomCur::Config;
use File::Path qw(make_path remove_tree);

my $config = PomCur::Config->new('pomcur.yaml');

my $deploy_dir = 't/scratch/tracking';

remove_tree $deploy_dir;

PomCur::Meta::Util::initialise_app($config, $deploy_dir, 'test');
