package Canto::Track::OntologyLoad;

=head1 NAME

Canto::Track::OntologyLoad - Code for loading ontology information into a
                              TrackDB

=head1 SYNOPSIS

my $loader = Canto::Track::OntologyLoad->new(schema => $schema,
                                             default_db_name => 'PomBase');

my $index = Canto::Track::OntologyIndex->new(...);

$loader->load($obo_file_name, $index, ["exact", "narrow"]);

# finalise() must be called to store the new terms
$loader->finalise();

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::OntologyLoad

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

use Moose;
use Carp;

use Try::Tiny;

use GO::Parser;
use LWP::Simple;
use File::Temp qw(tempfile);

use Canto::Track::LoadUtil;

has 'schema' => (
  is => 'ro',
  isa => 'Canto::TrackDB',
  required => 1,
);

has 'load_schema' => (
  is => 'rw',
  init_arg => undef,
  isa => 'Maybe[Canto::TrackDB]',
);

has 'default_db_name' => (
  is => 'ro',
  required => 1,
);

has 'temp_file_name' => (
  is => 'rw',
  init_arg => undef
);

has 'relationships_to_load' => (
  is => 'ro',
  required => 1,
  isa => 'ArrayRef[Str]',
);

sub BUILD
{
  my $self = shift;

  # use load_schema as a temporary database for loading
  my ($fh, $temp_file_name) = tempfile();

  $self->temp_file_name($temp_file_name);

  my $dbi_connect_string =
    Canto::DBUtil::connect_string_for_file_name($temp_file_name);

  my $load_schema =
    Canto::TrackDB->cached_connect($dbi_connect_string, undef, undef, {});

  my $orig_dbh = $self->schema->storage()->dbh();
  my $load_dbh = $load_schema->storage()->dbh();

  Canto::DBUtil::copy_sqlite_database($orig_dbh, $load_dbh);

  $self->load_schema($load_schema);
}

sub _delete_term_by_cv
{
  my $schema = shift;
  my $cv_name = shift;
  my $delete_relations = shift;

  my $cv = $schema->resultset('Cv')->find(
    {
      name => $cv_name
    });

  if (!defined $cv) {
    # nothing to delete
    return;
  }

  my $cv_cvterms =
    $schema->resultset('Cvterm')->search({ is_relationshiptype => $delete_relations,
                                           cv_id => $cv->cv_id() });

  for my $related (qw(cvtermprop_cvterms cvtermsynonym_cvterms
                      cvterm_relationship_objects cvterm_relationship_subjects
                      cvterm_relationship_types)) {
    $cv_cvterms->search_related($related)->delete();
  }

  $cv_cvterms->search_related('cvterm_dbxrefs')->delete();
  $cv_cvterms->delete();

  my $dbxref_where = \"dbxref_id NOT IN (SELECT dbxref_id FROM cvterm) AND dbxref_id NOT IN (SELECT dbxref_id FROM cvterm_dbxref)";

  $schema->resultset('Dbxref')->search({ }, { where => $dbxref_where })->delete();
}

=head2 load

 Usage   : my $ont_load = Canto::Track::OntologyLoad->new(schema => $schema);
           $ont_load->load($file_name, $index, [qw(exact related)]);
 Function: Load the contents an OBO file into the schema
 Args    : $source - the file name or URL of an obo format file
           $index - the index to add the terms to (optional)
           $synonym_types_ref - a array ref of synonym types that should be added
                                to the index
 Returns : Nothing

=cut

