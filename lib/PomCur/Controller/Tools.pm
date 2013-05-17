package PomCur::Controller::Tools;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Package::Alias PubmedUtil => 'PomCur::Track::PubmedUtil',
                   LoadUtil => 'PomCur::Track::LoadUtil';

use Clone qw(clone);
use Try::Tiny;

use PomCur::MailSender;
use PomCur::Export::CantoJSON;
use PomCur::Export::TabZip;

use Moose;

with 'PomCur::Role::CheckACL';

sub _get_status_cv
{
  my $schema = shift;

  my $cv_name = 'PomCur publication triage status';
  return $schema->find_with_type('Cv', { name => $cv_name });
}

sub _get_next_triage_pub
{
  my $schema = shift;
  my $new_cvterm = shift;

  my $constraint = {
    triage_status_id => $new_cvterm->cvterm_id()
  };

  my $options = {
    # nasty hack to order by pubmed ID
    order_by => {
      -asc => "cast((case me.uniquename like 'PMID:%' WHEN 1 THEN " .
        "substr(me.uniquename, 6) ELSE me.uniquename END) as integer)"
    },
    rows => 1,
  };

  return $schema->resultset('Pub')->search($constraint, $options)->single();
}

sub _redirect_to_pub
{
  my $c = shift;
  my $pub = shift;

  $c->res->redirect($c->uri_for('/view/object/pub/' . $pub->pub_id(), { model => 'track'} ));
  $c->detach();
}

=head1 NAME

PomCur::Controller::Tools - Controller for PomCur user tools

=head1 METHODS

