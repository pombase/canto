use strict;
use warnings;
use Test::More tests => 10;

use Plack::Test;

use Canto::TestUtil;
use Canto::Controller::Curs;
use Canto::Curs::GenotypeManager;

use JSON;

my $test_util = Canto::TestUtil->new();
my $config = $test_util->config();

$test_util->init_test('curs_annotations_2');

my $app = $test_util->plack_app()->{app};

my $track_schema = $test_util->track_schema();

my $curs_key = 'aaaa0007';
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $organism = $curs_schema->resultset('Organism')->first();

my $c12c2_gene =
  $curs_schema->resultset('Gene')->create({
    primary_identifier => 'SPBC12C2.02c',
    organism => $organism->organism_id(),
  });

my $root_url = "http://localhost:5000/curs/$curs_key";

test_psgi $app, sub {
  my $cb = shift;

  my $uri = new URI("$root_url/feature/genotype/store");

  my $test_create_1_proc =
    sub {
      my $genotype_name = shift;
      my $genotype_identifier = shift;
      my $status = shift;

      my $req = HTTP::Request->new(POST => $uri);
      $req->header('Content-Type' => 'application/json');

      my $params = {
        genotype_name => $genotype_name,
        genotype_background => 'h+',
        genotype_identifier => $genotype_identifier,
        taxonid => 4896,
        alleles =>
          [
            {
              # previously stored allele
              primary_identifier => "SPAC27D7.13c:aaaa0007-1",
              name => "ssm4delta",
              description => "",
              type => "deletion",
              expression => "",
              gene_id => 2
            },
            {
              # new allele
              name => "ssm4-h1",
              description => "K10G",
              type => "amino acid substitution(s)",
              expression => "knockdown",
              gene_id => 2,
            },
            {
              # allele from Chado
              external_uniquename => 'SPBC12C2.02c:allele-3',
              gene_id => $c12c2_gene->gene_id(),
           },
          ]
        };

      $req->content(to_json($params));

      my $res = $cb->($req);
      my $perl_res = decode_json $res->content();

      is($perl_res->{status}, $status);
    };

  my $genotype_manager = Canto::Curs::GenotypeManager->new(config => $config,
                                                           curs_schema => $curs_schema);
  $genotype_manager->_remove_unused_alleles();

  my $start_allele_count = $curs_schema->resultset('Allele')->count();

  $test_create_1_proc->("h+ abc-1", "h+ ssm4delta(deletion)", "success");
  # create new allele in the CursDB and allele from Chado
  is ($curs_schema->resultset('Allele')->count(), $start_allele_count + 2);

  $test_create_1_proc->("h+ abc-1 g-2", "h+ ssm4delta(deletion) g-2", "existing");
  # duplicate, so nothing new is stored
  is($curs_schema->resultset('Allele')->count(), $start_allele_count + 2);

  my $_create_test_genotype = sub
  {
    my $status = shift;
    my @alleles = @_;

    my $req = HTTP::Request->new(POST => $uri);
    $req->header('Content-Type' => 'application/json');

    my $params = {
      genotype_name => "h+ xyz-aa-1",
      genotype_background => 'h+',
      genotype_identifier => "h+ test-3",
      taxonid => 4896,
      alleles =>
        [
          @alleles,
        ]
      };

    $req->content(to_json($params));

    my $res = $cb->($req);
    my $perl_res = decode_json $res->content();

    is($perl_res->{status}, $status);
  };

  $_create_test_genotype->("existing",
    map {
      { primary_identifier => $_->primary_identifier() }
    } $curs_schema->resultset('Genotype')
      ->first()->alleles()->all());

  my $new_genotype =
    $curs_schema->resultset('Genotype')
      ->find({ name => 'h+ xyz-aa-1' });

  # genotype not created because it's a duplicate
  ok(!defined $new_genotype);

  # add an extra allele and try again
  $_create_test_genotype->("success",
    (map {
      { primary_identifier => $_->primary_identifier() }
    } $curs_schema->resultset('Genotype')
      ->first()->alleles()->all()),
    { external_uniquename => 'SPAC27D7.13c:allele-2' });

  $new_genotype =
    $curs_schema->resultset('Genotype')
      ->find({ name => 'h+ xyz-aa-1' });

  is ($new_genotype->alleles()->count(), 3);

  is ($new_genotype->identifier(), "aaaa0007-genotype-4");

  is ($curs_schema->resultset('Allele')->count(), $start_allele_count + 3);
};

1;
