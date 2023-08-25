use strict;
use warnings;
use Test::More tests => 8;
use Test::Deep;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

use Canto::TestUtil;

use JSON;

my $test_util = Canto::TestUtil->new();
$test_util->init_test('curs_annotations_2');

my $config = $test_util->config();
my $app = $test_util->plack_app()->{app};

my $curs_key = 'aaaa0007';
my $curs_schema = Canto::Curs::get_schema_for_key($config, $curs_key);

my $root_url = "http://localhost:5000/curs/$curs_key";

my $first_genotype =
 $curs_schema->resultset('Genotype')->find({ identifier => 'aaaa0007-genotype-test-1' });

my $first_genotype_annotation = $first_genotype->annotations()->first();

my $first_genotype_annotation_id = $first_genotype_annotation->annotation_id();
my $first_genotype_id = $first_genotype->genotype_id();

test_psgi $app, sub {
  my $cb = shift;

  my $uri = new URI("$root_url/ws/annotation/$first_genotype_annotation_id/new/change");

  my $req = HTTP::Request->new(POST => $uri);
  $req->header('Content-Type' => 'application/json');
  my $new_comment = "new service comment";
  my $changes = {
    key => $curs_key,
    submitter_comment => $new_comment,
  };

  ok(!defined($first_genotype_annotation->data()->{submitter_comment}));

  $req->content(to_json($changes));

  my $res = $cb->($req);

  my $perl_res = decode_json $res->content();

  is($perl_res->{status}, 'success');

  # re-query
  $first_genotype_annotation = $first_genotype->annotations()->first();

  is ($first_genotype_annotation->data()->{submitter_comment}, "$new_comment");
};

test_psgi $app, sub {
  my $cb = shift;

  # retrieve a single genotype
  my $uri = new URI("$root_url/ws/genotype/details/by_id/$first_genotype_id");

  my $req = HTTP::Request->new(GET => $uri);

  my $res = $cb->($req);

  my $perl_res = decode_json $res->content();

  cmp_deeply($perl_res,
             {
               'allele_string' => 'SPCC63.05delta ssm4delta',
               'genotype_id' => 1,
               'locus_count' => 2,
               'diploid_locus_count' => 0,
               'metagenotype_count_by_type' => {
                 interaction => 1,
               },
               strain_name => undef,
               'alleles' => [
                 {
                   'type' => 'deletion',
                   'name' => 'ssm4delta',
                   'allele_id' => 1,
                   'description' => 'deletion',
                   'gene_id' => 2,
                   'display_name' => 'ssm4delta',
                   'long_display_name' => 'ssm4delta',
                   'expression' => undef,
                   'primary_identifier' => 'SPAC27D7.13c:aaaa0007-1',
                   'gene_display_name' => 'ssm4',
                   'gene_systematic_id' => 'SPAC27D7.13c',
                   'comment' => undef,
                   'synonyms' => [],
                   'notes' => {},
                   'promoter_gene' => undef,
                },
                 {
                   'display_name' => 'SPCC63.05delta',
                   'long_display_name' => 'SPCC63.05delta',
                   'expression' => undef,
                   'primary_identifier' => 'SPCC63.05:aaaa0007-1',
                   'gene_id' => 4,
                   'description' => 'deletion',
                   'name' => 'SPCC63.05delta',
                   'allele_id' => 5,
                   'type' => 'deletion',
                   'gene_display_name' => 'SPCC63.05',
                   'gene_systematic_id' => 'SPCC63.05',
                   'comment' => undef,
                   'synonyms' => [],
                   'notes' => {},
                   'promoter_gene' => undef,
                 }
               ],
               'display_name' => 'SPCC63.05delta ssm4KE',
               'identifier' => 'aaaa0007-genotype-test-1',
               'name' => 'SPCC63.05delta ssm4KE',
               annotation_count => 1,
               interaction_count => 0,
               background => 'h+',
               comment => undef,
               organism => {
                 scientific_name => 'Schizosaccharomyces pombe',
                 taxonid => '4896',
                 pathogen_or_host => 'unknown',
                 full_name => 'Schizosaccharomyces pombe',
                 common_name => 'fission yeast'
               },
             });
};

test_psgi $app, sub {
  my $cb = shift;

  {
    my $uri = new URI("$root_url/ws/settings/get_all");
    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    my $perl_res = decode_json $res->content();

    is($perl_res->{annotation_mode}, 'advanced');
  }

  my $post_header = ['Content-Type' => 'application/json; charset=UTF-8'];

  {
    my $uri = new URI("$root_url/ws/settings/set/annotation_mode");
    my $req = HTTP::Request->new(POST => $uri, $post_header, '{"value": "advanced"}');
    my $res = $cb->($req);

    my $perl_res = decode_json $res->content();

    is($perl_res->{status}, 'success');
  }

  {
    my $uri = new URI("$root_url/ws/settings/get_all");
    my $req = HTTP::Request->new(GET => $uri);
    my $res = $cb->($req);

    my $perl_res = decode_json $res->content();

    is($perl_res->{annotation_mode}, 'advanced');
  }

  {
    my $uri = new URI("$root_url/ws/settings/set/dummy");
    my $req = HTTP::Request->new(POST => $uri, $post_header, '{"value": "dummy"}');
    my $res = $cb->($req);

    my $perl_res = decode_json $res->content();

    is($perl_res->{status}, 'error');
  }
};
