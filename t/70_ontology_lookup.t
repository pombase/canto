use strict;
use warnings;
use Test::More tests => 62;
use Test::Deep;

use Canto::TestUtil;

use Canto::Track;

my $test_util = Canto::TestUtil->new();
$test_util->init_test();

my $config = $test_util->config();
my $lookup = Canto::Track::get_adaptor($config, 'ontology');

my $search_string = 'transporter';
my $transport_id = 'GO:0005215';
my $transport_name = 'transporter activity';
my $transport_definition = 'Enables the directed movement of substances (such as macromolecules, small molecules, ions) into, out of or within a cell, or between cells.';

my $ont_name = 'molecular_function';

{
  my $results = $lookup->lookup(ontology_name => $ont_name,
                                search_string => "$search_string][)(-",
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
  my $results = $lookup->lookup(ontology_name => $ont_name,
                                search_string => $ont_name,
                                max_results => 10,
                                include_definition => 1);

  ok(defined $results);

  is(scalar(@$results), 1);

  is($results->[0]->{name}, $ont_name);
  is($results->[0]->{id}, 'GO:0003674');
  like($results->[0]->{definition}, qr/Elemental activities/);
}

{
  my $results = $lookup->lookup(ontology_name => $ont_name,
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

# lookup a broad synonym
{
  my $results = $lookup->lookup(ontology_name => 'molecular_function',
                                search_string => 'tagging',
                                max_results => 10,
                                include_definition => 1);

  ok(defined $results);

  is(scalar(@$results), 2);

  ok(grep {
    $_->{id} eq 'GO:0031386' && $_->{name} eq 'protein tag'
  } @$results);

  ok(grep {
    $_->{id} eq 'GO:0005515' && $_->{name} eq 'protein binding'
  } @$results);
}

my $id_result = $lookup->lookup(search_string => 'GO:0006810',
                                include_definition => 1);

is(scalar(@$id_result), 1);

is($id_result->[0]->{id}, 'GO:0006810');
is($id_result->[0]->{name}, 'transport');
is($id_result->[0]->{annotation_namespace}, 'biological_process');
like($id_result->[0]->{definition}, qr/^The directed movement of substances/);
is($id_result->[0]->{exact_synonyms}, undef);


# test getting exact synonyms
my $exact_synonyms_result = $lookup->lookup(search_string => 'GO:0016023',
                                            include_definition => 1,
                                            include_exact_synonyms => 1);

my @synonyms = @{$exact_synonyms_result->[0]->{synonyms}};

is(@synonyms, 2);

cmp_deeply(\@synonyms,
           [ { name => "cytoplasmic membrane bounded vesicle",
               type => 'exact' },
             { name => "cytoplasmic membrane-enclosed vesicle",
               type => 'exact' },
            ]);

# try looking up an ID from the wrong ontology
$id_result = $lookup->lookup(ontology_name => 'biological_process',
                             search_string => 'GO:0030133',
                             max_results => 10,
                             include_definition => 1);

is(scalar(@$id_result), 1);

is($id_result->[0]->{id}, 'GO:0030133');
is($id_result->[0]->{name}, 'transport vesicle');
is($id_result->[0]->{annotation_namespace}, 'cellular_component');
like($id_result->[0]->{definition}, qr/^Any of the vesicles of the constitutive/);

my $child_results =
  $lookup->lookup(ontology_name => $ont_name,
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


ok(grep { $_->{id} eq 'GO:0005487' &&
          $_->{name} eq 'nucleocytoplasmic transporter activity' ||
          $_->{id} eq 'GO:0022857' &&
          $_->{name} eq 'transmembrane transporter activity' } @children);

my $cache_key = "FYPO:0000114#@%1#@%0#@%0";
my $cached_value = $lookup->cache()->get($cache_key);
ok(!defined $cached_value);

# try a phenotype name
$id_result = $lookup->lookup(ontology_name => 'phenotype',
                             search_string => 'FYPO:0000114',
                             max_results => 10,
                             include_definition => 1);

is(scalar(@$id_result), 1);

my $expected_fypo_term = {
  id => 'FYPO:0000114',
  name => 'cellular process phenotype',
  annotation_namespace => 'fission_yeast_phenotype',
  definition => 'A phenotype that affects a cellular process.',
  is_obsolete => 0,
};

is($id_result->[0]->{id}, 'FYPO:0000114');
is($id_result->[0]->{name}, 'cellular process phenotype');
is($id_result->[0]->{annotation_namespace}, 'fission_yeast_phenotype');

cmp_deeply($id_result->[0], $expected_fypo_term);

# check that value was cached
$cached_value = $lookup->cache()->get($cache_key);
ok(defined $cached_value);
is($cached_value->{name}, 'cellular process phenotype');


my $fypo_cpp = $lookup->lookup_by_name(ontology_name => 'fission_yeast_phenotype',
                                       term_name => 'cellular process phenotype',
                                       include_definition => 1);
is ($fypo_cpp->{id}, 'FYPO:0000114');
is ($fypo_cpp->{name}, 'cellular process phenotype');

cmp_deeply($fypo_cpp, $expected_fypo_term);


my $expected_fypo_obsolete_term = {
  id => 'FYPO:0002233',
  name => 'viable elongated vegetative cell population',
  annotation_namespace => 'fission_yeast_phenotype',
  definition => 'A cell population phenotype in which all cells in the population are viable but longer than normal in the vegetative growth phase of the life cycle.',
  is_obsolete => 1,
  comment => 'This term was made obsolete because it is redundant with annotating to the equivalent cell phenotype plus a full-penetrance extension.',
};


my $fypo_obsolete = $lookup->lookup_by_id(id => 'FYPO:0002233',
                                          include_definition => 1);
cmp_deeply($fypo_obsolete, $expected_fypo_obsolete_term);

is ($fypo_cpp->{id}, 'FYPO:0000114');
is ($fypo_cpp->{name}, 'cellular process phenotype');

cmp_deeply($fypo_cpp, $expected_fypo_term);


my $fypo_fail = $lookup->lookup_by_name(ontology_name => 'fission_yeast_phenotype',
                                        term_name => 'unknown name');
ok (!defined $fypo_fail);


$lookup->cache()->remove($cache_key);

$cached_value = $lookup->cache()->get($cache_key);
ok(!defined $cached_value);

my $fypo_term = $lookup->lookup_by_id(id => 'FYPO:0000114',
                                      include_definition => 1);
cmp_deeply($fypo_term, $expected_fypo_term);

# check that value was cached
$cached_value = $lookup->cache()->get($cache_key);
ok(defined $cached_value);
is($cached_value->{name}, 'cellular process phenotype');

# check again to make sure that we are getting the cached value
$lookup->cache()->set($cache_key, { name => 'aardvark' });
$fypo_term = $lookup->lookup_by_id(id => 'FYPO:0000114',
                                   include_definition => 1);
$cached_value = $lookup->cache()->get($cache_key);
ok(defined $cached_value);
is($cached_value->{name}, 'aardvark');

# try looking up an alt_id
$fypo_term = $lookup->lookup_by_id(id => 'FYPO:0000028',
                                   include_definition => 1);
cmp_deeply($fypo_term, $expected_fypo_term);


# test get_all()
my @all_pco_terms = $lookup->get_all(ontology_name => 'phenotype_condition');
is (@all_pco_terms, 10);


# test that we follow has_part
my $elongated_cell = 'elongated cell';
my $elongated_cell_results =
  $lookup->lookup_by_id(id => 'FYPO:0000017',
                        include_children => 1);

my $children = $elongated_cell_results->{children};

is (@$children, 1);
is ($children->[0]->{id}, 'FYPO:0000133');
