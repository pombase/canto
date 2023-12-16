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
my $add_sessions_from_json = 0;
my $add_organism = 0;
my $dry_run = 0;
my $do_help = 0;

if (!@ARGV || $ARGV[0] eq '-h' || $ARGV[0] eq '--help') {
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
  '--sessions-from-json' => sub {
    $add_sessions_from_json = 1;
  },
  '--help' => sub {
    $do_help = 1;
  },
  '--dry-run' => sub {
    $dry_run = 1;
  },
  '--organism' => sub {
    $add_organism = 1;
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
    $message = "Error: $message\n\n";
  } else {
    $message = '';
  }

  die qq|${message}usage:
  $0 --cvterm cv_name term_name [db_name:accession [definition]]
or:
  $0 --person "name" email_address [ORCID [user_type]]
or:
  $0 --pubmed-by-id <pubmed_id> [pubmed_id ...]
or:
  $0 --pubmed-by-query <query>
or:
  $0 --session <pubmed_id> <curator_email_address>
or:
  $0 --sessions-from-json <json_file_name> <curator_email_address> <default_organism_taxonid>
or:
  $0 --organism "<genus> <species>" <taxon_id> [<common_name>]

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
              The ORCID can't be blank.  If the user has no ORCID, use a
              unique string such as the email address.
              For information of ORCID, see: https://orcid.org/about
  --pubmed-by-id  - add publications by PubMed IDs
      The details will be fetched from PubMed.
  --pubmed-by-query  - add publications by querying PubMed
      eg. 'pombe OR "fission yeast"'
  --session - create a session for a publication
  --sessions-from-json - create a session from a JSON file

File formats
~~~~~~~~~~~~

--sessions-from-json:

  For a description of the <json_file_name> argument, see:
    https://github.com/pombase/canto/wiki/JSON-Import-Format

  <curator_email_address> - each new session will have this user as its curator

  <default_organism_taxonid> - this is the organism to use for each genotype will
                               created for alleles in the JSON file

  If $0 is called using "canto_docker" the JSON file can be read from the
  "import_export" directory.  eg.
     ./canto/script/canto_docker /import_export/session_data.json curator\@pombase.org 4896

|;

}

if ($do_help) {
  usage();
}

if ($add_cvterm && (@ARGV < 2 || @ARGV > 4)) {
  usage("--cvterm needs 2, 3 or 4 arguments");
}

if ($add_person && (@ARGV < 4 || @ARGV > 5)) {
  usage("--person needs 4 or 5 arguments not " . scalar(@ARGV));
}

if ($add_session && @ARGV != 2) {
  usage("--session needs 2 or 3 arguments");
}

if ($add_sessions_from_json && @ARGV != 3) {
  usage("--sessions-from-json needs 3 arguments");
}

if ($add_organism && (@ARGV < 2 || @ARGV > 4)) {
  usage("--organism needs 2 or 3 arguments");
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
    my $orcid = shift @ARGV;
    my $role_name = shift @ARGV // "user";

    my $role = $load_util->find_cvterm(cv_name => 'Canto user types',
                                       name => $role_name);
    $load_util->get_person($name, $email_address, $orcid, '', $role);
  }

  if ($add_session) {
    my $pubmedid = shift @ARGV;
    # use the Person added by the add_person code
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

  if ($add_organism) {
    my $scientific_name = shift @ARGV;
    my $taxon_id = shift @ARGV;
    my $common_name = shift @ARGV;

    my $load_util = Canto::Track::LoadUtil->new(schema => $schema);
    my $guard = $schema->txn_scope_guard;
    $load_util->get_organism($scientific_name, $taxon_id, $common_name);
    $guard->commit unless $dry_run;
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

if ($add_sessions_from_json) {
  my $file_name = shift @ARGV;
  # use the Person added by the add_person code

  if (!-f $file_name) {
    die "file not found ($file_name) - exiting\n";
  }

  my $email_address = shift @ARGV;
  my $taxonid = shift @ARGV;

  my ($new_sessions, $updated_sessions) =
    $load_util->create_sessions_from_json($config, $file_name, $email_address, $taxonid);

  print "created ", scalar(@$new_sessions), " sessions\n";
  print "updated ", scalar(@$updated_sessions), " sessions\n";
}