=cut
sub triage :Local {
  my ($self, $c) = @_;

  if (!defined $c->user() || $c->user()->role()->name() ne 'admin') {
    $c->stash()->{error} = "Log in as administrator to allow triaging";
    $c->forward('/front');
    $c->detach();
    return;
  }

  my $st = $c->stash();
  my $schema = $c->schema('track');
  my $cv = _get_status_cv($schema);

  my $pub_just_triaged = undef;

  my $return_pub_id = $c->req()->param('triage-return-pub-id');
  $st->{return_pub_id} = $return_pub_id;

  my $new_status_cvterm = $schema->find_with_type('Cvterm',
                                                  { cv_id => $cv->cv_id(),
                                                    name => 'New' });

  my $next_pub = undef;

  my $untriaged_pubs_count = $schema->resultset('Pub')->search({
    triage_status_id => $new_status_cvterm->cvterm_id(),
  })->count();

  if ($c->req()->param('submit')) {
    my $guard = $schema->txn_scope_guard;

    my $pub_id = $c->req()->param('triage-pub-id');
    my $status_name = $c->req()->param('submit');

    $pub_just_triaged = $schema->find_with_type('Pub', $pub_id);

    my $status = $schema->find_with_type('Cvterm', { name => $status_name,
                                                     cv_id => $cv->cv_id() });

    $pub_just_triaged->triage_status_id($status->cvterm_id());

    my $pubprop_types_cv_name = 'PomCur publication property types';

    my $pubprop_types_cv =
      $schema->find_with_type('Cv',
                              { name => $pubprop_types_cv_name });
    my $experiment_type =
      $schema->find_with_type('Cvterm',
                              { name => 'experiment_type',
                                cv_id => $pubprop_types_cv->cv_id() });
    $pub_just_triaged->pubprops()->search({ type_id => $experiment_type->cvterm_id() })
      ->delete();

    for my $exp_type_param ($c->req()->param('experiment-type')) {
      my $pubprop =
        $schema->create_with_type('Pubprop',
                                  { type_id => $experiment_type->cvterm_id(),
                                    value => $exp_type_param,
                                    pub_id => $pub_just_triaged->pub_id() });
    }

    my $corresponding_author_id =
      $c->req()->param('triage-corresponding-author-person-id');
    if (defined $corresponding_author_id && length $corresponding_author_id > 0) {
      if ($corresponding_author_id =~ /^\d+$/) {
        if (defined $schema->resultset('Person')->find({
          person_id => $corresponding_author_id
        })) {
          $pub_just_triaged->corresponding_author($corresponding_author_id);
        }
      }
    } else {
      # user may have used the "New ..." button
      my $new_name =
        $c->req()->param('triage-corresponding-author-add-name') // '';
      $new_name =~ s/^\s+//;
      $new_name =~ s/\s+$//;
      my $new_email =
        $c->req()->param('triage-corresponding-author-add-email') // '';
      $new_email =~ s/^\s+//;
      $new_email =~ s/\s+$//;

      if (length $new_name > 0 || length $new_email > 0) {
        my $new_params = clone $c->req()->params();
        delete $new_params->{submit};
        my $redirect_uri = $c->uri_for('/tools/triage', $new_params);
        if (length $new_email == 0) {
          $c->flash()->{error} =
            "No email address given for new user: $new_name";
          $c->res->redirect($redirect_uri);
          $c->detach();
        }
        if (length $new_name == 0) {
          $c->flash()->{error} =
            "No name given for new email: $new_email";
          $c->res->redirect($redirect_uri);
          $c->detach();
        }
        my $load_util = LoadUtil->new(schema => $schema);
        my $user_types_cv = $load_util->find_cv('PomCur user types');
        my $user_cvterm = $load_util->get_cvterm(cv => $user_types_cv,
                                                 term_name => 'user');

        my $new_person = $schema->resultset('Person')->create({
          name => $new_name,
          email_address => $new_email,
          role => $user_cvterm,
        });
        $pub_just_triaged->corresponding_author($new_person->person_id());
      } else {
        # they didn't enter a new person - that's OK
      }
    }

    my $priority_cvterm_id = $c->req()->param('triage-curation-priority');
    my $priority_cvterm =
      $schema->resultset('Cvterm')->find({ cvterm_id => $priority_cvterm_id });

    $pub_just_triaged->curation_priority($priority_cvterm);

    my $community_curatable = $c->req()->param('community-curatable');
    my $community_curatable_cvterm =
      $schema->resultset('Cvterm')->find({ name => "community_curatable" });

    if (!defined $community_curatable_cvterm) {
      die "Can't find term for: community_curatable";
    }

    $pub_just_triaged->pubprops()->search({ type_id => $community_curatable_cvterm->cvterm_id() })
      ->delete();

    if (defined $community_curatable) {
      $schema->create_with_type('Pubprop',
                                { type_id => $community_curatable_cvterm->cvterm_id(),
                                  value => 'yes',
                                  pub_id => $pub_just_triaged->pub_id() });
    }

    my $triage_comment = $c->req()->param('triage-comment');
    my $triage_comment_cvterm =
      $schema->resultset('Cvterm')->find({ name => "triage_comment" });

    if (!defined $triage_comment_cvterm) {
      die "Can't find term for: triage_comment";
    }

    $pub_just_triaged->pubprops()->search({ type_id => $triage_comment_cvterm->cvterm_id() })
      ->delete();

    if (defined $triage_comment) {
      $triage_comment =~ s/^\s+//;
      $triage_comment =~ s/\s+$//;
      if (length $triage_comment > 0) {
        $schema->create_with_type('Pubprop',
                                  { type_id => $triage_comment_cvterm->cvterm_id(),
                                    value => $triage_comment,
                                    pub_id => $pub_just_triaged->pub_id() });
      }
    }

    $pub_just_triaged->update();

    $guard->commit();

    if (defined $return_pub_id && length $return_pub_id > 0) {
      # we were triaging a single publication and should now go back to the
      # publication detail page
      $next_pub = undef;
    } else {
      $next_pub = _get_next_triage_pub($schema, $new_status_cvterm);
    }

    if (defined $next_pub) {
      $c->res->redirect($c->uri_for('/tools/triage'));
      $c->detach();
    } else {
      # fall through
    }
  } else {
    my $return_pub = $schema->resultset('Pub')->find({ pub_id => $return_pub_id });
    $next_pub = $return_pub // _get_next_triage_pub($schema, $new_status_cvterm);
  }

  if (defined $next_pub) {
    $st->{title} = 'Triaging ' . $next_pub->uniquename();
    if (!defined $return_pub_id) {
      $st->{right_title} =
        "$untriaged_pubs_count remaining";
    }

    $st->{pub} = $next_pub;

    $st->{template} = 'tools/triage.mhtml';
  } else {
    if (defined $return_pub_id && length $return_pub_id > 0) {
      $c->flash()->{message} = $pub_just_triaged->uniquename . ' triaged';
      $c->res->redirect($c->uri_for("/view/object/pub/$return_pub_id", { model => 'track'} ));
    } else {
      $c->flash()->{message} =
        'Triaging finished - no more un-triaged publications';
      $c->res->redirect($c->uri_for('/'));
    }
    $c->detach();
  }
}

