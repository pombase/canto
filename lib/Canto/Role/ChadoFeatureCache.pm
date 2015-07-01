package Canto::Role::ChadoFeatureCache;

=head1 NAME

Canto::Role::ChadoFeatureCache - Cache Chado features using the cache() method

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Role::ChadoFeatureCache

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose::Role;

requires 'cache';
requires 'schema';

sub get_cached_taxonid
{
  my $self = shift;
  my $organism_id = shift;

  my $cache = $self->cache();

  my $key = "organism:organism_id";
  my $cached_value = $cache->get($key);

  if (defined $cached_value) {
    return $cached_value;
  } else {
    my $organism = $self->schema()->resultset('Organism')
      ->find({ organism_id => $organism_id },
             { join => { organismprops => 'type' }});

    my $prop = $organism->organismprops()
      ->search({ 'type.name' => 'taxon_id' }, { join => 'type' })->first();

    my $taxonid = $prop->value();

    die "no taxon_id for ", $organism->full_name() unless defined $taxonid;

    $cache->set($key, $taxonid, $self->config()->{cache}->{chado_gene_timeout});
    return $taxonid;
  }
}

sub get_cached_allele_details
{
  my $self = shift;
  my $allele = shift;

  my $cache = $self->cache();

  my $key = 'allele:' . $allele->feature_id();

  my $cached_value = $cache->get($key);

  if (defined $cached_value) {
    return $cached_value;
  } else {
    my %props = ();

    map {
      $props{$_->type()->name()} = $_->value();
    } $allele->featureprops() ->search({}, { join => 'type' })->all();

    my $gene_rs = $allele->feature_relationship_subjects()
      ->search({ 'type.name' => 'instance_of' },
               { join => 'type' })
      ->search_related('object');

    my $gene = $gene_rs->first();
    my $taxonid = $self->get_cached_taxonid($gene->organism_id());

    my %details = (
      primary_identifier => $allele->uniquename(),
      name => $allele->name(),
      description => $props{description},
      type => $props{type},
      gene_display_name => $gene->name() || $gene->uniquename(),
      gene_id => $gene->feature_id(),
      taxonid => $taxonid,
    );

    return \%details;
  }
}

sub get_cached_genotype_details
{
  my $self = shift;
  my $genotype = shift;

  my $key = 'genotype:' . $genotype->feature_id();

  my $cache = $self->cache();
  my $cached_value = $cache->get($key);

  if (defined $cached_value) {
    return $cached_value;
  } else {
    my @alleles = ();

    my $allele_rs = $genotype->feature_relationship_objects()
      ->search({ 'type.name' => 'part_of' },
               { join => 'type' })
      ->search_related('subject', { 'type_2.name' => 'allele' }, { join => 'type' });

    while (defined (my $allele = $allele_rs->next())) {
      push @alleles, $self->get_cached_allele_details($allele);
    }

    @alleles = sort {
      ($a->{name} // $a->{uniquename})
        cmp
      ($b->{name} // $b->{uniquename});
    } @alleles;

    my %details = (
      identifier => $genotype->uniquename(),
      name => $genotype->name(),
      alleles => \@alleles,
    );

    $cache->set($key, \%details, $self->config()->{cache}->{chado_gene_timeout});

    return \%details;
  }
}

1;
