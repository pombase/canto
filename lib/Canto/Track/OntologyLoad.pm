package Canto::Track::OntologyLoad;

=head1 NAME

Canto::Track::OntologyLoad - Code for loading ontology information into a
                              TrackDB

=head1 SYNOPSIS

my $loader = Canto::Track::OntologyLoad->new(schema => $schema,
                                             config => $config,
                                             relationships_to_load => ['is_a']);

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

use LWP::Simple;
use File::Temp qw(tempfile);

use Canto::Track::LoadUtil;
use Canto::Curs::Utils;
use Canto::Config::ExtensionProcess;
use Canto::Chado::SubsetProcess;

use PomBase::Chobo::ParseOBO;
use PomBase::Chobo::OntologyData;

with 'Canto::Role::Configurable';

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

has 'temp_file_name' => (
  is => 'rw',
  init_arg => undef
);

has 'relationships_to_load' => (
  is => 'ro',
  required => 1,
  isa => 'ArrayRef[Str]',
);

has 'extension_process' => (
  is => 'ro',
  default => undef,
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
                      cvterm_relationship_types cvterm_dbxrefs)) {
    $cv_cvterms->search_related($related)->delete();
  }

  $cv_cvterms->delete();

  my $dbxref_where = \"dbxref_id NOT IN (SELECT dbxref_id FROM cvterm) AND dbxref_id NOT IN (SELECT dbxref_id FROM cvterm_dbxref)";
  $schema->resultset('Dbxref')->search({ }, { where => $dbxref_where })->delete();

  my $cvtermprop_where = \"cvterm_id NOT IN (SELECT cvterm_id FROM cvterm)";
  $schema->resultset('Cvtermprop')->search({ }, { where => $cvtermprop_where })->delete();

  my $cvtermsynonym_where = \"cvterm_id NOT IN (SELECT cvterm_id FROM cvterm)";
  $schema->resultset('Cvtermsynonym')->search({ }, { where => $cvtermsynonym_where })->delete();
}

sub _store_cv_prop
{
  my $schema = shift;
  my $load_util = shift;

  my $cv = shift;
  my $prop_name = shift;
  my $value = shift;

  my $prop_type_term =
    $load_util->find_cvterm(cv_name => 'cvprop_type',
                            name => $prop_name);

  my $prop_term =
    $schema->resultset('Cvprop')->find({ cv_id => $cv->cv_id(),
                                         type_id => $prop_type_term->cvterm_id() });

  if (defined $prop_term) {
    $prop_term->value($value);
    $prop_term->update();
  } else {
    $schema->resultset('Cvprop')->create({ cv_id => $cv->cv_id(),
                                           type_id => $prop_type_term->cvterm_id(),
                                           value => $value});
  }
}

sub _parse_source
{
  my $self = shift;
  my $parser = shift;
  my $ontology_data = shift;
  my $source = shift;

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

  $parser->parse(filename => $file_name, ontology_data => $ontology_data);
}

=head2 load

 Usage   : my $ont_load = Canto::Track::OntologyLoad->new(schema => $schema,
                                                          config => $config,
                                                          relationships_to_load => ['is_a']);
           $ont_load->load($file_name, $index, [qw(exact related)]);
 Function: Load the contents an OBO file into the schema
 Args    : $source - the file name or URL of an obo format file
           $index - the index to add the terms to (optional)
           $synonym_types_ref - a array ref of synonym types that should be
                                added to the index

=cut

