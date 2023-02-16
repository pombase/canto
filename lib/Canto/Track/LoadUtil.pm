package Canto::Track::LoadUtil;

=head1 NAME

Canto::Track::LoadUtil -

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::LoadUtil

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use Carp;
use Moose;
use Digest::SHA qw(sha1_base64);
use Try::Tiny;
use JSON;

use feature qw(state);

use Package::Alias PubmedUtil => 'Canto::Track::PubmedUtil';

use Canto::Curs::GeneManager;
use Canto::Curs::AlleleManager;
use Canto::Curs::GenotypeManager;
use Canto::Curs::Utils;

use Canto::Track;

use Canto::Curs 'EXTERNAL_NOTES_KEY';

has 'schema' => (
  is => 'ro',
  isa => 'Canto::TrackDB',
  required => 1,
);

has 'default_db_name' => (
  is => 'ro'
);

has 'preload_cache' => (
  is => 'ro',
);

has 'cache' => (
  is => 'ro', init_arg => undef,
  lazy_build => 1,
);

sub _build_cache
{
  my $self = shift;

  my $cache = {
    cv => {},
    cvterm => {},
    dbxref => {},
  };

  if ($self->preload_cache()) {
    $self->_preload_dbxref_cache($cache);
  }

  return $cache;
}

=head2 get_organism

 Usage   : my $organism = $load_util->get_organism($scientific_name, $taxonid);
       OR: my $organism = $load_util->get_organism($scientific_name, $taxonid, $common_name);
 Function: Find or create, and then return the organism matching the arguments
 Returns : The found or new organism

=cut
sub get_organism
{
  my $self = shift;

  my $scientific_name = shift;
  my $taxonid = shift;
  my $common_name = shift;

  croak "no taxon id supplied" unless $taxonid;

  croak "taxon id not a number: $taxonid" unless $taxonid =~ /^\d+$/;

  my $schema = $self->schema();

  my $new_org =
    $schema->resultset('Organism')->find_or_create(
      {
        scientific_name => $scientific_name,
        organismprops => [ { value => $taxonid,
                             type => { name => 'taxon_id' },
                             rank => 0 } ]
      });

  if ($common_name && !defined $new_org->common_name()) {
    $new_org->common_name($common_name);
    $new_org->update();
  }

  return $new_org;
}

=head2 find_organism_by_taxonid

 Usage   : my $organism = $load_util->find_organism_by_taxonid($taxonid);
 Function: Find and return the organism with the given taxonid
 Returns : the organism object or undef