sub load
{
  my $self = shift;
  my $source = shift;
  my $index = shift;
  my $synonym_types_ref = shift;

  if (!defined $source) {
    croak "no source passed to OntologyLoad::load()";
  }

  if (!defined $synonym_types_ref) {
    croak "no synonym_types passed to OntologyLoad::load()";
  }

  my $schema = $self->load_schema();

  my $guard = $schema->txn_scope_guard;

  my $comment_cvterm = $schema->find_with_type('Cvterm', { name => 'comment' });
  my $parser = GO::Parser->new({ handler=>'obj' });

  my $file_name;
  my $fh;

  if ($source =~ m|http://|) {
    ($fh, $file_name) = tempfile('/tmp/downloaded_ontology_file_XXXXX',
                                 SUFFIX => '.obo');
    my $rc = getstore($source, $file_name);
    if (is_error($rc)) {
      die "failed to download source OBO file: $rc\n";
    }
  } else {
    $file_name = $source;
  }

  $parser->parse($file_name);

  my $graph = $parser->handler->graph;
  my %cvterms = ();

  my @synonym_types_to_load = @$synonym_types_ref;
  my %synonym_type_ids = ();

  for my $synonym_type (@synonym_types_to_load) {
    $synonym_type_ids{$synonym_type} =
      $schema->find_with_type('Cvterm', { name => $synonym_type })->cvterm_id();
  }

  my %relationship_cvterms = ();

  my $relationship_cv =
    $schema->resultset('Cv')->find({ name => 'relationship' });
  my $isa_cvterm = undef;

  if (defined $relationship_cv) {
    $isa_cvterm =
      $schema->resultset('Cvterm')->find({ name => 'is_a',
                                           cv_id => $relationship_cv->cv_id() });

    $relationship_cvterms{is_a} = $isa_cvterm;
  }

  my %cvs = ();

  my $collect_cvs_handler =
    sub {
      my $ni = shift;
      my $term = $ni->term;

      my $cv_name = $term->namespace();

      if (!defined $cv_name) {
        die "no namespace in $source";
      }

      $cvs{$cv_name} = 1;
    };

  $graph->iterate($collect_cvs_handler);


   # delete existing terms
   map {
     _delete_term_by_cv($schema, $_, 0);
  } keys %cvs;

  # delete relations
  map {
    _delete_term_by_cv($schema, $_, 1);
  } keys %cvs;

  my $db_rs = $schema->resultset('Db');

  my %db_ids = map { ($_->name(), $_->db_id()) } $db_rs->all();

  # create this object after deleting as LoadUtil has a dbxref cache (that
  # is a bit ugly ...)
  my $load_util = Canto::Track::LoadUtil->new(schema => $schema,
                                              default_db_name => $self->default_db_name(),
                                              preload_cache => 1);
  my $store_term_handler =
    sub {
      my $ni = shift;
      my $term = $ni->term;

      my $cv_name = $term->namespace();

      if (!defined $cv_name) {
        die "no namespace in $source";
      }

      my $comment = $term->comment();

      my $xrefs = $term->dbxref_list();

      for my $xref (@$xrefs) {
        my $x_db_name = $xref->xref_dbname();
        my $x_acc = $xref->xref_key();

        my $x_db_id = $db_ids{$x_db_name};

        if (defined $x_db_id) {
          my $x_dbxref = undef;

          try {
            $x_dbxref = $load_util->find_dbxref("OBO_REL:$x_acc");
          } catch {
            # dbxref not found
          };

          if (defined $x_dbxref) {
            # no need to add it as it's already there, loaded from another
            # ontology
            if ($term->is_relationship_type()) {
              my $x_dbxref_id = $x_dbxref->dbxref_id();
              my $cvterm_rs = $schema->resultset('Cvterm');
              my ($cvterm) = $cvterm_rs->search({dbxref_id => $x_dbxref_id});
              $relationship_cvterms{$term->name()} = $cvterm;
            }

            return;
          }
        }
      }

      my $term_name = $term->name();

      if (!defined $term_name) {
        die "Term ", $term->acc(), " from $cv_name has no name - cannot continue\n";
      }

      my $cvterm = $load_util->get_cvterm(cv_name => $cv_name,
                                          term_name => $term_name,
                                          ontologyid => $term->acc(),
                                          definition => $term->definition(),
                                          alt_ids => $term->alt_id_list(),
                                          is_obsolete => $term->is_obsolete(),
                                          is_relationshiptype =>
                                            $term->is_relationship_type());

      if ($term->is_relationship_type()) {
        (my $term_acc = $term->acc()) =~ s/OBO_REL://;
        $relationship_cvterms{$term_acc} = $cvterm;
      }

      my $cvterm_id = $cvterm->cvterm_id();

      if (defined $comment) {
        my $cvtermprop =
          $schema->create_with_type('Cvtermprop',
                                    {
                                      cvterm_id => $cvterm_id,
                                      type_id =>
                                        $comment_cvterm->cvterm_id(),
                                      value => $comment,
                                      rank => 0,
                                    });
      }

      my @synonyms_for_index = ();

      for my $synonym_type (@synonym_types_to_load) {
        my $synonyms = $term->synonyms_by_type($synonym_type);

        my $type_id = $synonym_type_ids{$synonym_type};

        for my $synonym (@$synonyms) {
          $schema->create_with_type('Cvtermsynonym',
                                    {
                                      cvterm_id => $cvterm_id,
                                      synonym => $synonym,
                                      type_id => $type_id,
                                    });

          push @synonyms_for_index, { synonym => $synonym, type => $synonym_type };
        }
      }

      if (!$term->is_relationship_type()) {
        $cvterms{$term->acc()} = $cvterm;

        if (!$term->is_obsolete() && defined $index) {
          $index->add_to_index($cv_name, $term_name, $cvterm_id,
                               $term->acc(), \@synonyms_for_index);
        }
      }
    };

  $graph->iterate($store_term_handler);

  my $rels = $graph->get_all_relationships();

  my @sorted_rels = sort {
    $a->{type} cmp $b->{type}
      ||
    $a->{acc1} cmp $b->{acc1}
      ||
    $a->{acc2} cmp $b->{acc2};
  } @$rels;

  my %relationships_to_load = ();

  map { $relationships_to_load{$_} = 1; } @{$self->relationships_to_load()};

  for my $rel (@sorted_rels) {
    my $subject_term_acc = $rel->subject_acc();
    my $object_term_acc = $rel->object_acc();

    next unless $relationships_to_load{$rel->type()};

    my $rel_type = $rel->type();
    my $rel_type_cvterm = $relationship_cvterms{$rel_type};

    die "can't find relationship cvterm for: $rel_type"
      unless defined $rel_type_cvterm;

    # don't store relations between relation terms
    my $subject_cvterm = $cvterms{$subject_term_acc};
    next unless defined $subject_cvterm;

    my $object_cvterm = $cvterms{$object_term_acc};
    next unless defined $object_cvterm;

    $schema->create_with_type('CvtermRelationship',
                              {
                                subject => $subject_cvterm,
                                object => $object_cvterm,
                                type => $rel_type_cvterm
                              });
  }

  $guard->commit();
}