sub _load_one_pub
{
  my $config = shift;
  my $schema = shift;
  my $pubmedid = shift;

  my $raw_pubmedid;

  $pubmedid =~ s/[^_\d\w:]+//g;

  if ($pubmedid =~ /^\s*(?:pmid:|pubmed:)?(\d+)\s*$/i) {
    $raw_pubmedid = $1;
    $pubmedid = "PMID:$1";
  } else {
    my $message = 'You need to give the raw numeric ID, or the ID ' .
      'prefixed by "PMID:" or "PubMed:"';
    return (undef, $message);
  }

  my $pub = $schema->resultset('Pub')->find({ uniquename => $pubmedid });

  if (defined $pub) {
    return ($pub, undef);
  } else {
    my $xml = PubmedUtil::get_pubmed_xml_by_ids($config, $raw_pubmedid);

    my $count = PubmedUtil::load_pubmed_xml($schema, $xml, 'user_load');

    if ($count) {
      $pub = $schema->resultset('Pub')->find({ uniquename => $pubmedid });
      return ($pub, undef);
    } else {
      (my $numericid = $pubmedid) =~ s/.*://;
      my $message = "No publication found in PubMed with ID: $numericid";
      return (undef, $message);
    }
  }
}

sub pubmed_id_lookup : Local Form {
  my ($self, $c) = @_;

  my $st = $c->stash();

  my $pubmedid = $c->req()->param('pubmed-id-lookup-input');

  my $result;

  if (!defined $pubmedid) {
    $result = {
      message => 'No PubMed ID given'
    }
  } else {
    my ($pub, $message) =
      _load_one_pub($c->config, $c->schema('track'), $pubmedid);

    if (defined $pub) {
      $result = {
        pub => {
          uniquename => $pub->uniquename(),
          title => $pub->title(),
          authors => $pub->authors(),
          abstract => $pub->abstract(),
          pub_id => $pub->pub_id(),
        }
      };

      my $sessions_rs = $pub->curs();
      if ($sessions_rs->count() > 0) {
        my $uniquename = $pub->uniquename();
        $result->{message} = "Sorry, $uniquename is currently being curated by someone " .
            "else.  Please contact the curation team for more information.";
        $result->{curation_sessions} = [ map { $_->curs_key(); } $sessions_rs->all() ],
      }
    } else {
      $result = {
        message => $message
      }
    }
  }

  $c->stash->{json_data} = $result;
  $c->forward('View::JSON');

}

sub pubmed_id_start : Local {
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Find a publication to curate using a PubMed ID';
  $st->{show_title} = 0;
  $st->{template} = 'tools/pubmed_id_start.mhtml';
}

sub pmid_search : Local {
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Find a publication to curate using a PubMed ID';
  $st->{show_title} = 0;
  $st->{template} = 'tools/pmid_search.mhtml';
}

=head2 start

 Usage   : /start/<pubmedid>
 Function: Create a new session for a publication and redirect to it
 Args    : pubmedid

=cut
sub start : Local Args(1) {
  my ($self, $c, $pub_uniquename) = @_;

  my $st = $c->stash();

  my $schema = $c->schema('track');
  my $config = $c->config();

  my $pub = $schema->find_with_type('Pub', { uniquename => $pub_uniquename });
  my $curs_key = PomCur::Curs::make_curs_key();

  my $curs = $schema->create_with_type('Curs',
                                       {
                                         pub => $pub,
                                         curs_key => $curs_key,
                                       });

  my $curs_schema = PomCur::Track::create_curs_db($config, $curs);

  my $mail_sender = PomCur::MailSender->new(config => $config);

  my $subject = "Created new session $curs_key from $pub_uniquename";
  my $session_uri = $c->uri_for("/curs/$curs_key");
  my $body = "Publication: $pub_uniquename\n\n" .
    $pub->title() . "\n\n" .
    "Session: " . $session_uri . "\n";

  $mail_sender->send_to_admin(subject => $subject,
                              body => $body);

  $c->res->redirect($session_uri);
}

=head2 pub_session

 Usage   : /pub_session/<pubmedid>
 Function: If a session exists for the publication, go to it.  Otherwise create
           a new session for a publication and redirect to it.
           If there is more than one session, go to the first.
 Args    : pubmedid

