use strict;
use warnings;
use Test::More tests => 15;
use Test::Exception;
use File::Temp qw(tempfile);
use Data::Compare;
use File::Copy qw(copy);

use PomCur::TestUtil;
use PomCur::DBUtil;
use PomCur::Track::LoadUtil;

{
  my $config = {};
  my $file_name = '/tmp/test_file.sqlite3';
  my $schema = PomCur::DBUtil::schema_for_file($config, $file_name, 'Curs');

  my $storage = $schema->storage();

  is ($storage->connect_info()->[0], "dbi:SQLite:dbname=$file_name");
}

{
  my $test_util = PomCur::TestUtil->new();

  ok(ref $test_util);

  throws_ok { $test_util->init_test('_no_such_config_') } qr(no test case);

}

{
  my $test_util = PomCur::TestUtil->new();

  ok(ref $test_util);

  $test_util->init_test('empty_db');

  is($test_util->track_schema()->resultset('Pub')->count(), 0);
  is($test_util->track_schema()->resultset('Gene')->count(), 0);
}

{
  my $test_util = PomCur::TestUtil->new();

  ok(ref $test_util);

  $test_util->init_test('1_curs');

  is($test_util->track_schema()->resultset('Pub')->count(), 21);
  is($test_util->track_schema()->resultset('Gene')->count(), 15);
}

{
  # test _process_data()

  my $config = PomCur::Config::get_config();
  $config->merge_config($config->{test_config_file});

  my $annotations_conf =
    $config->{test_config}->{test_cases}->
        {curs_annotations_1}->[0]->{annotations}->[0];

  my ($fh, $temp_db) = tempfile();

  package MockObject;

  sub new {
    my $class = shift;
    my $table = shift;
    my $id = shift;

    return bless { table => $table, id => $id }, 'MockObject';
  }

  sub table {
    my $self = shift;
    return $self->{table}
  }

  sub gene_id {
    my $self = shift;
    return $self->{id}
  }

  sub pub_id {
    my $self = shift;
    return $self->{id}
  }

  sub primary_columns {
    my $self = shift;
    return $self->{table} . '_id';
  }

  package main;

  package MockCursDB;

  sub find_with_type {
    my $self = shift;
    my $class_name = shift;
    my $hash = shift;

    my $field_name = (keys %$hash)[0];
    my $field_value = $hash->{$field_name};

    my %res = (
      'Gene' => {
        primary_identifier => {
          'SPCC1739.10' => 200
        }
      },
      'Pub' => {
        uniquename => {
          'PMID:18426916' => 300
        }
      }
    );

    my $obj_id = $res{$class_name}->{$field_name}->{$field_value};
    my $table = PomCur::DB::table_name_of_class($class_name);

    return MockObject->new($table, $obj_id);
  }

  package main;

  my $test_curs_db = bless {}, 'MockCursDB';

  my $results =
    PomCur::TestUtil::_process_data($test_curs_db, $annotations_conf);

  is (@{$results->{genes}}, 1);
  is ($results->{genes}->[0]->gene_id(), 200);
  is ($results->{pub}, 300);
}

sub track_init
{
  my $track_schema = shift;
  my $load_util = shift;

  $track_schema->create_with_type('Person',
                                  {
                                    email_address => 'kevin.hardwick@ed.ac.uk',
                                    name => 'Kevin Hardwick',
                                    role => 'user'
                                  });
  $track_schema->create_with_type('Cv',
                                  {
                                    cv_id => 50,
                                    name => 'Test CV'
                                  });
  my $db = $track_schema->create_with_type('Db',
                                           {
                                             name => 'Test DB'
                                           });
  my $dbxref = $track_schema->create_with_type('Dbxref',
                                               {
                                                 accession => 'Test accession',
                                                 db => $db
                                               });
  $track_schema->create_with_type('Cvterm',
                                  {
                                    cvterm_id => 601,
                                    cv_id => 50,
                                    name => 'Test pub type',
                                    dbxref => $dbxref
                                  });
  $track_schema->create_with_type('Cvterm',
                                  {
                                    cvterm_id => 602,
                                    cv_id => 50,
                                    name => 'Test pub status',
                                    dbxref => $dbxref
                                  });
  $track_schema->create_with_type('Pub',
                                  {
                                    uniquename => 'PMID:18426916',
                                    title => 'test title',
                                    type_id => 601,
                                    triage_status_id => 602,
                                  });
  my $organism = $load_util->get_organism('Schizosaccharomyces', 'pombe', 4896);

  $track_schema->create_with_type('Gene',
                                  {
                                    primary_identifier => 'SPCC1739.11c',
                                    product =>
                                      'SIN component scaffold protein, centriolin ortholog Cdc11',
                                    primary_name => 'cdc11',
                                    organism => $organism->organism_id()
                                  });
  $track_schema->create_with_type('Gene',
                                  {
                                    primary_identifier => 'SPCC1739.10',
                                    product => 'conserved fungal protein',
                                    organism => $organism->organism_id()
                                  });
  $track_schema->create_with_type('Gene',
                                  {
                                    primary_identifier => 'SPAC3A11.14c',
                                    primary_name => 'pkl1',
                                    product => 'kinesin-like protein Pkl1',
                                    genesynonyms => [
                                      {
                                        identifier => 'klp1'
                                      },
                                      {
                                        identifier => 'SPAC3H5.03c'
                                      }
                                    ],
                                    organism => $organism->organism_id()
                                  });
}

{
  # test make_curs_db

  my $config = PomCur::Config::get_config();
  $config->merge_config($config->{test_config_file});

  my $curs_config =
    $config->{test_config}->{test_cases}->{curs_annotations_1}->[0];

  my $track_db_template_file = $config->{track_db_template_file};

  my ($fh, $temp_track_db) = tempfile();

  copy $track_db_template_file, $temp_track_db or die "$!\n";

  my $track_schema =
    PomCur::DBUtil::schema_for_file($config, $temp_track_db, 'Track');

  my $load_util = PomCur::Track::LoadUtil->new(schema => $track_schema);

  track_init($track_schema, $load_util);

  my ($cursdb_schema, $cursdb_file_name) =
    PomCur::TestUtil::make_curs_db($config, $curs_config,
                                   $track_schema, $load_util);

  my @res_annotations = $cursdb_schema->resultset('Annotation')->all();

  is (@res_annotations, 2);

  my $res_annotation = $res_annotations[0];

  my $annotation_conf = $curs_config->{annotations}->[0];

  is ($res_annotation->pub()->uniquename(), $annotation_conf->{'pub(Pub:uniquename)'});

  my $gene_identifier = $annotation_conf->{'genes(Gene:primary_identifier)'};
  my $gene = $cursdb_schema->find_with_type('Gene',
                                            {
                                              primary_identifier => $gene_identifier,
                                            });

  is ($res_annotation->genes()->first()->gene_id(), $gene->gene_id());
}
