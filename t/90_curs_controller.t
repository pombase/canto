use strict;
use warnings;
use Test::More tests => 2;

use PomCur::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test('1_curs');

my $track_schema = $test_util->track_schema();

my @curs_objects = $track_schema->resultset('Curs')->all();

is(@curs_objects, 1);

my $curs_key = $curs_objects[0]->curs_key();

my $app = $test_util->plack_app();

my @known_genes = qw(SPCC1739.10 wtf22 SPNCRNA.119);
my @unknown_genes = qw(dummy SPCC999999.99);

test_psgi $app, sub {
  my $cb = shift;

  my $curs_schema =
    PomCur::Curs::get_schema_for_key($test_util->config(), $curs_key);

  my $curs_metadata_rs = $curs_schema->resultset('Metadata');

  my $first_contact = undef;

  while (defined (my $metadata = $curs_metadata_rs->next())) {
    if ($metadata->key() eq 'first_contact') {
      $first_contact = $metadata->value();
    }
  }

  is($first_contact, 'dom@genetics.med.harvard.edu');
};

done_testing;
