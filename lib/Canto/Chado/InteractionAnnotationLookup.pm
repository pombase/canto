package Canto::Chado::InteractionAnnotationLookup;

=head1 NAME

Canto::Chado::InteractionAnnotationLookup - Lookup interactions in Chado

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Chado::InteractionAnnotationLookup

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

use CHI;

use feature "state";

use Canto::Cache;

with 'Canto::Role::Configurable';
with 'Canto::Chado::ChadoLookup';
with 'Canto::Role::TaxonIDLookup';

has cache => (is => 'ro', init_arg => undef, lazy_build => 1);

sub _build_cache
{
  my $self = shift;

  my $cache = Canto::Cache::get_cache($self->config(), __PACKAGE__);

  return $cache;
}

=head2

 Usage   : my $res = Canto::Chado::InteractionAnnotationLookup($options);
 Function: lookup interaction annotation in a Chado database
 Args    : $options->{pub_uniquename} - the identifier of the publication,
               usually the PubMed ID to get annotations for
           $options->{gene_identifier} - the gene identifier to use to constrain
               the search; only annotations for the gene are returned (optional)
           $options->{interaction_type} - "physical" or "genetic"
           $options->{max_results} - maximum number of interactions to return
 Returns : A count of annotations and an array reference of annotation results:
            (1,
            [ {
              gene => {
                identifier => "SPAC22F3.13",
                name => 'tsc1',
                organism_taxonid => 4896
              },
              publication => {
                uniquename => 'PMID:10467002',
              },
              evidence_code => 'Phenotypic Enhancement',
              interacting_gene => { ... },
            }, ... ])
          - where annotation_id is a unique ID for this annotation

=cut
sub lookup
{
  my $self = shift;
  my $args_ref = shift;
  my %args = %{$args_ref};

  my $pub_uniquename = $args{pub_uniquename};
  my $gene_identifier = $args{gene_identifier};
  my $interaction_type_name = $args{interaction_type_name};
  my $max_results = $args{max_results} // 0;

  my $cache_key;

  if (defined $gene_identifier) {
    $cache_key = "$pub_uniquename!$gene_identifier!$interaction_type_name!$max_results";
  } else {
    $cache_key = "$pub_uniquename!$interaction_type_name!$max_results";
  }

  my $cached_value = $self->cache->get($cache_key);

  if (defined $cached_value) {
    return @$cached_value;
  }

  my $schema = $self->schema();

  my $interaction_types_cv =
    $schema->resultset('Cv')->find({ name => 'PomBase interaction types' }) //
    $schema->find_with_type('Cv', { name => 'interaction types' });

  my $interaction_type_cvterm;

  if ($interaction_type_name eq 'genetic_interaction') {
    $interaction_type_cvterm =
      $schema->find_with_type('Cvterm',
                              { name => 'interacts_genetically',
                                cv_id => $interaction_types_cv->cv_id() });
  } else {
    $interaction_type_cvterm =
      $schema->find_with_type('Cvterm',
                              { name => 'interacts_physically',
                                cv_id => $interaction_types_cv->cv_id() });
  }

  my $pub = $schema->resultset('Pub')->find({ uniquename => $pub_uniquename });

  if (!defined $pub) {
    return (0, []);
  }

  my %gene_constraint = ();
  my %query_options = ();

  if (defined $gene_identifier) {
    $gene_constraint{'-or'} = {
      'subject.uniquename' => $gene_identifier,
      'object.uniquename' => $gene_identifier,
    };
    $query_options{join} = [ 'subject', 'object' ];
  }

  my $relations = $pub
      ->search_related('feature_relationship_pubs')
      ->search_related('feature_relationship')
      ->search({ -and =>
                   {
                     'feature_relationship.type_id' => $interaction_type_cvterm->cvterm_id(),
                     %gene_constraint,
                   }
                 },
               { %query_options,
                 prefetch => [
                 { subject => 'organism' },
                 { object => 'organism' } ] });

  my $all_interactions_count = $relations->count();

  my @res = ();

  if ($max_results > 0) {
    $relations = $relations->search({}, { rows => $max_results });
  }

  while (defined (my $rel = $relations->next())) {
    my $subject = $rel->subject();
    my $object = $rel->object();

    my $rel_props = $rel->feature_relationshipprops();

    my $evidence_code = undef;

    for my $prop ($rel_props->all()) {
      if ($prop->type()->name() eq 'evidence') {
        $evidence_code = $prop->value(),
      }
    }

    push @res, {
      gene => {
        identifier => $subject->uniquename(),
        name => $subject->name(),
        taxonid => $self->taxon_id_lookup($subject->organism()),
      },
      interacting_gene => {
        identifier => $object->uniquename(),
        name => $object->name(),
        taxonid => $self->taxon_id_lookup($object->organism()),
      },
      publication => {
        uniquename => $pub_uniquename,
      },
      evidence_code => $evidence_code,
      annotation_type => $interaction_type_name,
    };

  }

  my @ret_val = ($all_interactions_count, \@res);

  $self->cache()->set($cache_key, \@ret_val, "2 hours");

  return @ret_val;
}

1;
