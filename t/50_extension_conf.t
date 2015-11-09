use strict;
use warnings;
use Test::More tests => 2;

use Test::Deep;

use Canto::TestUtil;
use Canto::Config::ExtensionConf;

my $test_util = Canto::TestUtil->new();
my $config = $test_util->config();

my @conf = Canto::Config::ExtensionConf::parse($config->{test_config}->{test_extension_conf});

cmp_deeply($conf[0],
           {
             'domain' => 'GO:0016023',
             'subset_rel' => 'is_a',
             'range' => ['GeneID'],
             'display_text' => 'kinase substrate',
             'cardinality' => [0,1],
             'allowed_relation' => 'has_substrate',
             'role' => 'user',
           });

cmp_deeply($conf[1]->{cardinality}, ['*']);
