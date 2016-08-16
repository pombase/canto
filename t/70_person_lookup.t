use strict;
use warnings;
use Test::More tests => 13;

use Canto::Track::PersonLookup;
use Canto::TestUtil;

my $test_util = Canto::TestUtil->new();
$test_util->init_test();

my $lookup = Canto::Track::PersonLookup->new(config => $test_util->config());

ok(defined $lookup->schema());

my @test_user_details_by_name = $lookup->lookup('name', 'Test User');

is(scalar(@test_user_details_by_name), 1);
my %user_details_hash = %{$test_user_details_by_name[0]};
is($user_details_hash{email}, 'test.user@pombase.org');
ok($user_details_hash{id} =~ /^\d+$/ && $user_details_hash{id} > 0);
is(keys(%user_details_hash), 4);

my $test_user_details_by_email = $lookup->lookup('email', 'test.user@pombase.org');

is($test_user_details_by_email->{name}, 'Test User');
is($test_user_details_by_email->{email}, 'test.user@pombase.org');

my $schema = $lookup->schema();

my $other_test_user =
  $schema->resultset('Person')->find({ email_address => 'other.tester@pombase.org' });


$other_test_user->name('Test Other');
$other_test_user->update();

my @test_user_details_by_name_wildcard = $lookup->lookup('name', 'Test*');

is(scalar(@test_user_details_by_name_wildcard), 2);
is($test_user_details_by_name_wildcard[0]->{email}, 'other.tester@pombase.org');
is($test_user_details_by_name_wildcard[1]->{email}, 'test.user@pombase.org');


$other_test_user->name('Test User');
$other_test_user->update();

my @test_user_details_by_name_2 = $lookup->lookup('name', 'Test User');

is(scalar(@test_user_details_by_name_2), 2);
is($test_user_details_by_name_2[0]->{email}, 'other.tester@pombase.org');
is($test_user_details_by_name_2[1]->{email}, 'test.user@pombase.org');
