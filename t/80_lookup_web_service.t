use strict;
use warnings;
use Test::More tests => 18;

use PomCur::TestUtil;

use PomCur::Track;

my $test_util = PomCur::TestUtil->new();
$test_util->init_test();

my $config = $test_util->config();
my $lookup = PomCur::Track::get_adaptor($config, 'go');

my $test_string = 'GO:00040';

my $search_string = 'transporter';
my $transport_id = 'GO:0005215';
my $transport_name = 'transporter activity';
my $transport_definition = 'Enables the directed movement of substances (such as macromolecules, small molecules, ions) into, out of or within a cell, or between cells.';

my $ont_name = 'molecular_function';

{
  my $results = $lookup->web_service_lookup(ontology_name => $ont_name,
                                            search_string => $search_string,
                                            max_results => 10,
                                            include_definition => 0);

  ok(defined $results);

  is(scalar(@$results), 3);

  ok(grep { $_->{id} eq $transport_id &&
            $_->{name} eq $transport_name &&
            !defined $_->{definition}
          } @$results);

  is(scalar(map { $_->{name} =~ /^$search_string/ } @$results), 1);
}

{
  my $results = $lookup->web_service_lookup(ontology_name => $ont_name,
                                            search_string => $search_string,
                                            max_results => 10,
                                            include_definition => 1);

  ok(defined $results);

  is(scalar(@$results), 3);

  ok(grep { $_->{id} eq $transport_id &&
            $_->{name} eq $transport_name &&
            $_->{definition} eq $transport_definition
          } @$results);

  is(scalar(map { $_->{name} =~ /^$search_string/ } @$results), 1);
}

my $id_result = $lookup->web_service_lookup(ontology_name => 'biological_process',
                                            search_string => 'GO:0006810',
                                            max_results => 10,
                                            include_definition => 1);

is(scalar(@$id_result), 1);

is($id_result->[0]->{id}, 'GO:0006810');
is($id_result->[0]->{name}, 'transport');
like($id_result->[0]->{definition}, qr/^The directed movement of substances/);

my $child_results =
  $lookup->web_service_lookup(ontology_name => $ont_name,
                              include_children => 1,
                              search_string => $transport_id,
                              max_results => 10);

is(@$child_results, 1);

my $child_res = $child_results->[0];

is($child_res->{id}, $transport_id);
is($child_res->{name}, $transport_name);
ok(!defined $child_res->{definition});

my @children = @{$child_res->{children}};

is(@children, 2);
        use Data::Dumper;

ok(grep { $_->{id} eq 'GO:0005487' &&
          $_->{name} eq 'nucleocytoplasmic transporter activity' ||
          $_->{id} eq 'GO:0022857' &&
          $_->{name} eq 'transmembrane transporter activity' } @children);