=cut
sub pub_session : Local Args(1) {
  my ($self, $c, $pub_id) = @_;

  my $st = $c->stash();

  my $schema = $c->schema('track');
  my $config = $c->config();

  my $pub = $schema->find_with_type('Pub', { pub_id => $pub_id });

  my $curs = $pub->curs()->first();

  if (!defined $curs) {
    my $curs_key = PomCur::Curs::make_curs_key();
    $curs = $schema->create_with_type('Curs',
                                       {
                                         pub => $pub,
                                         curs_key => $curs_key,
                                       });
    my $curs_schema = PomCur::Track::create_curs_db($config, $curs);
  }

  $c->res->redirect($c->uri_for("/curs/" . $curs->curs_key()));
}

=head2 store_all_statuses

 Function: Call PomCur::Curs::Utils::store_all_statuses()
 Args    : none

=cut
sub store_all_statuses : Local Args(0) {
  my ($self, $c) = @_;

  my $track_schema = $c->schema('track');
  my $config = $c->config();

  PomCur::Curs::Utils::store_all_statuses($config, $track_schema);

  $c->flash()->{message} =
    'Stored statuses for all sessions';
  $c->res->redirect($c->uri_for('/'));
  $c->detach();
}

sub ann_ex_locations : Local Args(0) {
  my ($self, $c) = @_;

  my $st = $c->stash();

  my $track_schema = $c->schema('track');
  my $config = $c->config();

  my %anexs = ();

  my $iter = PomCur::Track::curs_iterator($config, $track_schema);
  while (my ($curs, $cursdb) = $iter->()) {
    my $curs_key = $curs->curs_key();
    for my $gene ($cursdb->resultset('Gene')->all()) {
      for my $annotation ($gene->direct_annotations()) {
        next if $annotation->status() eq 'deleted';
        if (defined $annotation->data()->{annotation_extension}) {
          push @{$anexs{$annotation->data()->{annotation_extension}}->{$curs_key}}, {
            primary_identifier => $gene->primary_identifier(),
            gene_id => $gene->gene_id(),
          };
        }
      }
    }
  }

  $st->{extension_data} = \%anexs;

  $st->{title} = 'Locations of annotation extension strings';
  $st->{show_title} = 0;
  $st->{template} = 'tools/ann_ex_locations.mhtml';
}

sub sessions_with_type : Local Args(1) {
  my ($self, $c, $annotation_type) = @_;

  my $st = $c->stash();

  my $track_schema = $c->schema('track');
  my $config = $c->config();

  my $proc = sub {
    my $curs = shift;
    my $curs_schema = shift;

    my $rs = $curs_schema->resultset("Annotation")->search({ type => $annotation_type });
    return [$curs->curs_key(), $rs->count()];
  };

  my @res = PomCur::Track::curs_map($config, $track_schema, $proc);

  $st->{annotation_type} = $annotation_type;
  $st->{type_data} = [sort { $a->[0] cmp $b->[1] } grep { $_->[1] > 0 } @res];

  $st->{title} = "Sessions with annotations of type: $annotation_type";
  $st->{template} = 'tools/session_with_type.mhtml';
}

sub sessions_with_type_list : Local Args(0) {
  my ($self, $c) = @_;

  my $st = $c->stash();

  my $track_schema = $c->schema('track');
  my $config = $c->config();

  my $proc = sub {
    my $curs = shift;
    my $curs_schema = shift;

    my %res_map = ();

    my $rs = $curs_schema->resultset("Annotation");
    while (defined (my $an = $rs->next())) {
      $res_map{$an->type()} = 1;
    }
    return \%res_map;
  };

  my @res = PomCur::Track::curs_map($config, $track_schema, $proc);

  my %totals = ();

  map {
    while (my ($key, $count) = each %$_) {
      $totals{$key} += $count;
    }
  } @res;

  $st->{annotation_types} = [map {
    [$_->{name}, $totals{$_->{name}} // 0]
  } @{$config->{annotation_type_list}}];


  $st->{title} = "Sessions listed by type";
  $st->{template} = 'tools/sessions_with_type_list.mhtml';
}

=head2 add_person

 Function: Called with ajax by the person_picker_add template to add a person
 Args    : person-picker-add-name - the name to add
           person-picker-add-email - the email to add
 Return  : a JSON object with fields:
              person_id the database ID of the new Person
              name - the name of the new Person

=cut

sub add_person : Local Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  my $track_schema = $c->schema('track');
  my $config = $c->config();

  my $load_util = LoadUtil->new(schema => $track_schema);
  my $user_cvterm = $load_util->get_cvterm(cv_name => 'PomCur user types',
                                           term_name => 'user');

  my $name = $c->req()->param('person-picker-add-name');
  my $email = $c->req()->param('person-picker-add-email');

  my $result = { };

  if (!defined $name || length $name == 0) {
    $result->{error_message} = 'No name given';
  } else {
    if (!defined $email || length $email == 0) {
      $result->{error_message} = 'No email address given';
    } else {
      my $person = $track_schema->resultset('Person')->find({ email_address => $email });
      try {
        if (!defined $person) {
          $person = $track_schema->create_with_type('Person',
                                                    {
                                                      name => $name,
                                                      email_address => $email,
                                                      role => $user_cvterm,
                                                    });
        }
        $result->{person_id} = $person->person_id();
        $result->{name} = $person->name();
      } catch {
        $result->{error_message} = $_;
      }
    }
  }

  $c->stash->{json_data} = $result;
  $c->forward('View::JSON');
}

