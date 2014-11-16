#!/usr/bin/perl -w

use strict;
use warnings;
use Carp;
use feature ':5.10';

use File::Basename;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    # we're in the scripts directory - go up
    chdir "..";
  }
};

use lib qw(lib);

use Canto::Config;
use Canto::TrackDB;
use Canto::Track::LoadUtil;
use Canto::Meta::Util;
use Canto::Track::PubmedUtil;

my $add_cvterm = 0;
my $add_person = 0;
my $add_by_pubmed_id = 0;
my $add_by_pubmed_query = 0;
my $add_session = 0;
my $dry_run = 0;
my $do_help = 0;

if (!@ARGV) {
  usage();
}

my $opt = shift;

if ($opt !~ /^--/) {
  usage (qq{first argument must be an option, not "$opt"});
}

my %dispatch = (
  '--cvterm' => sub {
    $add_cvterm = 1;
  },
  '--person' => sub {
    $add_person = 1;
  },
  '--pubmed-by-id' => sub {
    $add_by_pubmed_id = 1;
  },
  '--pubmed-by-query' => sub {
    $add_by_pubmed_query = 1;
  },
  '--session' => sub {
    $add_session = 1;
  },
  '--help' => sub {
    $do_help = 1;
  },
  '--dry-run' => sub {
    $dry_run = 1;
  },
);

my $dispatch_sub = $dispatch{$opt};

if (defined $dispatch_sub) {
  $dispatch_sub->();
} else {
  usage ();
}

sub usage
{
  my $message= shift;

  if (defined $message) {
    $message .= "\n";
  } else {
    $message = '';
  }

  die qq|${message}usage:
  $0 --cvterm cv_name term_name [db_name:accession [definition]]
or:
  $0 --person "name" email_address password [user_type]
or:
  $0 --pubmed-by-id <pubmed_id> [pubmed_id ...]
or:
  $0 --pubmed-by-query <query>
or:
  $0 --session <pubmed_id> <user_email_address>

Options:
  --cvterm  - add a cvterm to the database
        - cv_name - the name of an existing CV from the cv table
        - term_name - the new term name
        - db_name:accession - optionally, the termid to use for the new dbxref
                              for the cvterm
        - definition - optionally, the term definition
      (if not given the termid defaults to the db_name:term_name where the
       db_name is the "name" from the canto.yaml file)
  --person  - add a person to the database, the user_type can be "user"
              or "admin" with the default being "user"
  --pubmed-by-id  - add publications by PubMed IDs
      The details will be fetched from PubMed.
  --pubmed-by-query  - add publications by querying PubMed
      eg. 'pombe OR "fission yeast"'
  --session - create a session for a publication
|;
}

if ($do_help) {
  usage();
}

if ($add_cvterm && (@ARGV < 2 || @ARGV > 4)) {
  usage("--cvterm needs 2, 3 or 4 arguments");
}

if ($add_person && (@ARGV < 3 || @ARGV > 4)) {
  usage("--person needs 2 or 3 arguments");
}

if ($add_session && @ARGV != 2) {
  usage("--session needs 2 or 3 arguments");
}

if (@ARGV == 0) {
  usage "$opt needs an argument";
}

my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

my $config = Canto::Config::get_config();
my $schema = Canto::TrackDB->new(config => $config);

my $load_util = Canto::Track::LoadUtil->new(schema => $schema);

my $proc = sub {
  if ($add_cvterm) {
    my $cv_name = shift @ARGV;
    my $term_name = shift @ARGV;
    my $termid = shift @ARGV;
    my $definition = shift @ARGV;

    my $cv = undef;
    eval {
      $cv = $load_util->find_cv($cv_name);
    };
    die "could not find CV for: $cv_name\n" if $@;

    eval {
      $load_util->find_cvterm(cv => $cv, name => $term_name);
    };
    die qq/term "$term_name" already exists in CV: $cv_name\n/ unless $@;

    if (defined $termid && length $termid > 0) {
      eval {
        $load_util->find_dbxref($termid);
      };
      die qq/$termid already exists in Dbxref/ unless $@;
    }

    $load_util->get_cvterm(cv => $cv,
                           term_name => $term_name,
                           ontologyid => $termid,
                           definition => $definition);
  }

  if ($add_person) {
    my $name = shift @ARGV;
    my $email_address = shift @ARGV;
    my $password = shift @ARGV;
    my $role_name = shift @ARGV // "user";

    my $role = $load_util->find_cvterm(cv_name => 'Canto user types',
                                       name => $role_name);
    $load_util->get_person($name, $email_address, $role, $password);
  }

  if ($add_session) {
    my $pubmedid = shift @ARGV;
    my $email_address = shift @ARGV;

    my ($curs, $cursdb, $curator) =
      $load_util->create_user_session($config, $pubmedid, $email_address);

    my $pub = $curs->pub();

    if (!$pub->corresponding_author()) {
      $pub->corresponding_author($curator);
      $pub->update();
    }

    print "created session: ", $curs->curs_key(), " pub: ", $pub->uniquename(), " for: $email_address\n";
  }
};

$schema->txn_do($proc);

# these actions start a transactions when needed for consistency:
if ($add_by_pubmed_id) {
  my $count = Canto::Track::PubmedUtil::load_by_ids($config, $schema,
                                                    [@ARGV], 'admin_load');
  print "loaded $count publcations\n";
}

if ($add_by_pubmed_query) {
  if (@ARGV > 1) {
    usage (qq{need one argument to "$opt"});
  } else {
    eval {
      my $count = Canto::Track::PubmedUtil::load_by_query($config, $schema,
                                                          $ARGV[0], 'admin_load');
      print "loaded $count publcations\n";
    };
    if ($@) {
      die "loading failed: $@\n";
    }
  }
}