=head2 finalise

 Usage   : $loader->finalise();
 Function: Finish an ontology load by copying the new terms into the schema
           that was passed to the constructor.

=cut
sub finalise
{
  my $self = shift;

  my $dest_dbh = $self->schema()->storage()->dbh();
  my $load_schema = $self->load_schema();
  my $load_dhb = $load_schema->storage()->dbh();

  # SQLite locks the database while in a transaction.  This hack works around
  # that by doing the loading into a temporary copy of the database, then
  # copying the tables back to the original DB.
  try {
    my $load_db_connect_string =
      Canto::DBUtil::connect_string_of_schema($load_schema);

    my $load_db_file_name =
      Canto::DBUtil::connect_string_file_name($load_db_connect_string);

    $dest_dbh->do("ATTACH '$load_db_file_name' as load_db");
    $dest_dbh->do("PRAGMA foreign_keys = OFF");

    $dest_dbh->begin_work();

    my @table_names =
      qw(db dbxref cv cvterm cvterm_dbxref cvtermsynonym cvterm_relationship cvtermprop);

    for my $table_name (reverse @table_names) {
      $dest_dbh->do("DELETE FROM main.$table_name WHERE main.$table_name.${table_name}_id NOT IN (SELECT ${table_name}_id FROM load_db.$table_name)");
    }

    for my $table_name (@table_names) {
      $dest_dbh->do("INSERT INTO main.$table_name SELECT * FROM load_db.$table_name WHERE load_db.$table_name.${table_name}_id NOT IN (SELECT ${table_name}_id FROM main.$table_name)");
    }

    $dest_dbh->commit();

    $dest_dbh->do("DETACH load_db");

    $self->load_schema(undef);
  } catch {
    $dest_dbh->do("PRAGMA foreign_keys = ON");
    die "OntologyLoad::finalise() failed: $_\n";
  };
}

sub DESTROY
{
  my $self = shift;

  if (defined $self->load_schema()) {
    die __PACKAGE__ . "::finalise() not called\n";
  }

  unlink($self->temp_file_name());
}

1;
