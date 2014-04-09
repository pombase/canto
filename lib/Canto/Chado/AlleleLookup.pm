package Canto::Chado::AlleleLookup;

=head1 NAME

Canto::Chado::AlleleLookup - Look up alleles in Chado

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Chado::AlleleLookup

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use Moose;

with 'Canto::Role::Configurable';
with 'Canto::Chado::ChadoLookup';

use Canto::Curs::Utils;

# Return the Canto allele type given a Chado (or "export") allele type
# and the allele description - Canto has different types for a single
# amino acid residue change and a multi amino acid change but Chado
# just has "amino_acid_mutation".  Here we use the
# export_type_reverse_map config field to map the Chado type to the
# Canto type.
sub _canto_allele_type
{
  my $self = shift;
  my $chado_type = shift;
  my $allele_description = shift;

  my @canto_allele_types = @{$self->config()->{export_type_to_allele_type}->{$chado_type}};

  if (@canto_allele_types == 0) {
    warn qq(no allele type found for Chado allele_type "$chado_type"\n);
    return $chado_type;
  } else {
    if (@canto_allele_types == 1) {
      return $canto_allele_types[0]->{name};
    } else {
      for my $allele_type (@canto_allele_types) {
        my $export_type_reverse_map_re =
          $allele_type->{export_type_reverse_map_re};
        if (!defined $export_type_reverse_map_re) {
          die "no export_type_reverse_map_re config found for ", $allele_type->{name};
        }
        if ($allele_description =~ /$export_type_reverse_map_re/) {
          return $allele_type->{name};
        }
      }

      die "no Canto allele type found for: $chado_type";
    }
  }
}

sub lookup
{
  my $self = shift;

  my %args = @_;

  my $gene_primary_identifier = $args{gene_primary_identifier};
  if (!defined $gene_primary_identifier) {
    die "no gene primary name passed to lookup()";
  }

  my $ignore_case = $args{ignore_case};
  my $search_string = $args{search_string};
  if (!defined $search_string) {
    die "no search_string parameter passed to lookup()";
  }

  my $max_results = $args{max_results} || 10;

  my $schema = $self->schema();

  my $gene_constraint_rs =
    $schema->resultset('FeatureRelationship')
           ->search({ 'object.uniquename' => $gene_primary_identifier },
                    { join => 'object' });

  my @search_args;

  if ($ignore_case) {
    @search_args = ('lower(features.name)', { -like => lc $search_string . '%' });
  } else {
    @search_args = ('features.name', { -like => $search_string . '%' });
  }

  my $rs = $schema->resultset('Cv')
    ->search({ 'me.name' => 'sequence' })
    ->search_related('cvterms', { 'cvterms.name' => 'allele' })
    ->search_related('features')
    ->search({ @search_args,
               feature_id => {
                 -in => $gene_constraint_rs->get_column('subject_id')->as_query(),
               },
             },
             { rows => $max_results });

  my %res = map {
   (
     $_->feature_id() => {
       name => $_->name(),
       uniquename => $_->uniquename(),
     }
   )
  } $rs->all();

  my $desc_rs = $schema->resultset('Cv')
    ->search({ 'me.name' => 'PomBase feature property types' })
    ->search_related('cvterms',
                     {
                       -or => [
                         'cvterms.name' => 'description',
                         'cvterms.name' => 'allele_type',
                       ],
                     })
    ->search_related('featureprops')
    ->search({ feature_id => { -in => [ keys %res ] } },
             { prefetch => 'type' });

  while (defined (my $prop = $desc_rs->next())) {
    $res{$prop->feature_id()}->{$prop->type()->name()} = $prop->value();
  }

  my @res = sort { $a->{name} cmp $b->{name} } values %res;

  return [ map {
    my $display_name =
      Canto::Curs::Utils::make_allele_display_name($_->{name},
                                                   $_->{description});


    $_->{display_name} = $display_name;
    $_->{allele_type} = $self->_canto_allele_type($_->{allele_type},
                                                  $_->{description});
    $_;
  } @res ];
}

1;

