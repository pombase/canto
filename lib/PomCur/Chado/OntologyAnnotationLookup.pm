package PomCur::Chado::OntologyAnnotationLookup;

=head1 NAME

PomCur::Chado::OntologyAnnotationLookup - Code for looking up ontology
    annotation in a ChadoDB

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Chado::OntologyAnnotationLookup

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

with 'PomCur::Role::Configurable';
with 'PomCur::Chado::ChadoLookup';

sub _get_taxonid
{
  my $schema = shift;
  my $cache = shift;
  my $genus = shift;
  my $species = shift;

  my $full_name = "$genus $species";

  if (exists $cache->{$full_name}) {
    return $cache->{$full_name};
  } else {
    my $constraint = { genus => $genus, species => $species };
    my $organism_rs = $schema->resultset('Organism')->search($constraint);
    my $prop = $organism_rs->search_related('organismprops')
      ->search({ 'type.name' => 'taxon_id' }, { join => 'type' })->first();

    my $taxonid = $prop->value();
    $cache->{$full_name} = $taxonid;
    return $taxonid;
  }
}

# if the $feature is an mRNA, return it's gene feature, otherwise return
# the $feature
sub _gene_of_feature
{
  my $self = shift;
  my $feature = shift;

  my $mrna_cvterm = $self->schema()->get_cvterm('sequence', 'mRNA');

  if ($feature->type_id() == $mrna_cvterm->cvterm_id()) {
    my $gene_cvterm = $self->schema()->get_cvterm('sequence', 'gene');

    return $feature->feature_relationship_objects()
                   ->search_related('subject', {
                     'subject.type_id' => $gene_cvterm->cvterm_id()
                   })->single();
  } else {
    return $feature;
  }
}

=head2

 Usage   : my $res = PomCur::Chado::OntologyAnnotationLookup($options);
 Function: lookup ontology annotation in a Chado database
 Args    : $options->{pub_uniquename} - the identifier of the publication,
               usually the PubMed ID to get annotations for
           $options->{gene_identifier} - the gene identifier to use to constrain
               the search; only annotations for the gene are returned (optional)
           $options->{ontology_name} - the ontology name to use to restrict the
               search; only annotations using terms from this ontology are
               returned (optional)
 Returns : An array reference of annotation results:
            [ {
              gene => {
                identifier => "SPAC22F3.13",
                name => 'tsc1',
                organism_taxonid => 4896
              },
              ontology_term => {
                ontology_name => 'molecular_function',
                term_name => 'regulation of conjugation ...',
                ontid => 'GO:0031137',
              },
              publication => {
                uniquename => 'PMID:10467002',
              },
              evidence_code => 'IMP',
              annotation_id => ....
            }, ... ]
          - where annotation_id is a unique ID for this annotation

=cut
sub lookup
{
  my $self = shift;
  my $args_ref = shift;
  my %args = %{$args_ref};

  my $pub_uniquename = $args{pub_uniquename};
  my $gene_identifier = $args{gene_identifier};
  my $ontology_name = $args{ontology_name};

  die "no ontology_name" unless defined $ontology_name;

  my %db_ontology_names = (
    post_translational_modification => 'PSI-MOD',
    physical_interaction => undef,
    genetic_interaction => undef,
  );

  my $db_ontology_name;
  if (exists $db_ontology_names{$ontology_name}) {
    if (defined $db_ontology_names{$ontology_name}) {
      $db_ontology_name = $db_ontology_names{$ontology_name};
    } else {
      return [];
    }
  } else {
    $db_ontology_name = $ontology_name;
  }

  my $schema = $self->schema();

  $pub_uniquename =~ s/PMID://;

  my $pub = $schema->resultset('Pub')->find({ uniquename => $pub_uniquename });

  if (defined $pub) {
    my $feature_cvtermprop_type_cv =
      $schema->find_with_type('Cv', name => 'feature_cvtermprop_type');
    my $evidence_type_cvterm_id =
      $schema->resultset('Cvterm')
         ->search({ cv_id => $feature_cvtermprop_type_cv->cv_id(),
                    name => 'evidence' })
         ->single()->cvterm_id();
    my $cv = $schema->find_with_type('Cv', name => $db_ontology_name);
    my $constraint = { pub_id => $pub->pub_id(),
                       'cvterm.cv_id' => $cv->cv_id() };
    if (defined $gene_identifier) {
      $constraint->{'feature.uniquename'} = $gene_identifier;
    }

    my $options = { prefetch => [ { feature => 'organism' },
                                  { cvterm => [ 'cv', { dbxref => 'db' } ] } ],
                    join => ['cvterm', 'feature'] };
    my $rs = $schema->resultset('FeatureCvterm')->search($constraint, $options);
    my $taxonid_cache = {};

    my @res = ();

    while (defined (my $row = $rs->next())) {
      my $feature = $self->_gene_of_feature($row->feature());
      my $cvterm = $row->cvterm();
      my $organism = $feature->organism();
      my $genus = $organism->genus();
      my $species = $organism->species();
      my $evidence_type_prop = $row->feature_cvtermprops
          ->search({ type_id =>$evidence_type_cvterm_id  })->single();
      my $evidence_type_name = 'Unknown';
      if (defined $evidence_type_prop) {
        $evidence_type_name = $evidence_type_prop->value();
      }
      $evidence_type_name =~ s/\s+with\s+.*//;
      my $evidence_code =
        $self->config()->{evidence_types_by_name}->{lc $evidence_type_name} //
        $evidence_type_name;

      push @res, {
        gene => {
          identifier => $feature->uniquename(),
          name => $feature->name(),
          organism_taxonid =>
            _get_taxonid($schema, $taxonid_cache, $genus, $species),
        },
        ontology_term => {
          ontology_name => $cvterm->cv()->name(),
          term_name => $cvterm->name(),
          ontid => $cvterm->db_accession(),
        },
        publication => {
          uniquename => $pub_uniquename,
        },
        evidence_code => $evidence_code,
        annotation_id => $row->feature_cvterm_id(),
      }
    }

    return [@res];
  } else {
    return [];
  }
}

1;
