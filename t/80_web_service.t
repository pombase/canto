use strict;
use warnings;
use Test::More tests => 23;

use Canto::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;
use JSON;

use Canto::Track;

my $test_util = Canto::TestUtil->new();
$test_util->init_test();

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
    ok(grep { $_->{name} =~ /molecular_function/ } @$obj);
    ok(grep { $_->{comment} =~ /Note that, in addition to forming the root/ } @$obj);
  }

  # test "phenotype_condition" which is an ontology but not an
  # annotation type
  {
    my $search_term = 'gl';
    my $url = "http://localhost:5000/ws/lookup/ontology/phenotype_condition/?term=$search_term";
    my $req = HTTP::Request->new(GET => $url);
    my $res = $cb->($req);

    is $res->code, 200;

    my $obj;
    eval { $obj = decode_json($res->content()); };
    if ($@) {
      die "$@\n", $res->content();
    }

    is (@$obj, 2);
    ok(grep { $_->{id} =~ /PECO:0000137/ } @$obj);
    ok(grep { $_->{name} =~ /glucose rich medium/ } @$obj);
    ok(grep { $_->{annotation_namespace} =~ /phenotype_condition/ } @$obj);
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

    like($res->content(), qr/"allele_name_required"\s*:\s*false/);
    like($res->content(), qr/"allele_name_required"\s*:\s*true/);

    ok ($obj->{'partial deletion, nucleotide'}->{allow_expression_change});
    ok (!$obj->{'partial deletion, nucleotide'}->{allele_name_required});
  }
};

done_testing;
