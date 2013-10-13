use strict;
use warnings;
use Test::More tests => 10;

use Clone qw(clone);
use JSON;

use PomCur::Curs::State qw/:all/;

use PomCur::TestUtil;
use PomCur::TrackDB;
use PomCur::Track::Serialise;
use PomCur::Export::CantoJSON;

my $test_util = PomCur::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = PomCur::TrackDB->new(config => $config);
my $curs_schema = PomCur::Curs::get_schema_for_key($config, 'aaaa0007');

my $admin_person = $test_util->get_a_person($track_schema, 'admin');
my $user_person = $test_util->get_a_person($track_schema, 'user');

my $state = PomCur::Curs::State->new(config => $config);

$state->set_state($curs_schema, APPROVAL_IN_PROGRESS,
                  { force => CURATION_IN_PROGRESS,
                    current_user => $admin_person });

sub _get_data
{
  my $prior_state = shift;
  my $options = shift;

  my $dump_export =
    PomCur::Export::CantoJSON->new(config => $config, options => $options);

  if (defined $prior_state) {
    $dump_export->state()->set_state($curs_schema, $prior_state,
                                     { current_user => $admin_person,
                                       force => APPROVAL_IN_PROGRESS, });
  }

  my $json = $dump_export->export();
  return decode_json($json);
}

# dump all
{
  my @options = qw(--all-data);
  my $ref = _get_data(undef, \@options);

  my $aaaa0007 = $ref->{curation_sessions}->{aaaa0007};
  is ($aaaa0007->{metadata}->{annotation_status}, "APPROVAL_IN_PROGRESS");

  is (keys (%{$ref->{curation_sessions}}), 2);
}

# no approved sessions yet
{
  my @options = qw(--dump-approved);
  my $ref = _get_data(undef, \@options);

  is (keys (%{$ref->{curation_sessions}}), 0);
}

# approve a session
{
  my @options = qw(--dump-approved);
  my $ref = _get_data(APPROVED, \@options);

  is (keys (%{$ref->{curation_sessions}}), 1);

  my $aaaa0007 = $ref->{curation_sessions}->{aaaa0007};
  is ($aaaa0007->{metadata}->{annotation_status}, "APPROVED");
}

# export the sessions
{
  my @options = qw(--export-approved);
  my $ref = _get_data(undef, \@options);

  is (keys (%{$ref->{curation_sessions}}), 1);

  my $aaaa0007 = $ref->{curation_sessions}->{aaaa0007};
  # an anomaly - we return the status before exporting:
  is ($aaaa0007->{metadata}->{annotation_status}, "APPROVED");
}

# the previous call should have changed the session state to "EXPORTED", so
# we won't get any sessions this time
{
  my @options = qw(--export-approved);
  my $ref = _get_data(undef, \@options);

  is (keys (%{$ref->{curation_sessions}}), 0);
}

# but dump all should still return them all
{
  my @options = qw(--all-data);
  my $ref = _get_data(undef, \@options);

  my $aaaa0007 = $ref->{curation_sessions}->{aaaa0007};
  is ($aaaa0007->{metadata}->{annotation_status}, "EXPORTED");

  is (keys (%{$ref->{curation_sessions}}), 2);
}

