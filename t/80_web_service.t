use strict;
use warnings;
use Test::More tests => 38;
use Test::Deep;

use Canto::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;
use JSON;

use Canto::Track;

my $test_util = Canto::TestUtil->new();
$test_util->init_test();

my $config = $test_util->config();
my $cookie_jar = $test_util->cookie_jar();

my $app = $test_util->plack_app()->{app};


test_psgi $app, sub {
  my $cb = shift;

  {
    my $search_term = 'transport';
    my $url = "http://localhost:5000/ws/lookup/ontology/biological_process/?term=$search_term";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    my $obj = decode_json($res->content());

    is (@$obj, 7);

    ok(grep { $_->{id} =~ /GO:0055085/ } @$obj);
    ok(grep { $_->{name} =~ /transmembrane transport/ } @$obj);
  }

  {
    my $search_term = 'molecular_function';
    my $url = "http://localhost:5000/ws/lookup/ontology/molecular_function/?term=$search_term&def=1";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    my $obj;
    eval { $obj = decode_json($res->content()); };
    if ($@) {
      die "$@\n", $res->content();
    }

    is (@$obj, 1);
    ok(grep { $_->{id} =~ /GO:0003674/ } @$obj);
  }

  # test "fission_yeast_phenotype_condition" which is an ontology but not an
  # annotation type
  {
    my $search_term = 'glu';
    my $url = "http://localhost:5000/ws/lookup/ontology/fission_yeast_phenotype_condition/?term=$search_term";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    my $obj;
    eval { $obj = decode_json($res->content()); };
    if ($@) {
      die "$@\n", $res->content();
    }

    is (@$obj, 1);

    ok(grep { $_->{id} =~ /FYECO:0000012/ } @$obj);
    ok(grep { $_->{name} =~ /standard glucose rich medium/ } @$obj);
    ok(grep { $_->{annotation_namespace} =~ /fission_yeast_phenotype_condition/ } @$obj);
  }

  # test getting all "fission_yeast_phenotype_condition" terms
  {
    my $url = "http://localhost:5000/ws/lookup/ontology/fission_yeast_phenotype_condition/?term=:ALL:";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    my $obj;
    eval { $obj = decode_json($res->content()); };
    if ($@) {
      die "$@\n", $res->content();
    }

    is (@$obj, 6);

    ok(grep { $_->{id} =~ /FYECO:0000012/ } @$obj);
    ok(grep { $_->{name} =~ /standard glucose rich medium/ } @$obj);
    ok(grep { $_->{annotation_namespace} =~ /fission_yeast_phenotype_condition/ } @$obj);
  }

  # add the closure subsets: cvtermprops with type 'canto_subset'
  my $index_path = $test_util->config()->data_dir_path('ontology_index_dir');
  my $ontology_index = Canto::Track::OntologyIndex->new(config => $config, index_path => $index_path);
  $test_util->load_test_ontologies($ontology_index, 1, 1, 1);

  my $two_term_subset = '[GO:0005215|GO:0016023]';

  # test getting a subset
  {
    my $url = "http://localhost:5000/ws/lookup/ontology/$two_term_subset/?term=:ALL:";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    my $obj;
    eval { $obj = decode_json($res->content()); };
    if ($@) {
      die "$@\n", $res->content();
    }

    my @res = sort {
      $a->{name} cmp $b->{name};
    } map {
      {
        name => $_->{name},
        id => $_->{id},
      }
    } @$obj;

    cmp_deeply(\@res,
               [
                 {
                   'name' => 'cytoplasmic membrane-bounded vesicle',
                   'id' => 'GO:0016023',
                 },
                 {
                   'name' => 'nucleocytoplasmic transporter activity',
                   'id' => 'GO:0005487'
                 },
                 {
                   'id' => 'GO:0030141',
                   'name' => 'stored secretory granule'
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
  }

  # test counting a subset
  {
    my $url = "http://localhost:5000/ws/lookup/ontology/$two_term_subset/?term=:COUNT:";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    my $obj;
    eval { $obj = decode_json($res->content()); };
    if ($@) {
      die "$@\n", $res->content();
    }

    is ($obj->{count}, 6);
  }

  # test counting a subset, in extension_lookup mode - uses subsets to ignore
  # from $config->{ontology_namespace_config}{subsets_to_ignore}{extension}
  # instead of ...{primary_autocomplete}
  {
    my $url = "http://localhost:5000/ws/lookup/ontology/$two_term_subset/?term=:COUNT:&extension_lookup=1";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    my $obj;
    eval { $obj = decode_json($res->content()); };
    if ($@) {
      die "$@\n", $res->content();
    }

    is ($obj->{count}, 6);
  }

  # try lookup_by_id()
  {
    my $search_term = 'GO:0055085';
    my $url = "http://localhost:5000/ws/lookup/ontology/?term=$search_term";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    my $obj;
    eval { $obj = decode_json($res->content()); };
    if ($@) {
      die "$@\n", $res->content();
    }

    is($obj->{id}, $search_term);
    is($obj->{name}, 'transmembrane transport');
    is($obj->{annotation_namespace}, 'biological_process');
  }

  {
    my $url = "http://localhost:5000/ws/canto_config/allele_types";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    my $obj;
    eval { $obj = decode_json($res->content()); };
    if ($@) {
      die "$@\n", $res->content();
    }

    like($res->content(), qr/"description_required"\s*:\s*false/);
    like($res->content(), qr/"allele_name_required"\s*:\s*true/);

    ok ($obj->{'partial deletion, nucleotide'}->{allow_expression_change});
    ok (!$obj->{'unknown'}->{description_required});
  }

  {
    $test_util->app_login($cookie_jar, $cb);

    my $url = "http://localhost:5000/ws/details/user";
    my $req = HTTP::Request->new(GET => $url);
    $cookie_jar->add_cookie_header($req);
    my $res = $cb->($req);

    is $res->code, 200;

    my $obj;
    eval { $obj = decode_json($res->content()); };
    if ($@) {
      die "$@\n", $res->content();
    }

    is ($obj->{status}, 'success');
    is ($obj->{details}->{email}, 'val@3afaba8a00c4465102939a63e03e2fecba9a4dd7.ac.uk');
    is ($obj->{details}->{is_admin}, JSON::true);
  }

  {
    my $url = "http://localhost:5000/ws/canto_config/pathogen_host_mode";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    my $obj;
    eval { $obj = decode_json($res->content()); };
    if ($@) {
      die "$@\n", $res->content();
    }

    ok(!$obj->{value});
  }
};

done_testing;
