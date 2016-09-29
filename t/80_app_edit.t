use strict;
use warnings;
use Test::More tests => 29;

use Canto::TestUtil;

use Plack::Test;
use Plack::Util;
use HTTP::Request;

my $test_util = Canto::TestUtil->new();
$test_util->init_test();

my $return_path = 'http://localhost:5000/';

my %test_app_conf = %{$test_util->plack_app(login => $return_path)};
my $app = $test_app_conf{app};
my $cookie_jar = $test_app_conf{cookie_jar};

my $test_name = 'Test name';
my $test_email = 'test@test';
my $test_email2 = 'new@test_email';

my $new_person_id = undef;

my $schema = $test_util->track_schema();

test_psgi $app, sub {
  my $cb = shift;

  # test visiting the create object page
  {
    my $url = 'http://localhost:5000/object/new/person?model=track';
    my $req = HTTP::Request->new(GET => $url);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 200;

    like ($res->content(), qr/<form/);
    like ($res->content(), qr/<input name="email_address"/);
  }

  # test creating an object
  {
    my $uri = new URI('http://localhost:5000/object/new/person');
    $uri->query_form(model => 'track',
                     name => $test_name,
                     email_address => $test_email,
                     lab => 0,
                     role => 1,
                     submit => 'Submit',
                    );

    my $req = HTTP::Request->new(GET => $uri);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    ok ($redirect_url =~ m:view/object/person/(\d+):);

    $new_person_id = $1;

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Details for Test name/);
    like ($redirect_res->content(), qr/Email address/);
    like ($redirect_res->content(), qr/\Q$test_name/);
    like ($redirect_res->content(), qr/\Q$test_email/);
  }

  # test visiting the edit object page
  {
    my $url = "http://localhost:5000/object/edit/person/$new_person_id?model=track";
    my $req = HTTP::Request->new(GET => $url);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 200;

    like ($res->content(), qr/<form/);
    like ($res->content(), qr/<input name="email_address"/);
  }

  # test editing an object
  {
    my $test_name = 'Test name';

    my $uri = new URI("http://localhost:5000/object/edit/person/$new_person_id");
    $uri->query_form(model => 'track',
                     name => $test_name,
                     email_address => $test_email2,
                     lab => 0,
                     role => 1,
                     submit => 'Submit',
                    );

    my $req = HTTP::Request->new(GET => $uri);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Details for Test name/);
    like ($redirect_res->content(), qr/Email address/);
    unlike ($redirect_res->content(), qr/\Q$test_email/);
    like ($redirect_res->content(), qr/\Q$test_email2/);
  }

  # test create action
  {
    my $test_name = 'Test name';
    my $pub = $schema->find_with_type('Pub', { uniquename => 'PMID:19056896' });
    my $curs_key = 'abcd1234';

    my $uri = new URI("http://localhost:5000/create/curs");
    $uri->query_form(model => 'track',
                     curs_key => $curs_key,
                     pub => $pub->pub_id(),
                    );

    my $req = HTTP::Request->new(GET => $uri);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);

    is $res->code, 302;

    my $redirect_url = $res->header('location');

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Details for curation session $curs_key/);
    my $pub_uniquename = $pub->uniquename();
    like ($redirect_res->content(), qr/$pub_uniquename/);
  }

  my $load_type_cvterm =
    $schema->find_with_type('Cvterm', { name => "admin_load" });

  my $other_pub = $schema->find_with_type('Pub', { uniquename => 'PMID:19686603' });
  ok (defined $other_pub);

  # special case: test editing publications separately as they have a reference
  # that ends in _id ("type_id") and an odd order_by field
  {
    my $pub = $schema->find_with_type('Pub', { uniquename => 'PMID:19686603' });
    ok (defined $pub);
    my $pub_id = $pub->pub_id();

    my $url = "http://localhost:5000/object/edit/pub/$pub_id?model=track";
    my $uri = new URI($url);

    $uri->query_form(model => 'track',
                     'Publication ID' => 'TEST:1',
                     title => 'title',
                     authors => '',
                     corresponding_author => 0,
                     type => $pub->type_id(),
                     load_type => $load_type_cvterm->cvterm_id(),
                     triage_status => $pub->triage_status()->cvterm_id(),
                     curation_priority => 0,
                     submit => 'Submit',
                    );

    my $req = HTTP::Request->new(GET => $uri);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);
    is $res->code, 302;

    my $redirect_url = $res->header('location');

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Details for publication/);
    like ($redirect_res->content(), qr/TEST:1/);
  }

  # edit same publication again
  {
    my $pub = $schema->find_with_type('Pub', { uniquename => 'TEST:1' });
    ok (defined $pub);
    my $pub_id = $pub->pub_id();

    my $url = "http://localhost:5000/object/edit/pub/$pub_id?model=track";
    my $uri = new URI($url);
    $uri->query_form(model => 'track',
                     'Publication ID' => 'TEST:2',
                     title => 'title',
                     authors => '',
                     corresponding_author => 0,
                     type => $pub->type_id(),
                     load_type => $load_type_cvterm->cvterm_id(),
                     triage_status => $pub->triage_status()->cvterm_id(),
                     curation_priority => 0,
                     submit => 'Submit',
                    );

    my $req = HTTP::Request->new(GET => $uri);
    $cookie_jar->add_cookie_header($req);

    my $res = $cb->($req);
    is $res->code, 302;

    my $redirect_url = $res->header('location');

    my $redirect_req = HTTP::Request->new(GET => $redirect_url);
    my $redirect_res = $cb->($redirect_req);

    like ($redirect_res->content(), qr/Details for publication/);
    like ($redirect_res->content(), qr/TEST:2/);
  }

};

done_testing;
