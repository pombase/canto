use strict;
use warnings;
use Test::More tests => 86;
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
my $transport_definition = 'Enables the directed movement of substances (such as macromolecules, small molecules, ions) into, out of or within a cell, or between cells.';

my $ont_name = 'molecular_function';

my $parse_search_scope_simple_res =
  Canto::Track::OntologyLookup::_parse_search_scope("molecular_function");
is ($parse_search_scope_simple_res, "molecular_function");

my $parse_search_scope_two_res =
  Canto::Track::OntologyLookup::_parse_search_scope("[GO:0055085|GO:0034762]");
cmp_deeply($parse_search_scope_two_res, ['is_a(GO:0055085)', 'is_a(GO:0034762)']);

my $parse_search_scope_subset_res =
  Canto::Track::OntologyLookup::_parse_search_scope("[GO:0055085-GO:0034762]");
cmp_deeply($parse_search_scope_subset_res, [{ include => 'is_a(GO:0055085)',
                                              exclude => 'is_a(GO:0034762)' }]);

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
  my $results = $lookup->lookup(ontology_name => "biological_process",
                                search_string => "transport",
                                max_results => 10);

  ok(defined $results);

  is(scalar(@$results), 7);
}

{
  my $results = $lookup->lookup(ontology_name => $ont_name,
                                search_string => $ont_name,
                                max_results => 10,
                                include_definition => 1);

  ok(defined $results);

  is(scalar(@$results), 1);
}

my $config_subsets_to_ignore =
  $config->{ontology_namespace_config}{subsets_to_ignore};

my @primary_exclude_subsets = @{$config_subsets_to_ignore->{primary_autocomplete}};
my @extension_exclude_subsets = @{$config_subsets_to_ignore->{extension}};


{
  my $results = $lookup->lookup(ontology_name => $ont_name,
                                search_string => $ont_name,
                                max_results => 10,
                                include_definition => 1,
                                exclude_subsets => \@primary_exclude_subsets);

  ok(defined $results);

  # root terms shouldn't be returned because of the subsets_to_ignore
  is(scalar(@$results), 1);
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
like($id_result->[0]->{definition}, qr/^The directed movement of substances/);
is($id_result->[0]->{synonyms}, undef);


my $synonyms_result = $lookup->lookup(search_string => 'GO:0016023',
                                      include_definition => 1,
                                      include_synonyms => ['exact']);

my @synonyms = @{$synonyms_result->[0]->{synonyms}};

is(@synonyms, 2);

cmp_deeply([sort { $a->{name} cmp $b->{name} } @synonyms],
           [
             { name => "cytoplasmic membrane bounded vesicle",
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
  name => 'OBSOLETE FYPO:0002233 viable elongated vegetative cell population',
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


# non-existent ID
$fypo_term = $lookup->lookup_by_id(id => 'FYPO:99999999');
ok(!defined($fypo_term));


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
my $ontology_index = Canto::Track::OntologyIndex->new(config => $config, index_path => $index_path);
$test_util->load_test_ontologies($ontology_index, 1, 1, 1);

{
  my $results = $lookup->lookup(ontology_name => '[GO:0005215]',
                                search_string => 'activity',
                                max_results => 10);

  ok(defined $results);

  @$results = sort {
    $a->{id} cmp $b->{id};
  } @$results;

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
                 'name' => 'nucleocytoplasmic transporter activity',
                 'is_obsolete' => 0,
                 'id' => 'GO:0005487',
                 'annotation_namespace' => 'molecular_function',
                 'annotation_type_name' => 'molecular_function'
               },
               {
                 'name' => 'transmembrane transporter activity',
                 'is_obsolete' => 0,
                 'id' => 'GO:0022857',
                 'annotation_type_name' => 'molecular_function',
                 'annotation_namespace' => 'molecular_function'
               },
             ]);
}


# test get_all()
my @all_pco_terms = $lookup->get_all(ontology_name => 'phenotype_condition',
                                     exclude_subsets => \@primary_exclude_subsets);
is (@all_pco_terms, 6);

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
  } $lookup->get_all(ontology_name => $two_term_subset,
                     exclude_subsets => \@primary_exclude_subsets);
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
               'name' => 'stored secretory granule',
               'id' => 'GO:0030141'
             },
             {
               'name' => 'transmembrane transporter activity',
               'id' => 'GO:0022857'
             },
             {
               'name' => 'transport vesicle',
               'id' => 'GO:0030133'
             },
             {
               'id' => 'GO:0005215',
               'name' => 'transporter activity'
             }
           ]);


my $subset_2_count =
  $lookup->get_count(ontology_name => $two_term_subset,
                     exclude_subsets => \@primary_exclude_subsets);

is($subset_2_count, scalar(@all_subset_2_terms));


# test excluding a sub-ontology

my $exclude_test_query = '[GO:0006810-GO:0055085]';

# test get_all() for a subset defined by two IDs
my @all_exclude_test_terms =
  sort {
    $a->{name} cmp $b->{name};
  } map {
    {
      name => $_->{name},
      id => $_->{id},
    }
  } $lookup->get_all(ontology_name => $exclude_test_query);
is (@all_exclude_test_terms, 1);

cmp_deeply(\@all_exclude_test_terms,
           [
             {
               'id' => 'GO:0006810',
               'name' => 'transport'
             }
           ]);


my $exclude_test_count =
  $lookup->get_count(ontology_name => $exclude_test_query);

is($exclude_test_count, scalar(@all_exclude_test_terms));