=cut
sub find_organism_by_taxonid
{
  my $self = shift;

  state $cache = {};

  my $taxonid = shift;

  croak "no taxon id supplied" unless $taxonid;

  if ($taxonid !~ /^\d+$/) {
    die qq(taxon ID "$taxonid" isn't numeric\n);
  }

  if ($cache->{$taxonid}) {
    return $cache->{$taxonid};
  }

  my $schema = $self->schema();

  my $organismprop_rs = $schema->resultset('Organismprop')
    ->search({'type.name' => 'taxon_id', 'me.value' => $taxonid},
             { join => 'type', prefetch => 'organism' });

  my $prop = $organismprop_rs->next();

  if ($prop) {
    my $organism = $prop->organism();
    $cache->{$taxonid} = $organism;
    return $organism;
  }

  return undef;
}

=head2 get_strain

 Usage   : my $strain = $load_util->get_strain($organism_obj, $strain);
 Function: Find or create, and then return a new strain object
 Args    : a organism object and the strain description

=cut
sub get_strain
{
  my $self = shift;
  my $organism = shift;
  my $strain = shift;

  croak "no strain supplied" unless $strain;

  my $schema = $self->schema();

  return $schema->resultset('Strain')->find_or_create(
      {
        organism_id => $organism->organism_id(),
        strain_name => $strain,
      });
}

=head2 find_cv

 Usage   : my $cv = $load_util->find_cv($cv_name);
 Function: Find and return the cv object matching the arguments
 Args    : $cv_name - the cv name
 Returns : The CV or calls die()

=cut
sub find_cv
{
  my $self = shift;
  my $cv_name = shift;

  my $schema = $self->schema();

  croak "no cv name supplied" unless defined $cv_name;

  my $cv_cache = $self->cache()->{cv};

  my $cv = $cv_cache->{$cv_name};

  if (defined $cv) {
    return $cv;
  }

  $cv = $schema->resultset('Cv')->find(
      {
        name => $cv_name
      });

  if (defined $cv) {
    $cv_cache->{$cv_name} = $cv;

    return $cv;
  } else {
    croak "no CV found for: $cv_name";
  }
}

=head2 find_or_create_cv

 Usage   : my $cv = $load_util->find_or_create_cv($cv_name);
 Function: Find or create, and then return the cv object matching the arguments.
           The Cv object is cached
 Args    : $cv_name - the cv name
 Returns : The new CV

=cut
sub find_or_create_cv
{
  my $self = shift;
  my $cv_name = shift;

  if (!defined $cv_name) {
    croak "no cv name passed to find_or_create_cv()";
  }

  if (exists $self->cache()->{cv}->{$cv_name}) {
    return $self->cache()->{cv}->{$cv_name};
  } else {
    my $cv = $self->schema()->resultset('Cv')->find_or_create(
      {
        name => $cv_name
      });
    $self->cache()->{cv}->{$cv_name} = $cv;
    return $cv;
  }
}


=head2 find_db

 Usage   : my $db = $load_util->find_db()
 Function: Find then return the db object for the db_name
 Args    : db_nam
 Returns : the Db object

=cut
sub find_db
{
  my $self = shift;
  my $db_name = shift;

  my $schema = $self->schema();

  my $db = $schema->resultset('Db')->find(
      {
        name => $db_name,
      });

  if (defined $db) {
    return $db;
  } else {
    croak "no Db found for $db_name";
  }
}

=head2 find_dbxref

 Usage   : my $dbxref = $load_util->find_dbxref()
 Function: Find then return the dbxref object matching the arguments
 Args    : termid - "db_name:accession" eg. GO:0055085
 Returns : the Dbxref object

=cut
sub find_dbxref
{
  my $self = shift;
  my $termid = shift;

  my ($db_name, $dbxref_acc) = $termid =~ /^(.*?):(.*)/;

  if (!defined $db_name) {
    croak qq(dbxref "$termid" not in the form: <DB_NAME>:<ACCESSION>);
  }

  my $schema = $self->schema();

  my @dbxrefs = $schema->resultset('Db')->search({ name => $db_name })
    ->search_related('dbxrefs', { accession => $dbxref_acc })->all();

  if (@dbxrefs > 1) {
    croak "internal error: looking up $termid returned more than one result";
  }

  if (@dbxrefs == 1) {
    return $dbxrefs[0];
  } else {
    croak "no Dbxref found for $termid";
  }
}

=head2 find_cvterm

 Usage   : my $cvterm = $load_util->find_cvterm(cv => $cv,
                                                name => $cvterm_name);
 Function: Find and return the cvterm object matching the arguments
 Args    : name - the cvterm name
           cv - the Cv object
 Returns : The Cvterm or calls die()

=cut
sub find_cvterm
{
  my $self = shift;
  my %args = @_;

  my $cv = $args{cv};

  if (defined $args{cv_name}) {
    if (defined $cv) {
      croak "don't pass cv and cv_name";
    }
    $cv = $self->find_cv($args{cv_name});
  }

  my $schema = $self->schema();

  croak "no cvterm name passed" unless defined $args{name};

  my $cvterm = $schema->resultset('Cvterm')->find(
      {
        cv_id => $cv->cv_id(),
        name => $args{name}
      });

  if (defined $cvterm) {
    return $cvterm;
  } else {
    croak "no cvterm found for: $args{name}";
  }
}

=head2 get_db

 Usage   : my $db = $load_util->get_db($db_name);
 Function: Find or create, and then return the db object matching the arguments
 Returns : The new db object

=cut
sub get_db
{
  my $self = shift;
  my $db_name = shift;

  if (exists $self->cache()->{db}->{$db_name}) {
    return $self->cache()->{db}->{$db_name};
  }

  my $schema = $self->schema();

  my $db = $schema->resultset('Db')->find_or_create(
      {
        name => $db_name
      });

  $self->cache()->{db}->{$db_name} = $db;

  return $db;
}

sub _create_dbxref
{
  my $self = shift;
  my $db = shift;
  my $dbxref_acc = shift;

  my $schema = $self->schema();

  my $dbxref = $schema->resultset('Dbxref')->create(
      {
        accession => $dbxref_acc,
        db => $db
      });

  my $termid = $db->name() . ':' .$dbxref_acc;

  $self->cache()->{dbxref}->{$termid} = $dbxref;

  return $dbxref;
}

sub _preload_dbxref_cache
{
  my $self = shift;
  my $cache = shift;

  my $dbxref_rs = $self->schema()->resultset('Dbxref')
    ->search({}, { prefetch => 'db' });

  for my $dbxref ($dbxref_rs->all()) {
    $cache->{dbxref}->{$dbxref->db_accession()} = $dbxref;
  }
}

=head2 get_dbxref_by_accession

 Usage   : my $dbxref = $load_util->get_dbxref($db, $dbxref_acc, $term_name,
                                               $create_only);
 Function: Find or create, and then return the object matching the arguments
 Args    : $dbxref_acc - the term ID eg. "GO:0055085"
           $term_name - the term name, used as the accession if the $dbxref_acc
                        is undef with "Canto" as the db name
           $create_only - if true, don't try to find() the dbxref before
                          creating, assume it's new
 Returns : The new dbxref object

=cut
sub get_dbxref_by_accession
{
  my $self = shift;
  my $termid = shift;
  my $term_name = shift;
  my $create_only = shift;

  my $db_name;
  my $accession;

  if (defined $termid) {
    if ($termid =~ /(.*):(.*)/) {
      $db_name = $1;
      $accession = $2
    } else {
      $db_name = 'Canto';
      $accession = $termid;
    }
  } else {
    if (defined $term_name) {
      $db_name = 'Canto';
      $accession = $term_name;
    } else {
      croak "no termid or term_name passed to get_dbxref_by_accession()";
    }
  }

  my $key = "$db_name:$accession";

  if (!$create_only) {
    if (exists $self->cache()->{dbxref}->{$key}) {
      return $self->cache()->{dbxref}->{$key};
    } else {
      my $dbxref = undef;

      try {
        $dbxref = $self->find_dbxref($key);
        $self->cache()->{dbxref}->{$key} = $dbxref;
      } catch {
        # fall through - dbxref not in DB
      };

      if (defined $dbxref) {
        return $dbxref;
      }
    }
  }
  my $db = $self->get_db($db_name);
  my $dbxref = $self->_create_dbxref($db, $accession);

  $self->cache()->{dbxref}->{$key} = $dbxref;

  return $dbxref;
}

=head2 get_cvterm

 Usage   : my $cvterm = $load_util->get_cvterm(cv_name => $cv_name,
                                               term_name => $term_name,
                                               ontologyid => $ontologyid,
                                               definition => $definition,
                                               create_only => $create_only);
 Function: Find or create, and then return the object matching the arguments.
           The result is cached using the cv_name and term_name.
 Args    : cv_name - the Cv name
           term_name - the cvterm name
           ontologyid - the id in the ontology, eg. "GO:0001234"
           definition - the term definition
           alt_ids - an array ref of alternate ontology IDs for this
                     term
           create_only - if true, don't try to find() the cvterm before
                         creating, assume it's new
 Returns : The new cvterm object

=cut
sub get_cvterm
{
  my $self = shift;

  my %args = @_;

  my $cv_name = $args{cv_name};
  my $cv = $args{cv};

  if (!defined $cv_name && !defined $cv) {
    croak "no cv_name or cv passed to get_cvterm()";
  }

  if (defined $cv) {
    $cv_name = $cv->name();
  } else {
    $cv = $self->find_or_create_cv($cv_name);
  }
  my $term_name = $args{term_name};

  if (!defined $term_name) {
    confess "no term name passed to get_cvterm() for $cv_name";
  }

  my $ontologyid = $args{ontologyid};
  my $create_only = $args{create_only} && $ontologyid;
  my $key = "$cv_name--$term_name";
  my $cvterm_cache = $self->cache()->{cvterm};
  my $cached_cvterm = $cvterm_cache->{$key};

  if (defined $cached_cvterm) {
    return $cached_cvterm;
  }

  my $definition = $args{definition};
  my $is_relationshiptype = $args{is_relationshiptype} // 0;
  my $is_obsolete = $args{is_obsolete} // 0;

  my $dbxref = $self->get_dbxref_by_accession($ontologyid, $term_name, $create_only);

  my $schema = $self->schema();

  my %create_args = (
    name => $term_name,
    cv => $cv,
    dbxref => $dbxref,
    is_relationshiptype => $is_relationshiptype,
    is_obsolete => $is_obsolete,
  );

  if (defined $definition) {
    $create_args{definition} = $definition;
  }

  my $cvterm;

  if ($create_only) {
    $cvterm = $self->schema()->resultset('Cvterm')->create({
      %create_args
    });
  } else {
    $cvterm = $self->schema()->resultset('Cvterm')->find_or_create({
      %create_args
    });
  }

  if (defined $args{alt_ids}) {
    for my $alt_id (@{$args{alt_ids}}) {
      my $alt_dbxref = $self->get_dbxref_by_accession($alt_id);

      $self->schema()->resultset('CvtermDbxref')->create({
        dbxref_id => $alt_dbxref->dbxref_id(),
        cvterm_id => $cvterm->cvterm_id(),
      });
    }
  }

  $cvterm_cache->{$key} = $cvterm;

  return $cvterm;
}

=head2 get_pub

 Usage   : my $pub = $load_util->get_pub($uniquename);
 Function: Find or create, and then return the object matching the arguments
 Args    : $uniquename - the PubMed ID
           $load_type - a cvterm from the "Publication load types" CV that
                        records who is loading this publication
 Returns : The new pub object

=cut
sub get_pub
{
  my $self = shift;
  my $uniquename = shift;
  my $load_type = shift;

  if (!defined $load_type) {
    croak("no load_type passed to get_pub()");
  }

  my $schema = $self->schema();

  state $load_type_cv = $self->find_cv('Canto publication load types');
  state $load_type_term = $self->find_cvterm(cv => $load_type_cv,
                                             name => $load_type);

  state $pub_type_cv = $self->find_cv('Canto publication type');
  state $pub_type = $self->find_cvterm(cv => $pub_type_cv,
                                       name => 'unknown');

  state $pub_status_cv = $self->find_cv('Canto publication triage status');
  state $pub_new_status = $self->find_cvterm(cv => $pub_status_cv,
                                             name => 'New');

  return $schema->resultset('Pub')->find_or_create(
      {
        uniquename => $uniquename,
        type => $pub_type,
        triage_status => $pub_new_status,
        load_type => $load_type_term,
      });
}

=head2 get_lab

 Usage   : my $lab = $load_util->get_lab($lab_head_obj);
 Function: Find or create, and then return the object matching the arguments
 Args    : $lab_head_obj - the Person object for the lab head
 Returns : The new lab object

=cut
sub get_lab
{
  my $self = shift;
  my $lab_head = shift;

  my $schema = $self->schema();

  my $lab_head_name = $lab_head->name();

  (my $lab_head_surname = $lab_head_name) =~ s/.* //;

  return $schema->resultset('Lab')->find_or_create(
      {
        lab_head => $lab_head,
        name => "$lab_head_surname Lab"
      });
}

=head2 get_person

 Usage   : my $person = $load_util->get_person($name, $email_address, $role_cvterm,
                                               $password, $orcid);
 Function: Find or create, and then return the object matching the arguments
 Args    : $name - the Person full name
           $email_address - the email address
           $orcid
           $role_cvterm - a cvterm from the user types cv
 Returns : The new person object

=cut
sub get_person
{
  warn "@_";

  my $self = shift;
  my $name = shift;
  my $email_address = shift;
  my $role_cvterm = shift;
  my $password = shift;
  my $orcid = shift;

  my $schema = $self->schema();

  if (!defined $email_address || length $email_address == 0) {
    die "email not set for $name\n";
  }
  if (!defined $name || length $name == 0) {
    die "name not set for $email_address\n";
  }
  if (!defined $password) {
    die "no password passed to get_person()\n";
  }
  if (!$password) {
    die "empty password passed to get_person()\n";
  }
  if (!$role_cvterm) {
    die "no role passed to get_person()\n";
  }

  my $hashed_password = sha1_base64($password);

  my %args = (
    name => $name,
    email_address => $email_address,
    password => $hashed_password,
    role => $role_cvterm,
  );

  if ($orcid) {
    $orcid =~ s|(?:(?:https?://)orcid.org/)||;
    $args{orcid} = $orcid;
  }

  return $schema->resultset('Person')->find_or_create(\%args);
}

=head2 create_user_session

 Usage   : my ($curs, $cursdb, $curator) =
             $load_util->create_user_session($config, $pubmedid, $email_address);
 Function: Create a session for a publication and set the curator.  If the
           publication has no corresponding_author, set it to the curator.
 Args    : $config - the Config object
           $pub_uniquename - a PubMed ID with optional "PMID:" prefix
           $email_address - the email address of the user to curate the session
 Return  : The Curs object from the Track database, the CursDB object and the
           Person object for the email_address.

=cut
sub create_user_session
{
  my $self = shift;
  my $config = shift;
  my $pub_uniquename = shift;
  my $email_address = shift;

  if ($pub_uniquename =~ /^\d+$/) {
    $pub_uniquename = "PMID:$pub_uniquename";
  }

  my ($curs, $cursdb) =
    Canto::Track::create_curs($config, $self->schema(), $pub_uniquename);

  my $person = $self->schema()->resultset('Person')->find_or_create({
    email_address => $email_address,
  });

  my $curator_manager = Canto::Track::CuratorManager->new(config => $config);

  $curator_manager->set_curator($curs->curs_key(), $email_address);

  return ($curs, $cursdb, $person);
}

=head2 load_pub_from_pubmed

 Usage   : my ($pub, $err_message) = $load_util->load_pub_from_pubmed($config, $pubmed_id);
 Function: Query PubMed for the details of the given publication and store
           the results in the TrackDB
 Args    : $config - a Config file
           $pubmed_id - the ID
 Returns : ($pub_object, undef) on success
           (undef, "some error message") on failure

=cut

sub load_pub_from_pubmed
{
  my $self = shift;
  my $config = shift;
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

  my $pub = $self->schema()->resultset('Pub')->find({ uniquename => $pubmedid });

  if (defined $pub) {
    return ($pub, undef);
  } else {
    my $xml = PubmedUtil::get_pubmed_xml_by_ids($config, $raw_pubmedid);

    my $count = PubmedUtil::load_pubmed_xml($self->schema(), $xml, 'user_load');

    if ($count) {
      $pub = $self->schema()->resultset('Pub')->find({ uniquename => $pubmedid });
      return ($pub, undef);
    } else {
      (my $numericid = $pubmedid) =~ s/.*://;
      my $message = "No publication found in PubMed with ID: $numericid";
      return (undef, $message);
    }
  }
}


sub _update_allele_details
{
  my ($existing_allele, $json_allele_details, $db_genes) = @_;

  my $session_updated = 0;

  if (($existing_allele->name() // '') ne ($json_allele_details->{name} // '')) {
    $existing_allele->name($json_allele_details->{name});
    print "updated allele name of ", ($json_allele_details->{name} // ''), "\n";
    $session_updated = 1;
  }

  if (($existing_allele->comment() // '') ne ($json_allele_details->{comment} // '')) {
    $existing_allele->comment($json_allele_details->{comment});
    print "updated comment of allele ", ($json_allele_details->{name} // ''), "\n";
    $session_updated = 1;
  }

  if ($json_allele_details->{type} &&
        $existing_allele->type() ne $json_allele_details->{type}) {
    $existing_allele->type($json_allele_details->{type});
    $session_updated = 1;
  }

  my $allele_gene_uniquename = $json_allele_details->{gene};

  if ($allele_gene_uniquename && $existing_allele->gene() &&
        $existing_allele->gene()->primary_identifier() ne $allele_gene_uniquename) {
    my $new_gene = $db_genes->{$allele_gene_uniquename};

    print qq|gene for "|, $existing_allele->primary_identifier(),
      qq|" changed from "|, $existing_allele->gene()->primary_identifier(),
      qq| to "$allele_gene_uniquename"\n|;

    $existing_allele->gene($new_gene);
    $session_updated = 1;
  }

  if ($session_updated) {
    $existing_allele->update();
  }

  return $session_updated;
}


=head2 create_sessions_from_json

 Usage   : my ($curs, $cursdb, $curator) =
             $load_util->create_sessions_from_json($config, $file_name, $curator_email_address,
                                                   $default_organism_taxonid);
 Function: Create sessions for the JSON data in the given file and set the curator.
 Args    : $config - the Config object
           $file_name - the JSON file,
                        see: https://github.com/pombase/canto/wiki/JSON-Import-Format
           $curator_email_address - the email address of the user to curate the session,
                                    the user must exist in the database
           $default_organism_taxonid - the taxon ID of the organism to attach to any
                                       single allele genotypes that we create
 Return  : The Curs object from the Track database, the CursDB object and the
           Person object for the curator_email_address.

=cut
sub create_sessions_from_json
{
  my $self = shift;
  my $config = shift;
  my $file_name = shift;
  my $curator_email_address = shift;
  my $default_organism_taxonid = shift;

  my $json_text = do {
   open(my $json_fh, "<:encoding(UTF-8)", $file_name)
      or die("Can't open \$filename\": $!\n");
   local $/;
   <$json_fh>
 };

  my $gene_lookup = Canto::Track::get_adaptor($config, 'gene');
  my $sessions_data = JSON->new->utf8(0)->decode($json_text);

  my $curator_manager = Canto::Track::CuratorManager->new(config => $config);

  my $curator = $self->schema()->resultset('Person')->find({
    email_address => $curator_email_address,
  });

  if (!$curator) {
    die qq|can't find user with email address "$curator_email_address" in the database\n|;
  }

  # disable connection caching so we don't run out of file descriptors
  my $connect_options = { cache_connection => 0 };

  my @new_sessions = ();
  my @updated_sessions = ();

  # load the publication in batches in advance
  print "loading publications from PubMed\n";
  PubmedUtil::load_by_ids($config, $self->schema(), [keys %$sessions_data], 'admin_load');

  my $success = 0;
  my ($curs, $cursdb, $pub) = ();
  my $using_existing_session = undef;

  my $triage_status_cv = $self->find_cv('Canto publication triage status');
  my $curation_priority_cv = $self->find_cv('Canto curation priorities');

  my $session_updated = 0;

  print "Creating sessions\n";

 PUB:
  while (my ($pub_uniquename, $session_data) = each %$sessions_data) {
    $success = 0;

    $pub = undef;
    $curs = undef;
    $cursdb = undef;
    $using_existing_session = 0;
    $session_updated = 0;

    my $external_notes = $session_data->{comment};

    my $new_allele_count = 0;

    my $error_message;
    # the publication should be in the track DB at this point
    ($pub, $error_message) = $self->load_pub_from_pubmed($config, $pub_uniquename);

    if (!$pub) {
      die "can't get publication details for $pub_uniquename from PubMed:\n$error_message";
    }

    my $curs_rs = $pub->curs();

    if ($curs_rs->count() > 0) {
      if ($curs_rs->count() > 1) {
        die "more than one session for: $pub_uniquename\n";
      }
      $curs = $curs_rs->first();
      print "updating existing session ", $curs->curs_key(), " for $pub_uniquename\n";
      $using_existing_session = 1;
    }

    if ($using_existing_session) {
      $cursdb = Canto::Curs::get_schema_for_key($config, $curs->curs_key(),
                                                $connect_options);
    } else {
      ($curs, $cursdb) =
        Canto::Track::create_curs($config, $self->schema(), $pub, $connect_options);
    }

    my %existing_session_gene_uniquenames = ();
    my %existing_session_alleles_by_uniquenames = ();

    if ($using_existing_session) {
      my @existing_genes = $cursdb->resultset('Gene')->all();

      for my $existing_gene (@existing_genes) {
        $existing_session_gene_uniquenames{$existing_gene->primary_identifier()} = $existing_gene;
      }

      my @existing_alleles = $cursdb->resultset('Allele')->all();

      for my $existing_allele (@existing_alleles) {
        $existing_session_alleles_by_uniquenames{$existing_allele->primary_identifier()} = $existing_allele;
      }
   }

    my $alleles_from_json = $session_data->{alleles};
    my $genes_from_json = $session_data->{genes};

    # do some checks for consistency
    if ($using_existing_session) {
      my %secondary_gene_identifier_counts = ();

      for my $gene_details (values %$genes_from_json) {
        for my $secondary_identifier (@{$gene_details->{secondary_identifiers} // []}) {
          $secondary_gene_identifier_counts{$secondary_identifier}++;
        }
      }

      for my $secondary_identifier (keys %secondary_gene_identifier_counts) {
        if ($secondary_gene_identifier_counts{$secondary_identifier} > 1 &&
              $existing_session_gene_uniquenames{$secondary_identifier}) {
          print "two genes in the JSON file have a secondary identifier ",
            "($secondary_identifier) in common and there is a gene with that ",
            "identifier in the session - skipping $pub_uniquename\n";
          next PUB;
        }
      }

      my %secondary_allele_identifier_counts = ();

      for my $allele_details (values %$alleles_from_json) {
        for my $secondary_identifier (@{$allele_details->{secondary_identifiers} // []}) {
          $secondary_allele_identifier_counts{$secondary_identifier}++;
        }
      }

      for my $secondary_identifier (keys %secondary_allele_identifier_counts) {
        if ($secondary_allele_identifier_counts{$secondary_identifier} > 1 &&
              $existing_session_alleles_by_uniquenames{$secondary_identifier}) {
          print "two alleles in the JSON file have a secondary identifier ",
            "($secondary_identifier) in common and there is a allele with that ",
            "identifier in the session - skipping $pub_uniquename\n";
          next PUB;
        }
      }
    }

    my @gene_lookup_results = ();

  GENE:
    while (my ($json_gene_uniquename, $json_gene_details) = each %$genes_from_json) {
      if ($using_existing_session) {
        if ($existing_session_gene_uniquenames{$json_gene_uniquename}) {
          next GENE;
        }

        $session_updated = 1;

        for my $secondary_identifier (@{$json_gene_details->{secondary_identifiers} || []}) {
          my $existing_session_gene = $existing_session_gene_uniquenames{$secondary_identifier};

          if ($existing_session_gene) {
            $existing_session_gene->primary_identifier($json_gene_uniquename);
            $existing_session_gene->update();
            delete $existing_session_gene_uniquenames{$secondary_identifier};
            $existing_session_gene_uniquenames{$json_gene_uniquename} = $existing_session_gene;
            next GENE;
          }
        }

        print "adding new gene to existing session: $json_gene_uniquename\n";
      }

      my $lookup_result = $gene_lookup->lookup([$json_gene_uniquename]);

      if (@{$lookup_result->{missing}} != 0) {
        print "no gene found in the database for ID $json_gene_uniquename, skipping $pub_uniquename\n";
        next PUB;
      }

      push @gene_lookup_results, $lookup_result;
    }

    my $allele_manager =
      Canto::Curs::AlleleManager->new(config => $config, curs_schema => $cursdb);
    my $genotype_manager =
      Canto::Curs::GenotypeManager->new(config => $config, curs_schema => $cursdb);
    my $gene_manager =
      Canto::Curs::GeneManager->new(config => $config, curs_schema => $cursdb);

    if (!$using_existing_session) {
      $curator_manager->set_curator($curs->curs_key(), $curator_email_address);
    }

    if (!$pub->corresponding_author()) {
      $pub->corresponding_author($curator);
      $pub->update();
    }

    my %db_genes = ();

    @gene_lookup_results = sort {
      my $a_display_name =
        lc $a->{found}->[0]->{primary_name} || $a->{found}->[0]->{primary_identifier};
      my $b_display_name =
        lc $b->{found}->[0]->{primary_name} || $b->{found}->[0]->{primary_identifier};
      $a_display_name cmp $b_display_name;
    } @gene_lookup_results;

    for my $lookup_result (@gene_lookup_results) {
      my %result = $gene_manager->create_genes_from_lookup($lookup_result);

      while (my ($result_uniquename, $result_gene) = each %result) {
        $db_genes{$result_uniquename} = $result_gene;
      }
    }

    for my $existing_gene_uniquename (keys %existing_session_gene_uniquenames) {
      $db_genes{$existing_gene_uniquename} =
        $existing_session_gene_uniquenames{$existing_gene_uniquename};
    }

    if ($alleles_from_json) {
      my @genotype_details = ();

    ALLELE:
      while (my ($allele_uniquename, $json_allele_details) = each %$alleles_from_json) {
        my $allele_gene_uniquename = $json_allele_details->{gene};

        if ($json_allele_details->{type} ne 'aberration') {
          if (!defined $allele_gene_uniquename) {
            print qq|no "gene" field in details for $allele_uniquename in $pub_uniquename\n|;
            next PUB;
          }

          my $gene = $db_genes{$allele_gene_uniquename};
          if (!defined $gene) {
            print qq|error while loading $pub_uniquename: gene $allele_gene_uniquename (from allele $allele_uniquename) missing from the "genes" section\n|;
            next PUB;
          }
        }

        if ($using_existing_session) {
          if ($existing_session_alleles_by_uniquenames{$allele_uniquename}) {
            my $existing_allele = $existing_session_alleles_by_uniquenames{$allele_uniquename};
            if (_update_allele_details($existing_allele, $json_allele_details, \%db_genes)) {
              $session_updated = 1;
            }
            next;
          }

          $session_updated = 1;

          for my $secondary_identifier (@{$json_allele_details->{secondary_identifiers} || []}) {

            my $existing_session_allele =
              $existing_session_alleles_by_uniquenames{$secondary_identifier};

            if ($existing_session_allele) {
              $existing_session_allele->primary_identifier($allele_uniquename);
              $existing_session_allele->update();
              _update_allele_details($existing_session_allele, $json_allele_details, \%db_genes);
              next ALLELE;
            }
          }

          print "adding new allele to existing session: $allele_uniquename\n";
        }

        $json_allele_details->{source_identifier} = $allele_uniquename;

        my $gene = undef;

        if ($json_allele_details->{type} ne 'aberration') {
          $gene = $db_genes{$allele_gene_uniquename};

          $json_allele_details->{gene_id} = $gene->gene_id();
        }

        $json_allele_details->{synonyms} = [map {
          {
            edit_status => 'existing',
            synonym => $_,
          }
        } @{$json_allele_details->{synonyms} // []}];

        my $gene_display_name;

        if ($gene) {
          my $gene_proxy =
            Canto::Curs::GeneProxy->new(config => $config, cursdb_gene => $gene);
          $gene_display_name = $gene_proxy->display_name();
        } else {
          $gene_display_name = "(aberration)";
        }

        delete $json_allele_details->{gene};

        my $allele_display_name =
          Canto::Curs::Utils::make_allele_display_name($config,
                                                       $json_allele_details->{name},
                                                       $json_allele_details->{description},
                                                       $json_allele_details->{type});

        $new_allele_count++;

        push @genotype_details, {
          allele => $json_allele_details,
          allele_display_name => lc $allele_display_name,
          gene_display_name => lc $gene_display_name,
          identifier => undef,
          taxonid => $default_organism_taxonid,
        };
      }

      @genotype_details = sort {
        $a->{gene_display_name} cmp $b->{gene_display_name}
          ||
        $a->{allele_display_name} cmp $b->{allele_display_name};
      } @genotype_details;

      for my $genotype_details (@genotype_details) {
        my $genotype =
          $genotype_manager->make_genotype(undef, undef, [$genotype_details->{allele}],
                                           $genotype_details->{taxonid},
                                           $genotype_details->{identifier}, undef,
                                           $genotype_details->{comment});
        my $genotype_allele = ($genotype->alleles()->all())[0];

        my $allele_source_identifier = $genotype_details->{allele}->{source_identifier};
        $genotype_allele->primary_identifier($allele_source_identifier);
        $genotype_allele->update();
      }
    }

    $success = 1;

    my $triage_status = $session_data->{triage_status};

    if ($triage_status) {
      my $triage_status_cvterm = $self->find_cvterm(cv => $triage_status_cv,
                                                    name => $triage_status);

      $pub->triage_status($triage_status_cvterm);
      $pub->update();
    }

    my $curation_priority = $session_data->{curation_priority};

    if ($curation_priority) {
      my $curation_priority_cvterm = $self->find_cvterm(cv => $curation_priority_cv,
                                                        name => $curation_priority);

      $pub->curation_priority($curation_priority_cvterm);
      $pub->update();
    }

    if ($using_existing_session) {
      # check for alleles that are in the Canto database but aren't in input file
    ALLELE:
      for my $allele ($cursdb->resultset('Allele')->all()) {
        my $allele_primary_identifier = $allele->primary_identifier();
        if (!exists $alleles_from_json->{$allele_primary_identifier}) {
          print "allele $allele_primary_identifier - ",
            $allele->long_identifier($config),
            " is in the Canto database is not in the JSON input for session: ",
            $curs->curs_key(), "\n";

          my @allele_genotypes = $allele->genotypes()->all();

          map {
            my $genotype = $_;

            if ($genotype->annotations()->count() > 0) {
              print "  can't remove $allele_primary_identifier - one or more ",
                "genotypes containing this allele has annotation\n";
              next ALLELE;
            }
            if ($genotype->metagenotypes() > 0) {
              print "  can't remove $allele_primary_identifier - one or more ",
                "genotypes containing this allele are part of an interaction ",
                "or metagenotype\n";
              next ALLELE;
            }
          } @allele_genotypes;

          $session_updated = 1;
          map {
            my $genotype = $_;
            $genotype->delete();
          } @allele_genotypes;
          $allele->allele_notes()->delete();
          $allele->allelesynonyms()->delete();
          $allele->delete();
          print "  - successfully deleted from the Canto database\n";
        }
      }

      # check for genes
    GENE:
      for my $gene ($cursdb->resultset('Gene')->all()) {
        my $gene_primary_identifier = $gene->primary_identifier();
        if (!exists $genes_from_json->{$gene_primary_identifier}) {
          print "gene $gene_primary_identifier ",
            "is in the Canto database is not in the JSON input for session: ",
            $curs->curs_key(), "\n";

          my @gene_alleles = $gene->alleles();

          map {
            my $allele = $_;

            my @gene_allele_genotypes = $allele->genotypes()->all();

            map {
              my $genotype = $_;

              if ($genotype->annotations()->count() > 0) {
                print "  can't remove $gene_primary_identifier - one or more ",
                  "genotypes containing an allele from this gene has annotation\n";
                next GENE;
              }
              if ($genotype->metagenotypes() > 0) {
                print "  can't remove $gene_primary_identifier - one or more ",
                  "genotypes containing this allele from this gene are part of ",
                  "an interaction or metagenotype\n";
                next GENE;
              }

            } @gene_allele_genotypes;
          } @gene_alleles;

          $session_updated = 1;
          $gene->delete();
          print "  - successfully deleted from the Canto database\n";
        }
      }

      if ($new_allele_count > 0) {
        $session_updated = 1;
      } else {
        print "no new alleles adding to session: ", $curs->curs_key(), "\n";
      }
    }

    if ($external_notes) {
      my $curs_metadata_rs = $cursdb->resultset('Metadata');
      $curs_metadata_rs->update_or_create({ key => Canto::Curs->EXTERNAL_NOTES_KEY,
                                            value => $external_notes });
    }
  } continue {
    if ($session_updated) {
      push @updated_sessions, $curs;
    }

    if (!$using_existing_session) {
      if ($success) {
        push @new_sessions, $curs;
        print "created session: ", $curs->curs_key(), " pub: ", $pub->uniquename(),
          " for: $curator_email_address\n";
        $success = 0;
      } else {
        print "no session created for ", $pub->uniquename(), " due to an error\n";
        if (defined $curs) {
          Canto::Track::delete_curs($config, $self->schema(), $curs->curs_key());
        }
      }
    }
  }

  return (\@new_sessions, \@updated_sessions);
}

=head2 load_strains

 Usage   : $load_util->load_util($strain_file_name);
 Function: Load strains and strain synonyms from a file.  Existing strains are
           retained but synonyms are replaced.  The input file is comma
           separated with these columns:
             - taxon ID
             - species common name
             - strain name
             - synonyms - comma separated and quoted
 Returns : nothing

=cut

sub load_strains
{
  my $self = shift;
  my $config = shift;
  my $file_name = shift;

  open my $fh, '<', $file_name or die "can't open $file_name: $!";

  my $csv = Text::CSV->new({ blank_is_undef => 1, binary => 1, auto_diag => 1  });

  my %strains_by_name = ();
  my %strains_by_synonym = ();

  while (my $row = $csv->getline($fh)) {

    next if lc $row->[0] eq 'ncbitaxspeciesid' && $. == 1;

    my ($taxonid, $common_name, $strain_name, $synonyms) = @$row;

    if ($taxonid !~ /^\d+$/) {
      die qq(load failed - taxon ID in first column of line $. isn't an integer: $taxonid\n);
    }

    $strain_name =~ s/^\s+//;
    $strain_name =~ s/\s+$//;

    my $organism = $self->find_organism_by_taxonid($taxonid);

    if (!$organism) {
      die qq(load failed - no organism with taxon ID "$taxonid" found in the database\n);
    }

    my $strain = $self->get_strain($organism, $strain_name);

    my $name_key = "$taxonid:$strain_name";
    if (exists $strains_by_name{$name_key}) {
      die qq(load failed - strain name "$strain_name" for taxon $taxonid is duplicated in $file_name\n);
    } else {
      $strains_by_name{$name_key} = $strain;
    }

    $strain->strainsynonyms()->delete_all();

    if (defined $synonyms) {
      map {
        my $synonym = $_;
        $synonym =~ s/^\s+//;
        $synonym =~ s/\s+$//;
        $self->schema()->create_with_type('Strainsynonym', {
          strain => $strain,
          synonym => $synonym,
        });

        my $synonym_key = "$taxonid:$synonym";
        if (exists $strains_by_synonym{$synonym_key}) {
          if (@{$strains_by_synonym{$synonym_key}} == 1) {

            warn qq(Warning: strain synonym "$synonym" for strain "$strain_name" for taxon $taxonid is duplicated in $file_name\n);
          }

          # If there is more than one element in the array, any
          # strains in sessions we the name $synonym_key are prevented
          # from finding a track strain.
          # It needs manual intervention in that case.
          my $other_strains = $strains_by_synonym{$synonym_key};
          push @{$strains_by_synonym{$synonym_key}}, $strain;
        } else {
          $strains_by_synonym{$synonym_key} = [$strain];
        }

      } split /,/, $synonyms;
    }
  }

  my $curs_fix_proc = sub {
    my $curs = shift;
    my $curs_schema = shift;
    my $track_schema = shift;

    my $curs_strain_rs = $curs_schema->resultset('Strain')
      ->search({ track_strain_id => undef },
               { prefetch => 'organism' });
    while (defined (my $curs_strain = $curs_strain_rs->next())) {
      my $curs_organism = $curs_strain->organism();
      my $curs_strain_name = $curs_strain->strain_name();
      my $curs_taxon = $curs_organism->taxonid();
      my $name_key = $curs_taxon . ":$curs_strain_name";
      my $track_strain_by_name = $strains_by_name{$name_key};

      my $track_strains_by_synonym = $strains_by_synonym{$name_key};

      if (defined $track_strain_by_name && defined $track_strains_by_synonym) {
        my @all_strains = @$track_strains_by_synonym;
        warn qq(The strain "$name_key" in session ), $curs->curs_key(),
          " is ambiguous as there is a strain in the track database with that ",
          "name and also a strain synonym with that name.\n";
        warn qq(Strains of taxon $curs_taxon with "$curs_strain_name" as a synonym: ),
          (join ", ", map {
            $_->strain_name()
          } @all_strains), "\n";
      } else {
        if (defined $track_strains_by_synonym && @$track_strains_by_synonym > 1) {
          warn qq(The strain "$name_key" in session ), $curs->curs_key(),
            " is ambiguous as there is more than one strain in the track DB ",
            "with that name as a synonym.\n";
          warn qq(Strains of taxon $curs_taxon with "$curs_strain_name" as a synonym: ),
            (join ", ", map {
              $_->strain_name()
            } @$track_strains_by_synonym), "\n";
        } else {
          my $track_strain = $track_strain_by_name;
          if (!defined $track_strain) {
            if (defined $track_strains_by_synonym) {
              $track_strain = $track_strains_by_synonym->[0];
            }
          }

          if ($track_strain) {
            $curs_strain->strain_name(undef);
            $curs_strain->track_strain_id($track_strain->strain_id());
            $curs_strain->update();
          }
        }
      }
    }
  };

  Canto::Track::curs_map($config, $self->schema(), $curs_fix_proc);
}

1;
