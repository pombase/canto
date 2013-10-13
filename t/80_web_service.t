use strict;
use warnings;
use Test::More tests => 14;

use Canto::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

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

    use JSON::Any;

    my $json_any = JSON::Any->new();
    my $obj = $json_any->jsonToObj($res->content());

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

    use JSON::Any;

    my $json_any = JSON::Any->new();
    my $obj;
    eval { $obj = $json_any->jsonToObj($res->content()); };
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

    use JSON::Any;

    my $json_any = JSON::Any->new();
    my $obj;
    eval { $obj = $json_any->jsonToObj($res->content()); };
    if ($@) {
      die "$@\n", $res->content();
    }

    is (@$obj, 2);
    ok(grep { $_->{id} =~ /PECO:0000137/ } @$obj);
    ok(grep { $_->{name} =~ /glucose rich medium/ } @$obj);
    ok(grep { $_->{annotation_namespace} =~ /phenotype_condition/ } @$obj);
  }

};

done_testing;
