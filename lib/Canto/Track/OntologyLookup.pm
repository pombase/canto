package Canto::Track::OntologyLookup;

=head1 NAME

Canto::Track::OntologyLookup - Lookup/search methods for ontologies

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::GOLookup

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

use Carp;
use Moose;

use String::Similarity;

use Canto::Track::OntologyIndex;
use Canto::Track::LoadUtil;

with 'Canto::Role::Configurable';
with 'Canto::Track::TrackAdaptor';
with 'Canto::Role::SimpleCache';

has load_util => (is => 'ro', isa => 'Canto::Track::LoadUtil',
                  lazy_build => 1, init_arg => undef);

has inverse_relationships => (is => 'rw', init_arg => undef);
has follow_inverse_cv_names => (is => 'rw', init_arg => undef);

sub _build_load_util
{
  my $self = shift;

  return Canto::Track::LoadUtil->new(schema => $self->schema());
}

sub BUILD
{
  my $self = shift;

  # "inverse" relationships are where the more specific term is the object. eg. has_part
  my @inverse_relationships =
    @{$self->config()->{load}->{ontology}->{inverse_relationships} // []};

  $self->inverse_relationships(\@inverse_relationships);

  # follow has_part and friends only for some CVs
  my @follow_inverse_cv_names =
    @{$self->config()->{curs_config}->{follow_inverse_cv_names} // []};

  $self->follow_inverse_cv_names(\@follow_inverse_cv_names);
}

sub _get_synonyms
{
  my $cvterm = shift;
  my $synonym_types = shift;

  if (!$synonym_types) {
    return [];
  }

  my %synonym_types = map { ($_,$_) } @$synonym_types;

  my $synonyms = $cvterm->synonyms()->search({}, { prefetch => 'type' });

  return [
    grep {
      my $current_type = $_->{type};
      $synonym_types{$current_type};
    } map {
      { name => $_->synonym(), type => $_->type()->name() };
    } $synonyms->all()
  ];
}

sub _get_subset_ids
{
  my $cvterm = shift;

  my $prop_rs =
    $cvterm->cvtermprop_cvterms()->search({'type.name' => 'canto_subset',},
                                          { join => 'type' });

  return map {
    $_->value();
  } $prop_rs->all();
}

sub _make_term_hash
{
  my $self = shift;
  my $cvterm = shift;
  my $cv_name = shift;
  my $include_definition = shift;
  my $include_children = shift;
  my $include_synonyms = shift;
  my $matching_synonym = shift;
  my $include_subset_ids = shift;

  my $inverse_relationships = $self->inverse_relationships();
  my $follow_inverse_cv_names = $self->follow_inverse_cv_names();

  my %term_hash = ();

  $term_hash{id} = $cvterm->db_accession();
  $term_hash{name} = $cvterm->name();
  $term_hash{is_obsolete} = $cvterm->is_obsolete();

  if (defined $matching_synonym) {
    $term_hash{matching_synonym} = $matching_synonym;
  }
  my $annotation_namespace = $cvterm->cv()->name();
  $term_hash{annotation_namespace} = $annotation_namespace;

  my $annotation_types = $self->config()->{annotation_types_by_namespace}->{$annotation_namespace};

  if ($annotation_types) {
    if (@{$annotation_types} == 1) {
      $term_hash{annotation_type_name} = $annotation_types->[0]->{name};
    }
  } else {
    $term_hash{annotation_type_name} = $annotation_namespace;
  }

  if ($include_definition) {
    $term_hash{definition} = $cvterm->definition();
    my $comment_prop =
      $cvterm->cvtermprop_cvterms()->search({ 'type.name' => 'comment' },
                                            {
                                              join => 'type',
                                            })->first();
    if ($comment_prop) {
      $term_hash{comment} = $comment_prop->value();
    }
  }

  if ($include_children) {
    my %seen = ();

    @{$term_hash{children}} = ();

    my $search_details;

    if (grep { $_ eq $cv_name } @{$follow_inverse_cv_names}) {
      $search_details = {};
    } else {
      $search_details = { 'type.name' => { 'not in' => $inverse_relationships }};
    }

    my @child_cvterms =
      $cvterm->cvterm_relationship_objects()
        ->search($search_details,
                 { join => 'type' })
        ->search_related('subject',
                         { 'cv.name' => $cv_name, 'subject.is_obsolete' => 0 },
                         { join => 'cv' })->all();

    my @child_hashes = ();

    for my $child_cvterm (@child_cvterms) {
      if (!$seen{$child_cvterm->cvterm_id()}) {
        push @child_hashes,
          {$self->_make_term_hash($child_cvterm,
                                  $child_cvterm->cv()->name(), 1, 0, 0, undef)};
        $seen{$child_cvterm->cvterm_id()} = 1;
      }
    }

    @child_hashes = sort {
      $a->{name} cmp $b->{name};
    } @child_hashes;

    $term_hash{children} = \@child_hashes;
  }

  if ($include_synonyms && @$include_synonyms) {
    $term_hash{synonyms} = _get_synonyms($cvterm, $include_synonyms);
  }

  if ($include_subset_ids) {
    $term_hash{subset_ids} = [_get_subset_ids($cvterm)];
  }

  return %term_hash;
}

sub _clean_string
{
  my $text = shift;

  $text =~ s/\W+/ /g;
  $text =~ s/^\s+//;
  $text =~ s/\s+$//;

  return $text;
}


sub _parse_search_scope
{
  my $string = shift;

  if ($string =~ /^\[(.*)\]$/) {
    my $id_string = $1;
    my @ids = split /\|/, $id_string;

    @ids = map {
      if (/(\w+:\d+)-(\w+:\d+)/) {
        {
          include => "is_a($1)",
          exclude => "is_a($2)",
        };
      } else {
        "is_a($_)";
      }
    } @ids;

    return \@ids;
  } else {
    return $string;
  }
}


=head2 lookup

 Usage   : my $lookup = Canto::Track::OntologyLookup->new(...);
           my $result = $lookup->lookup(search_string => $search_string,
                                        ontology_name => $ontology_name);
 Function: Return matching ontology terms from a given ontology
 Args    : ontology_name - the ontology to search
           search_string - the text to use when searching, if this is a ontology
                           ID (eg. "GO:0012345") return just that match
           max_results - maximum hits to return (ignored when search_string is
                         an ontology ID)
           include_children - include data about the child terms (default: 0)
           include_definition - include the definition for terms (default: 0)
           include_synonyms - if defined this is a include all the synonyms in
                              the result (default: [])
           exclude_subsets - exclude from the results any terms that are in the
                             listed subsets (default: [])
 Returns : [ { id => '...', name => '...', definition => '...',
               matching_synonym => '...',  # set only if a synonym matched
               synonyms => [     # set only if include_synonyms is set
                 { name => '...', type => '...' },
                 { name => '...', type => '...' },
               ],
               children => [ { id => '...' }, { id => '...' }, ... ] } ]

           Note: if the search_string matches a synonym more exactly
           than it matches the cvterm name, the matching_synonym field
           is name that synonym, otherwise matching_synonym won't be
           returned in the hash

=cut
sub lookup
{
  my $self = shift;
  my %args = @_;

  my $ontology_name = $args{ontology_name};
  my $search_string = $args{search_string};
  my $max_results = $args{max_results} || 10;
  my $include_definition = $args{include_definition};
  my $include_children = $args{include_children};
  my $include_synonyms = $args{include_synonyms};
  my $exclude_subsets = $args{exclude_subsets} // [];

  my $config = $self->config();
  my $index_path = $config->data_dir_path('ontology_index_dir');
  my $ontology_index = Canto::Track::OntologyIndex->new(config => $config, index_path => $index_path);

  my @results;

  if ($search_string =~ /^\s*([a-zA-Z_]+:\d+)\s*$/) {
    my $res = $self->lookup_by_id(id => $1,
                                  include_definition => $include_definition,
                                  include_children => $include_children,
                                  include_synonyms => $include_synonyms);
    if (defined $res) {
      return [$res];
    } else {
      return [];
    }
  } else {
    if (!defined $ontology_name || length $ontology_name == 0) {
      croak "no ontology_name passed to lookup()";
    }

    my $search_scope = _parse_search_scope($ontology_name);

    @results = $ontology_index->lookup($search_scope,
                                       $exclude_subsets,
                                       _clean_string($search_string),
                                       $max_results);

    my $schema = $self->schema();

    my @limited_hits = ();

    for my $result (@results) {
      my $doc = $result->{doc};
      my $cvterm_id = $doc->get('cvterm_id');
      my $term_name = $doc->get('term_name');
      my $cvterm = $schema->find_with_type('Cvterm', $cvterm_id);

      my %ret_hit = (
        doc => $doc, score => $result->{score},
        cvterm_id => $cvterm_id,
        cvterm_name => $term_name,
        cvterm => $cvterm,
        cv_name => $ontology_name,
      );

      if ($term_name ne $doc->get('text')) {
        $ret_hit{matching_synonym} = $doc->get('text');
      }

      push @limited_hits, \%ret_hit;
    }

    my @ret_list = ();

    for my $hit_hash (@limited_hits) {
      my $doc = $hit_hash->{doc};
      my $name = $doc->get('name');
      my $matching_synonym = $hit_hash->{matching_synonym};
      my $cvterm = $hit_hash->{cvterm};

      my %term_hash =
        $self->_make_term_hash($cvterm,
                               $ontology_name,
                               $include_definition, $include_children,
                               $include_synonyms, $matching_synonym);

      push @ret_list, \%term_hash;
    }

    return \@ret_list;
  }
}


sub _find_cv
{
  my $self = shift;
  my $ontology_name = shift;

  my $cv = $self->schema()->resultset('Cv')->find({ name => $ontology_name });

  die "no cv with name: $ontology_name" unless defined $cv;

  return $cv;
}


=head2 lookup_by_name

 Usage   : my $result = $lookup->lookup_by_name(ontology_name => $ontology_name,
                                                term_name => $term_name);
 Function: Return the detail of the term that matches $term_name in the given
           ontology.
 Args    : ontology_name - the ontology to search
           term_name - the name of the term to find
           include_children - include data about the child terms (default: 0)
           include_definition - include the definition for terms (default: 0)
           include_synonyms - if defined this is a include all the synonyms in
                              the result (default: [])
 Returns : A hash ref of details about the term, or undef if there is no term
           with that name.  The hash will have the same field as returned by
           lookup().
           eg.
           {
             name => '...',
             definition => '...',
             id => '...',
           }

=cut

sub lookup_by_name
{
  my $self = shift;
  my %args = @_;

  my $ontology_name = $args{ontology_name};
  if (!defined $ontology_name) {
    croak "no ontology_name passed to OntologyLookup::lookup_by_name()";
  }

  my $term_name = $args{term_name};

  my $include_definition = $args{include_definition};
  my $include_children = $args{include_children};
  my $include_synonyms = $args{include_synonyms};

  my $schema = $self->schema();

  my $cv = $self->_find_cv($ontology_name);
  my $cvterm = $schema->resultset('Cvterm')->find({ cv_id => $cv->cv_id(),
                                                    name => $term_name });

  if (!defined $cvterm) {
    my $synonym_rs =
      $schema->resultset('Cvtermsynonym')
        ->search({ synonym => $term_name })
        ->search_related('cvterm', { cv_id => $cv->cv_id() });;
    if ($synonym_rs->count() > 1) {
      warn qq(more than one cvterm matching "$term_name");
      return undef;
    }

    if ($synonym_rs->count() == 1) {
      $cvterm = $synonym_rs->first();
    }
  }

  if (defined $cvterm) {
    return { $self->_make_term_hash($cvterm, $cv->name(), $include_definition,
                                    $include_children, $include_synonyms, undef) };
  } else {
    return undef;
  }
}

=head2 lookup_by_id

 Usage   : my $result = $lookup->lookup_by_id(id => $termid);
 Function: Return the detail of the with the given id
 Args    : id - the id to search for
           include_children - include data about the child terms (default: 0)
           include_definition - include the definition for terms (default: 0)
 Returns : A hash ref of details about the term, or undef if there is no term
           with that id.  The hash will have the same field as returned by
           lookup().
           eg.
           {
             name => '...',
             definition => '...',
             id => '...',
           }

=cut

sub lookup_by_id
{
  my $self = shift;
  my %args = @_;

  my $include_definition = $args{include_definition} // 0;
  my $include_children = $args{include_children} // 0;
  my $include_synonyms = $args{include_synonyms} || [];
  my $include_subset_ids = $args{include_subset_ids} // 0;

  my $term_id = $args{id};
  if (!defined $term_id) {
    croak "no id passed to OntologyLookup::lookup_by_id()";
  }

  my @key_bits = ($term_id, $include_definition, $include_children,
                  (join "-", @{$include_synonyms}),
                  $include_subset_ids);
  my $cache_key = join '#@%', @key_bits;

  my $cache = $self->cache();

  my $cached_value = $cache->get($cache_key);

  if (defined $cached_value) {
    return $cached_value;
  }

  my $dbxref;

  eval {
    $dbxref = $self->load_util()->find_dbxref($term_id);
  };

  if (!defined $dbxref) {
    return undef;
  }

  my @terms = $dbxref->cvterms();

  if (@terms > 1) {
    warn "internal error: looked up $term_id and got more than one result:\n";
    for my $term (@terms) {
      warn '  ', $term->name(), ' (', $term->cv()->name(), ")\n";
    }
    die "\n";
  }

  my $cvterm;

  if (@terms == 0) {
    my @cvterm_dbxrefs = $dbxref->cvterm_dbxrefs();

    if (@cvterm_dbxrefs > 1) {
      die "internal_error: looked up $term_id and got more than one " .
        "result via the cvterm_dbxref table";
    }

    if (@cvterm_dbxrefs == 0) {
      return undef;
    } else {
      $cvterm = $cvterm_dbxrefs[0]->cvterm();
    }
  } else {
    $cvterm = $terms[0];
  }

  my $ret_val = { $self->_make_term_hash($cvterm, $cvterm->cv()->name(),
                           $include_definition, $include_children,
                           $include_synonyms, undef,
                           $include_subset_ids) };

  $cache->set($cache_key, $ret_val, $self->config()->{cache}->{default_timeout});

  return $ret_val;
}


sub _get_all_count_rs
{
  my $self = shift;
  my $schema = $self->schema();
  my $search_scope = shift;
  my $exclude_subsets = shift;

  my $rs = undef;

  if (ref $search_scope) {
    # we got eg. "[GO:000123|SO:000345]" or "[GO:0008150-GO:0000770|GO:0000123]"
    # from the user so $search_scope is an array of IDs or hashes like
    # { include => 'GO:0008150', exclude => 'GO:0000770' }
    # (meaning exclude a term and children)
    my $place_holder_count = 0;

    my $where =
      join ' OR ', map {
        my $where_bit = <<"END";
cvterm_id in
  (SELECT p.cvterm_id FROM cvtermprop p
     JOIN cvterm pt ON p.type_id = pt.cvterm_id
    WHERE pt.name = 'canto_subset' AND value = ?)
END

        if (ref $_) {
          $where_bit .= <<"END";
AND cvterm_id NOT IN
  (SELECT p.cvterm_id FROM cvtermprop p
     JOIN cvterm pt ON p.type_id = pt.cvterm_id
    WHERE pt.name = 'canto_subset' AND value = ?)
END
          $place_holder_count += 2;
        } else {
          $place_holder_count++;
        }

        $where_bit;
      } @$search_scope;

    my @flat_ids = map {
      if (ref $_) {
        ($_->{include}, $_->{exclude});
      } else {
        $_;
      }
    } @$search_scope;

    my @bind_params = map {
      ['value', $_];
    } @flat_ids;

    $rs = $schema->resultset('Cvterm')->search(\["is_obsolete = 0 AND ($where)", @bind_params]);
  } else {
    my $cv = $self->_find_cv($search_scope);
    $rs = $schema->resultset('Cvterm')->search({
      cv_id => $cv->cv_id(),
      is_obsolete => 0,
      is_relationshiptype => 0,
    });
  }

  if (@$exclude_subsets) {
    my $subset_cvtermprop_rs =
      $schema->resultset('Cvtermprop')
        ->search(
          {
            value => { -in => $exclude_subsets },
            'type.name' => 'canto_subset',
          },
          {
            join => 'type',
          });

    $rs = $rs->search({
      cvterm_id => {
        -not_in => $subset_cvtermprop_rs->get_column('cvterm_id')->as_query(),
      }
    });
  }

  return $rs;
}


=head2 get_all

 Usage   : my $lookup = Canto::Track::OntologyLookup->new(...);
           my @all_terms = $lookup->get_all(ontology_name => $ontology_name,
                                            include_children => 1|0,
                                            include_definition => 1|0,
                                            include_exact_synonyms => 1|0);
 Function: Return all the non-obsolete, non-relation terms from an ontology
           or subset
 Args    : ontology_name - the ontology or subset to search, subsets look like:
                           "[GO:000123|SO:000345]"
           include_children - include data about the child terms (default: 0)
           include_definition - include the definition for terms (default: 0)
           include_synonyms - if defined this is a include all the synonyms in
                              the result (default: [])
           exclude_subsets - exclude from the results any terms that are in the
                             listed subsets (default: [])
 Returns : returns an array of hashes in the same format as lookup()
           but with no matching_synonym keys

=cut
sub get_all
{
  my $self = shift;
  my %args = @_;

  my $ontology_name = $args{ontology_name};
  if (!defined $ontology_name) {
    croak "no ontology_name passed to OntologyLookup::get_all()";
  }

  my $include_definition = $args{include_definition};
  my $include_children = $args{include_children};
  my $include_synonyms = $args{include_synonyms};
  my $include_subset_ids = $args{include_subset_ids};
  my $exclude_subsets = $args{exclude_subsets} // [];

  my $schema = $self->schema();
  my @ret_list = ();

  my $search_scope = _parse_search_scope($ontology_name);

  my $cvterm_rs = $self->_get_all_count_rs($search_scope, $exclude_subsets);

  while (defined (my $cvterm = $cvterm_rs->next())) {
    my %term_hash =
      $self->_make_term_hash($cvterm, $ontology_name,
                             $include_definition, $include_children,
                             $include_synonyms, undef, $include_subset_ids);

    push @ret_list, \%term_hash;
  }

  return @ret_list;
}


=head2 get_column

 Usage   : my $count = $lookup->get_count(ontology_name => $ontology_name);
 Function: Return the count of the non-relation terms from an ontology or subset
 Args    : ontology_name - the ontology or subset to search, subsets look like:
                           "[GO:000123|SO:000345]"
           exclude_subsets - exclude from the results any terms that are in the
                             listed subsets (default: [])

=cut

sub get_count
{
  my $self = shift;
  my %args = @_;

  my $ontology_name = $args{ontology_name};
  if (!defined $ontology_name) {
    croak "no ontology_name passed to OntologyLookup::get_count()";
  }

  my $exclude_subsets = $args{exclude_subsets} // [];

  my $schema = $self->schema();

  my $search_scope = _parse_search_scope($ontology_name);
  my $cvterm_rs = $self->_get_all_count_rs($search_scope, $exclude_subsets);

  return $cvterm_rs->count();
}

1;
