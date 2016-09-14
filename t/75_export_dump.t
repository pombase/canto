use strict;
use warnings;
use Test::More tests => 13;

use Clone qw(clone);
use JSON;
use Encode;

use Canto::Curs::State qw/:all/;

use Canto::TestUtil;
use Canto::TrackDB;
use Canto::Track::Serialise;
use Canto::Export::CantoJSON;

my $test_util = Canto::TestUtil->new();

$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $track_schema = Canto::TrackDB->new(config => $config);
my $curs_schema = Canto::Curs::get_schema_for_key($config, 'aaaa0007');

my $admin_person = $test_util->get_a_person($track_schema, 'admin');
my $user_person = $test_util->get_a_person($track_schema, 'user');

my $state = Canto::Curs::State->new(config => $config);

$state->set_state($curs_schema, APPROVAL_IN_PROGRESS,
                  { force => CURATION_IN_PROGRESS,
                    current_user => $admin_person });

sub _get_data
{
  my $prior_state = shift;
  my $options = shift;

  my $dump_export =
    Canto::Export::CantoJSON->new(config => $config, options => $options);

  if (defined $prior_state) {
    $dump_export->state()->set_state($curs_schema, $prior_state,
                                     { current_user => $admin_person,
                                       force => APPROVAL_IN_PROGRESS, });
  }

  my $json = $dump_export->export();
  return decode_json(encode("utf8", $json));
}

# dump all
{
  my @options = qw(--all);
  my $ref = _get_data(undef, \@options);

  my $aaaa0007 = $ref->{curation_sessions}->{aaaa0007};
  is ($aaaa0007->{metadata}->{annotation_status}, "APPROVAL_IN_PROGRESS");
  is ($aaaa0007->{metadata}->{canto_session}, "aaaa0007");
  is ($aaaa0007->{metadata}->{curator_name}, "Some Testperson");
  is ($aaaa0007->{metadata}->{curator_email}, 'some.testperson@pombase.org');

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
  my @options = qw(--all);
  my $ref = _get_data(undef, \@options);

  my $aaaa0007 = $ref->{curation_sessions}->{aaaa0007};
  is ($aaaa0007->{metadata}->{annotation_status}, "EXPORTED");

  is (keys (%{$ref->{curation_sessions}}), 2);
}

