use strict;
use warnings;
use Test::More tests => 75;
use Test::Deep;

use Canto::TestUtil;
use Canto::Track;

use Clone qw(clone);

my $test_util = Canto::TestUtil->new();
$test_util->init_test();

my $config = $test_util->config();
my $lookup = Canto::Track::get_adaptor($config, 'ontology');

my $search_string = 'transporter';
my $transport_id = 'GO:0005215';
my $transport_name = 'transporter activity';

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
}

{
  my $results = $lookup->lookup(ontology_name => $ont_name,
                                search_string => $search_string,
                                max_results => 10,
                                include_definition => 1);

  ok(defined $results);

  is(scalar(@$results), 3);

  ok(grep { $_->{id} eq $transport_id &&
            $_->{name} eq $transport_name
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

  is($results->[0]->{matching_synonym}, 'protein tagging activity');
  is($results->[1]->{matching_synonym}, 'protein tagging activity');

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
is($id_result->[0]->{synonyms}, undef);


my $synonyms_result = $lookup->lookup(search_string => 'GO:0016023',
                                      include_definition => 1,
                                      include_synonyms => ['exact']);

my @synonyms = @{$synonyms_result->[0]->{synonyms}};

is(@synonyms, 2);

cmp_deeply(\@synonyms,
           [ { name => "cytoplasmic membrane bounded vesicle",
               type => 'exact' },
             { name => "cytoplasmic membrane-enclosed vesicle",
               type => 'exact' },
            ]);

# test synonyms again
$synonyms_result = $lookup->lookup(search_string => 'GO:0034763',
                                      include_definition => 1,
                                      include_synonyms => ['exact']);

@synonyms = @{$synonyms_result->[0]->{synonyms}};

is(@synonyms, 1);

cmp_deeply(\@synonyms,
           [ { name => "down regulation of transmembrane transport",
               type => 'exact' },
            ]);

# test getting two types of synonyms
$synonyms_result = $lookup->lookup(search_string => 'GO:0034763',
                                      include_definition => 1,
                                      include_synonyms => ['exact', 'narrow']);

@synonyms = @{$synonyms_result->[0]->{synonyms}};

is(@synonyms, 2);

cmp_deeply(\@synonyms,
           [ { name => "down regulation of transmembrane transport",
               type => "exact" },
             { name => "inhibition of transmembrane transport",
               type => "narrow",},
            ]);

# test synonyms again
$synonyms_result = $lookup->lookup(search_string => 'GO:0034763',
                                      include_definition => 1,
                                      include_synonyms => ['exact']);

@synonyms = @{$synonyms_result->[0]->{synonyms}};

is(@synonyms, 1);

cmp_deeply(\@synonyms,
           [ { name => "down regulation of transmembrane transport",
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

my $cache_key = "FYPO:0000114#@%1#@%0#@%#@%0";
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
  annotation_type_name => 'phenotype',
  definition => undef,
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
  annotation_type_name => 'phenotype',
  definition => undef,
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

$fypo_term = $lookup->lookup_by_id(id => 'FYPO:0000114',
                                   include_definition => 1,
                                   include_subset_ids => 1);

my $expected_term_with_subset_ids = clone $expected_fypo_term;

$expected_term_with_subset_ids->{subset_ids} = [];

# same result
cmp_deeply($fypo_term, $expected_term_with_subset_ids);

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


# test that we follow has_part
my $elongated_cell = 'elongated cell';
my $elongated_cell_results =
  $lookup->lookup_by_id(id => 'FYPO:0000017',
                        include_children => 1);

my $children = $elongated_cell_results->{children};

is (@$children, 1);
is ($children->[0]->{id}, 'FYPO:0000133');


# test querying a subset

my $index_path = $config->data_dir_path('ontology_index_dir');
my $ontology_index = Canto::Track::OntologyIndex->new(index_path => $index_path);
$test_util->load_test_ontologies($ontology_index, 1, 1, 1);

{
  my $results = $lookup->lookup(ontology_name => '[GO:0005215]',
                                search_string => 'activity',
                                max_results => 10);

  ok(defined $results);

  is(scalar(@$results), 3);

  cmp_deeply($results,
             [
               {
                 'id' => 'GO:0005215',
                 'annotation_type_name' => 'molecular_function',
                 'annotation_namespace' => 'molecular_function',
                 'name' => 'transporter activity',
                 'is_obsolete' => 0
               },
               {
                 'name' => 'transmembrane transporter activity',
                 'is_obsolete' => 0,
                 'id' => 'GO:0022857',
                 'annotation_type_name' => 'molecular_function',
                 'annotation_namespace' => 'molecular_function'
               },
               {
                 'name' => 'nucleocytoplasmic transporter activity',
                 'is_obsolete' => 0,
                 'id' => 'GO:0005487',
                 'annotation_namespace' => 'molecular_function',
                 'annotation_type_name' => 'molecular_function'
               }
             ]);
}


# test get_all()
my @all_pco_terms = $lookup->get_all(ontology_name => 'phenotype_condition');
is (@all_pco_terms, 10);

# test get_all() for a subset
my @all_subset_1_terms =
  sort {
    $a->{name} cmp $b->{name};
  } map {
    {
      name => $_->{name},
      id => $_->{id},
    }
  } $lookup->get_all(ontology_name => '[GO:0005215]');
is (@all_subset_1_terms, 3);


my $two_term_subset = '[GO:0005215|GO:0016023]';

# test get_all() for a subset defined by two IDs
my @all_subset_2_terms =
  sort {
    $a->{name} cmp $b->{name};
  } map {
    {
      name => $_->{name},
      id => $_->{id},
    }
  } $lookup->get_all(ontology_name => $two_term_subset);
is (@all_subset_2_terms, 6);

cmp_deeply(\@all_subset_2_terms,
           [
             {
               'name' => 'cytoplasmic membrane-bounded vesicle',
               'id' => 'GO:0016023'
             },
             {
               'id' => 'GO:0005487',
               'name' => 'nucleocytoplasmic transporter activity'
             },
             {
               'id' => 'GO:0030141',
               'name' => 'stored secretory granule'
             },
             {
               'id' => 'GO:0022857',
               'name' => 'transmembrane transporter activity'
             },
             {
               'id' => 'GO:0030133',
               'name' => 'transport vesicle'
             },
             {
               'name' => 'transporter activity',
               'id' => 'GO:0005215'
             }]);


my $subset_2_count =
  $lookup->get_count(ontology_name => $two_term_subset);

is($subset_2_count, scalar(@all_subset_2_terms));