sub load
{
  my $self = shift;
  my $sources = shift;
  my $index = shift;
  my $synonym_types_ref = shift;

  if (!defined $sources) {
    croak "no source passed to OntologyLoad::load()";
  }

  if (!defined $synonym_types_ref) {
    croak "no synonym_types passed to OntologyLoad::load()";
  }

  my $config_subsets_to_ignore =
    $self->config()->{ontology_namespace_config}{subsets_to_ignore};

  my @subsets_to_ignore = ();

  if ($config_subsets_to_ignore) {
    for my $key (keys %{$config_subsets_to_ignore}) {
      my @this_subset = @{$config_subsets_to_ignore->{$key}};
      for my $subset_id (@this_subset) {
        if (!grep { $subset_id eq $_ } @subsets_to_ignore) {
          push @subsets_to_ignore, $subset_id
        }
      }
    }
  }

  my $subset_process = Canto::Chado::SubsetProcess->new();
  my $subset_data;

  if ($self->extension_process()) {
    $subset_data = $self->extension_process()->get_subset_data(@$sources);
  } else {
    $subset_data = $subset_process->get_empty_subset_data();
  }

  my $schema = $self->load_schema();

  my $guard = $schema->txn_scope_guard;

  my $comment_cvterm = $schema->find_with_type('Cvterm', { name => 'comment' });
  my $parser = PomBase::Chobo::ParseOBO->new();
  my $ontology_data = PomBase::Chobo::OntologyData->new();

  for my $source (@$sources) {
    $self->_parse_source($parser, $ontology_data,  $source);
  }

  my %cvterms = ();

  my %relationship_cvterms = ();

  my $relationship_cv =
    $schema->resultset('Cv')->find({ name => 'canto_core' });
  my $isa_cvterm = undef;

  if (defined $relationship_cv) {
    $isa_cvterm =
      $schema->resultset('Cvterm')->find({ name => 'is_a',
                                           cv_id => $relationship_cv->cv_id() });

    $relationship_cvterms{is_a} = $isa_cvterm;
  }

  my %cvs = ();
  map {
    $cvs{$_} = 1;
  } $ontology_data->get_cv_names();

  # delete existing terms
  map {
     _delete_term_by_cv($schema, $_, 0);
  } keys %cvs;

  # delete relations
  map {
    _delete_term_by_cv($schema, $_, 1);
  } keys %cvs;

  # create this object after deleting as LoadUtil has a dbxref cache (that
  # is a bit ugly ...)
  my $load_util = Canto::Track::LoadUtil->new(schema => $schema,
                                              default_db_name => $self->config()->{default_db_name},
                                              preload_cache => 1);
  my %relationships_to_load = ();

  map { $relationships_to_load{$_} = 1; } @{$self->relationships_to_load()};

  my @synonym_types_to_load = @$synonym_types_ref;
  my %synonym_type_ids = ();

  for my $synonym_type (@synonym_types_to_load) {
    $synonym_type_ids{$synonym_type} =
      $load_util->find_cvterm(cv_name => 'synonym_type',
                              name => $synonym_type)->cvterm_id();
  }

  my %term_counts = ();

  my @sorted_terms_to_store = sort { $a->id() cmp $b->id() } $ontology_data->get_terms();

  my %term_namespace = ();

  for my $term (@sorted_terms_to_store) {
    my $cv_name = $term->namespace() // 'external';
    my $term_acc = $term->id();

    $term_namespace{$term_acc} = $cv_name;
  }

  my @sorted_cvterm_rels = sort {
    $a->[1] cmp $b->[1]  # type
      ||
    $a->[0] cmp $b->[0]  # subject
      ||
    $a->[2] cmp $b->[2]; # object
  } $ontology_data->relationships();

  my %term_parents = ();

  for my $rel (@sorted_cvterm_rels) {
    my $subject_term_id = $rel->[0];
    my $object_term_id = $rel->[2];

    next unless defined $term_namespace{$subject_term_id};
    next unless defined $term_namespace{$object_term_id};

    if ($term_namespace{$subject_term_id} eq $term_namespace{$object_term_id}) {
      push @{$term_parents{$subject_term_id}}, $object_term_id;
    }
  }

  for my $term (@sorted_terms_to_store) {
    my $cv_name = $term->namespace() // 'external';
    my $comment = $term->comment();

    my $term_name = $term->name();

    if (!defined $term_name) {
      die "Term ", $term->id(), " from $cv_name has no name - cannot continue\n";
    }

    if ($term->is_relationshiptype() &&
        !$relationships_to_load{$term->name()} &&
        !$relationships_to_load{$term->name() =~ s/\s+/_/gr}) {
      next;
    }

      my $cvterm = $load_util->get_cvterm(cv_name => $cv_name,
                                          term_name => $term_name,
                                          ontologyid => $term->id(),
                                          definition => $term->def(),
                                          alt_ids => $term->alt_id(),
                                          is_obsolete => $term->is_obsolete(),
                                          is_relationshiptype =>
                                            $term->is_relationshiptype());

    if ($term->is_relationshiptype()) {
      $relationship_cvterms{$term_name} = $cvterm;
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

    my @synonyms = $term->synonyms();

    for my $synonym_type (@synonym_types_to_load) {
      for my $synonym (sort { $a->{synonym} cmp $b->{synonym} } @synonyms) {
        if (lc $synonym->{scope} eq lc $synonym_type) {
          my $type_id = $synonym_type_ids{$synonym_type};

          $schema->create_with_type('Cvtermsynonym',
                                    {
                                      cvterm_id => $cvterm_id,
                                      synonym => $synonym->{synonym},
                                      type_id => $type_id,
                                    });

          push @synonyms_for_index, { synonym => $synonym->{synonym}, type => $synonym_type };
        }
      }
    }

    my @subset_ids = ();

    my $objects = $subset_data->{$term->id()};

    if ($objects) {
      push @subset_ids, map { "is_a($_)" } (keys %$objects, $term->id());
    }

    if (!$term->is_relationshiptype()) {
      $cvterms{$term->id()} = $cvterm;

      if (!$term->is_obsolete()) {
        if (!defined $term_parents{$term->id()}) {
          push @subset_ids, 'is_a(canto_root_subset)';
          $subset_process->add_to_subset($subset_data, 'canto_root_subset',
                                         'is_a', [$term->id()]);
        }

        for my $subset_id (@subsets_to_ignore) {
          if (grep { "is_a($_)" eq $subset_id } $term->subsets()) {
            push @subset_ids, $subset_id;
            my $subset_id_term_only = $subset_id =~ s/^\s*.*\((.*)\)\s*$/$1/r;
            $subset_process->add_to_subset($subset_data, $subset_id_term_only,'is_a',
                                           [$term->id()]);
          }
        }
        if (defined $index) {
          $index->add_to_index($cv_name, $term_name, $cvterm_id,
                               $term->id(), \@subset_ids, \@synonyms_for_index);
        }
      }

      $term_counts{$cv_name}++;
    }
  }

  for my $rel (@sorted_cvterm_rels) {
    my $subject_term_id = $rel->[0];
    my $object_term_id = $rel->[2];

    my $rel_type = $rel->[1];
    next unless $relationships_to_load{$rel_type};

    my $rel_type_cvterm = $relationship_cvterms{$rel_type};

    die "can't find relationship cvterm for: $subject_term_id <- $rel_type -> $object_term_id"
      unless defined $rel_type_cvterm;

    # don't store relations between relation terms
    my $subject_cvterm = $cvterms{$subject_term_id};
    next unless defined $subject_cvterm;

    my $object_cvterm = $cvterms{$object_term_id};
    next unless defined $object_cvterm;

    $schema->create_with_type('CvtermRelationship',
                              {
                                subject => $subject_cvterm,
                                object => $object_cvterm,
                                type => $rel_type_cvterm
                              });
  }

  for my $cv_name (sort keys %cvs) {
    my $cv = $load_util->find_or_create_cv($cv_name);

    my $date = Canto::Curs::Utils::get_iso_date();
    _store_cv_prop($schema, $load_util, $cv, 'cv_date', $date);

    _store_cv_prop($schema, $load_util, $cv, 'cv_term_count',
                   $term_counts{$cv_name} // 0);
  }

  # add canto_subset cvtermprop to the terms in subsets
  $subset_process->process_subset_data($self->load_schema(), $subset_data);

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
      qw(db dbxref cv cvprop cvterm cvterm_dbxref cvtermsynonym cvterm_relationship cvtermprop);

    for my $table_name (reverse @table_names) {
      $dest_dbh->do("DELETE FROM main.$table_name WHERE main.$table_name.${table_name}_id");
    }

    for my $table_name (@table_names) {
      $dest_dbh->do("INSERT INTO main.$table_name SELECT * FROM load_db.$table_name");
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
