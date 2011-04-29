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
      ->search({ 'type.name' => 'taxonId' }, { join => 'type' })->first();

    my $taxonid = $prop->value();
    $cache->{$full_name} = $taxonid;
    return $taxonid;
  }
}

=head2

 Usage   :
 Function:
 Args    :
 Returns :

=cut
sub lookup
{
  my $self = shift;
  my $args_ref = shift;
  my %args = %{$args_ref};

  my $pub_uniquename = $args{pub_uniquename};
  my $ontology_name = $args{ontology_name};

  die "no ontology_name" unless defined $ontology_name;

  my %db_ontology_names = (
    post_translational_modification => 'pt_mod',
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

  my $pub = $schema->find_with_type('Pub', { uniquename => $pub_uniquename });

  if (defined $pub) {
    my $cv = $schema->find_with_type('Cv', name => $db_ontology_name);
    my $constraint = { pub_id => $pub->pub_id(),
                       'cvterm.cv_id' => $cv->cv_id() };
    my $options = { prefetch => [ { feature => 'organism' },
                                  { cvterm => [ 'cv', { dbxref => 'db' } ] } ],
                    join => 'cvterm' };
    my $rs = $schema->resultset('FeatureCvterm')->search($constraint, $options);
    my $taxonid_cache = {};

    my @res = ();

    while (defined (my $row = $rs->next())) {
      my $feature = $row->feature();
      my $cvterm = $row->cvterm();
      my $organism = $feature->organism();
      my $genus = $organism->genus();
      my $species = $organism->species();
      push @res, {
        gene => { identifier => $feature->uniquename(),
                  name => $feature->name(),
                  product => 'DUNNO product',
                  synonyms => ['DUNNO synonyms'],
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
        evidence_code => 'DUNNO',
      }
    }

    return [@res];
  } else {
    return [];
  }
}

1;
