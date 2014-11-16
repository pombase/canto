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

use feature qw(state);

use Canto::Track;

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

 Usage   : my $organism = $load_util->get_organism($genus, $species);
 Function: Find or create, and then return the organism matching the arguments
 Args    : the genus and species of the new organism
 Returns : The found or new organism

=cut
sub get_organism
{
  my $self = shift;

  my $genus = shift;
  my $species = shift;
  my $taxonid = shift;

  croak "no taxon id supplied" unless $taxonid;

  my $schema = $self->schema();

  return $schema->resultset('Organism')->find_or_create(
      {
        genus => $genus,
        species => $species,
        organismprops => [ { value => $taxonid,
                             type => { name => 'taxon_id' },
                             rank => 0 } ]
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

 Usage   : my $dbxref = $load_util->get_dbxref($db, $dbxref_acc);
 Function: Find or create, and then return the object matching the arguments
 Args    : $termid - the term ID in the form "DB:ACCESSION"
 Returns : The new dbxref object

=cut
sub get_dbxref_by_accession
{
  my $self = shift;
  my $termid = shift;
  my $term_name = shift;

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

  my $db = $self->get_db($db_name);
  my $dbxref = $self->_create_dbxref($db, $accession);

  $self->cache()->{dbxref}->{$key} = $dbxref;

  return $dbxref;
}

=head2 get_cvterm

 Usage   : my $cvterm = $load_util->get_cvterm(cv_name => $cv_name,
                                               term_name => $term_name,
                                               ontologyid => $ontologyid,
                                               definition => $definition);
 Function: Find or create, and then return the object matching the arguments.
           The result is cached using the cv_name and term_name.
 Args    : cv_name - the Cv name
           term_name - the cvterm name
           ontologyid - the id in the ontology, eg. "GO:0001234"
           definition - the term definition
           alt_ids - an array ref of alternate ontology IDs for this
                     term
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

  my $key = "$cv_name--$term_name";

  my $cvterm_cache = $self->cache()->{cvterm};

  my $cached_cvterm = $cvterm_cache->{$key};

  if (defined $cached_cvterm) {
    return $cached_cvterm;
  }

  my $definition = $args{definition};
  my $is_relationshiptype = $args{is_relationshiptype} // 0;
  my $is_obsolete = $args{is_obsolete} // 0;

  my $dbxref = $self->get_dbxref_by_accession($ontologyid, $term_name);

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

  my $cvterm =
    $self->schema()->resultset('Cvterm')->find_or_create({
      %create_args
    });

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

 Usage   : my $person = $load_util->get_person($name, $email_address,
                                               $role_cvterm);
 Function: Find or create, and then return the object matching the arguments
 Args    : $name - the Person full name
           $email_address - the email address
           $role_cvterm - a cvterm from the user types cv
 Returns : The new person object

=cut
sub get_person
{
  my $self = shift;
  my $name = shift;
  my $email_address = shift;
  my $role_cvterm = shift;
  my $password = shift;

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

  my $hashed_password = sha1_base64($password);

  return $schema->resultset('Person')->find_or_create(
      {
        name => $name,
        email_address => $email_address,
        password => $hashed_password,
        role => $role_cvterm,
      });
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

1;
