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

=head2 lookup

 Usage   : my $allele_lookup = Canto::Track::get_adaptor($config, 'allele');
           my $results = $allele_lookup->lookup(gene_primary_identifier => 'SPAC1556.01c',
                                                search_string => 'rad50',
                                                max_results => 10);
 Function: Look up allele details by allele name prefix.  This only searches the
           alleles of the gene given by the gene_primary_identifier argument.
           This function is used for autocompleting in the allele selection
           dialog and the search should be case insensitive.
 Args    : gene_primary_identifier - the gene to restrict the search to
           search_string - the prefix of the allele name, eg. "rad" for pombe
                           "SPAC1556.01c" could return "rad50-c1" or
                           "rad50delta"
           max_results - maximum matches to return [optional, default 10]
 Return  : [ { description: "some allele description",
               display_name: "a pretty name for the user",
               uniquename: "database unique identifier for the allele",
               name: "allele name"
               allele_type: "allele type"
             }, { < next match > }, ... ]
           Notes:
             - the "name" field of each returned match should have the
               search_string argument as a prefix
             - the "allele_type" should be one of the entries in the
               allele_type_list configuration map in canto.yaml
           Example result searching for "rad":
             [{
               "description": "wild type",
               "display_name": "ste20+(wild type)",
               "uniquename": "SPBC12C2.02c:allele-5",
               "name": "ste20+",
               "allele_type": "wild type"
             },
             {
               "uniquename": "SPBC12C2.02c:allele-3",
               "display_name": "ste20delta(deletion)",
               "description": "deletion",
               "name": "ste20delta",
               "allele_type": "deletion"
             }]

=cut

sub lookup
{
  my $self = shift;

  my %args = @_;

  my $gene_primary_identifier = $args{gene_primary_identifier};
  if (!defined $gene_primary_identifier) {
    die "no gene primary name passed to lookup()";
  }

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

  my @search_args = ('lower(features.name)', { -like => lc $search_string . '%' });

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