=head2 create_session

 Function: Make a Curs and a CursDB for it
 Args    : pub - the publication ID
           curator - the Person to curate the session
 Return  : none

=cut

sub create_session : Local Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  my $track_schema = $c->schema('track');
  my $config = $c->config();

  my $load_util = LoadUtil->new(schema => $track_schema);
  my $user_cvterm = $load_util->get_cvterm(cv_name => 'PomCur user types',
                                           term_name => 'user');

  my $return_path = $c->req()->param('pub-view-path');

  my $pub_id = $c->req()->param('pub_id');
  my $person_id = $c->req()->param('pub-create-session-person-id');

  my $person =
    $track_schema->resultset('Person')->find({ person_id => $person_id });

  if (!defined $person) {
    $c->flash()->{message} = "No curator chosen - session not created";
    $c->res->redirect($return_path);
    $c->detach();
  }

  if ($c->req->param('curs-pub-create-session-cancel')) {
    $c->res->redirect($return_path);
    $c->detach();
  }

  my $pub = $track_schema->find_with_type('Pub', { pub_id => $pub_id });

  if ($pub->not_exported_curs()->count() == 0) {
    my $admin_session = 0;
    if ($person->role()->name() eq 'admin') {
      $admin_session = 1;
    }
    my %create_args = (
      pub => $pub_id,
      curs_key => PomCur::Curs::make_curs_key(),
    );
    my $curs = $track_schema->create_with_type('Curs', { %create_args });
    my ($curs_schema) = PomCur::Track::create_curs_db($c->config(), $curs, $admin_session);

    my $curator_name = $person->name();
    my $curator_email = $person->email_address();

    my $curator_manager =
      PomCur::Track::CuratorManager->new(config => $config);

    $curator_manager->set_curator($curs->curs_key, $curator_email,
                                  $curator_name);

    if (defined $curs_schema) {
      PomCur::Curs::State->new(config => $config)->store_statuses($curs_schema);
    }
  }

  $c->res->redirect($return_path);
  $c->detach();
}

sub send_session : Local Args(1)
{
  my ($self, $c, $curs_key) = @_;

  my $track_schema = $c->schema('track');
  my $curs = $track_schema->find_with_type('Curs',
                                           {
                                             curs_key => $curs_key,
                                           });
  my $config = $c->config();
  my $email_util = PomCur::EmailUtil->new(config => $config);
  my $pub = $curs->pub();

  my $curator_manager =
    PomCur::Track::CuratorManager->new(config => $c->config());
  my ($submitter_email, $submitter_name) =
    $curator_manager->current_curator($curs_key);

  my $help_index = $c->uri_for($config->{help_path});

  my %args = (
    session_link => $c->uri_for("/curs/$curs_key"),
    curator_name => $submitter_name,
    publication_uniquename => $pub->uniquename(),
    publication_title => $pub->title(),
    help_index => $help_index,
  );

  my ($subject, $body) = $email_util->make_email_contents('session_assigned', %args);

  my $mail_sender = PomCur::MailSender->new(config => $config);

  $mail_sender->send(to => $submitter_email,
                     subject => $subject,
                     body => $body);

  my $link_sent_to_curator_date_cvterm =
    $track_schema->resultset('Cvterm')
      ->find({ name => 'link_sent_to_curator_date',
               'cv.name' => 'PomCur cursprop types' },
             { join => 'cv' });

  my $link_sent_date_cvterm_id = $link_sent_to_curator_date_cvterm->cvterm_id();
  my $link_sent_prop =
    $curs->cursprops()->search({ type => $link_sent_date_cvterm_id })->first();
  my $now = PomCur::Util::get_current_datetime();
  if (defined $link_sent_prop) {
    $link_sent_prop->value($now);
  } else {
    $track_schema->resultset('Cursprop')->create({ curs => $curs->curs_id(),
                                                   type => $link_sent_date_cvterm_id,
                                                   value => $now });
  }

  $c->flash()->{message} = "Session email sent to user";

  _redirect_to_pub($c, $pub);
}


=head2 remove_curs

 Function: remove the curs given by the argument curs_key and remove its cursdb
 Args    : $curs_key = the curs key hash
 Return  : nothing

=cut

sub remove_curs : Local Args(1)
{
  my ($self, $c, $curs_key) = @_;

  if (!$self->check_access($c)->{delete}) {
    die "insufficient privileges to remove a session";
  }

  my $st = $c->stash();

  my $track_schema = $c->schema('track');
  my $curs = $track_schema->find_with_type('Curs',
                                           {
                                             curs_key => $curs_key,
                                           });
  my $pub = $curs->pub();

  $c->flash()->{message} = "Deleted session: $curs_key";

  PomCur::Track::delete_curs($c->config(), $track_schema, $curs_key);

  _redirect_to_pub($c, $pub);
}


=head2 dump

 Function: Retrieve the approved sessions in the requested format
 Args    : $type - export type eg. cantojson, tabzip (zip file of tab delimited
                   data)
 Return  : the data

=cut
sub dump : Local Args(2)
{
  my ($self, $c, $dump_type, $dump_format) = @_;

  if (!$self->check_access($c)->{dump}) {
    die "insufficient privileges to dump sessions";
  }

  my $config = $c->config();
  my $track_schema = PomCur::TrackDB->new(config => $config);

  my $file_name_prefix;

  my @options;
  if ($dump_type eq 'approved') {
    @options = qw(--dump-approved);
    $file_name_prefix = "approved_session_annotation";
  } else {
    if ($dump_type eq 'all_sessions') {
      # default is all sessions
      @options = ();
      $file_name_prefix = "all_session_annotation";
    } else {
      if ($dump_type eq 'exported') {
        @options = qw(--dump-exported);
        $file_name_prefix = "exported_session_annotation";
      } else {
        die "unknown export type '$dump_type'\n";
      }
    }
  }

  my $exporter;

  if ($dump_format eq 'json') {
    $exporter = PomCur::Export::CantoJSON->new(config => $config,
                                               options => \@options);
    $c->res->content_type('text/plain');
  } else {
    if ($dump_format eq 'tabzip') {
      $exporter = PomCur::Export::TabZip->new(config => $config,
                                              options => \@options);
      $c->res->headers->header("Content-Disposition" =>
                                 "attachment; filename=$file_name_prefix.zip");
      $c->res->content_type('application/zip');
    } else {
      die "unknown export type: $dump_format\n";
    }
  }

  my $results = $exporter->export();
  $c->res->body($results);
}

=head2 export

 Function: Export the approved sessions in the requested format then mark the
           approved sessions as "EXPORTED".
 Args    : $type - export type eg. cantojson, tabzip (zip file of tab delimited
                   data)
 Return  : the exported data

=cut

sub export : Local Args(2)
{
  my ($self, $c, $export_type, $export_format) = @_;

  if (!$self->check_access($c)->{export}) {
    die "insufficient privileges to export sessions";
  }

  my $config = $c->config();
  my $track_schema = PomCur::TrackDB->new(config => $config);

  my @options;
  if ($export_type eq 'approved') {
    @options = qw(--export-approved);
  } else {
    die "unknown export type '$export_type'\n";
  }

  my $admin_person = $c->user()->get_object();

  my $exporter;

  if ($export_format eq 'json') {
    $exporter = PomCur::Export::CantoJSON->new(config => $config,
                                               options => \@options);
    $c->res->content_type('text/plain');
  } else {
    if ($export_format eq 'tabzip') {
      $exporter = PomCur::Export::TabZip->new(config => $config,
                                              options => \@options);
      $c->res->headers->header("Content-Disposition" =>
                                 "attachment; filename=approved_session_annotation.zip");
      $c->res->content_type('application/zip');
    } else {
      die "unknown export type: $export_format\n";
    }
  }

  my $results = $exporter->export();
  $c->res->body($results);
}

=head1 LICENSE
This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
