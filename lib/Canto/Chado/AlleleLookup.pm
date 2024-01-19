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

use feature qw(state);

use Moose;

use Canto::Curs::Utils;

with 'Canto::Role::Configurable';
with 'Canto::Chado::ChadoLookup';


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
               type: "allele type"
             }, { < next match > }, ... ]
           Notes:
             - the "name" field of each returned match should have the
               search_string argument as a prefix
             - the "type" should be one of the entries in the
               allele_type_list configuration map in canto.yaml
           Example result searching for "rad":
             [{
               "description": "wild type",
               "display_name": "ste20+(wild type)",
               "uniquename": "SPBC12C2.02c:allele-5",
               "name": "ste20+",
               "type": "wild type"
             },
             {
               "uniquename": "SPBC12C2.02c:allele-3",
               "display_name": "ste20delta(deletion)",
               "description": "deletion",
               "name": "ste20delta",
               "type": "deletion"
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

  my $max_results = $args{max_results} || 20;

  my $schema = $self->schema();

  my $gene_constraint_rs =
    $schema->resultset('FeatureRelationship')
           ->search({ 'object.uniquename' => $gene_primary_identifier },
                    { join => 'object' });

  $search_string =~ s/^\s+//;
  $search_string =~ s/\s+$//;

  my @search_args = ('lower(features.name)', { -like => '%' . lc $search_string . '%' });

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

  if (scalar(keys %res) < $max_results) {
    my $synonym_rs = $schema->resultset('Cv')
      ->search({ 'me.name' => 'sequence' })
      ->search_related('cvterms', { 'cvterms.name' => 'allele' })
      ->search_related('features')
      ->search({ 'features.feature_id' => {
                   -in => $gene_constraint_rs->get_column('subject_id')->as_query(),
                 },
                 'lower(synonym.name)' => { -like => '%' . lc $search_string . '%' }
               },
               { join => { feature_synonyms => 'synonym' } });

    map {
      $res{$_->feature_id()} = {
        name => $_->name(),
        uniquename => $_->uniquename(),
      };
    } $synonym_rs->all();
  }

  my $syn_rs = $schema->resultset('FeatureSynonym')
    ->search({ feature_id => { -in => [ keys %res ] } },
             { prefetch => { synonym => 'type' }});

  while (defined (my $row = $syn_rs->next())) {
    my $synonym = $row->synonym();
    my $allele = $res{$row->feature_id()};
    if (!grep {
      $_->{synonym} eq $synonym->name()
    } @{$allele->{synonyms}}) {
      push @{$allele->{synonyms}}, {
        synonym => $synonym->name(),
        edit_status => 'existing',
      };
    }
  }

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
      Canto::Curs::Utils::make_allele_display_name($self->config(),
                                                   $_->{name},
                                                   $_->{description},
                                                   $_->{allele_type});

    $_->{display_name} = $display_name;
    $_->{type} =
      Canto::Curs::Utils::canto_allele_type($self->config(),
                                            $_->{allele_type},
                                            $_->{description});
    $_->{synonyms} //= [];

    delete $_->{allele_type};
    $_;
  } @res ];
}

=head2 lookup_by_uniquename

 Usage   : my $allele_details = $lookup->lookup_by_uniquename($allele_uniquename);
 Function: Return the details of a given allele
 Args    : $allele_uniquename - the uniquename of the allele in the feature
                                table eg. "SPBC12C2.02c:allele-5"
 Return  : Returns a hash ref in the form:
             {
               "uniquename": "SPBC12C2.02c:allele-5",
               "name": "ste20+",
               "description": "wild type",
               "display_name": "ste20+(wild type)",
               "type": "wild type"
             }
           or undef if no allele is found

=cut

sub lookup_by_uniquename
{
  my $self = shift;
  my $uniquename = shift;

  my $schema = $self->schema();

  my $allele = $schema->resultset('Feature')->find({ uniquename => $uniquename,
                                                     'type.name' => 'allele' },
                                                   { join => 'type' });

  if (defined $allele) {
    my $allele_gene = $allele->feature_relationship_subjects()
      ->search({ 'type.name' => 'instance_of' },
               {
                 join => 'type' })
        ->search_related('object',
                         {
                           'type_2.name' => 'gene',},
                         {
                           join => 'type' })->first();

    my $gene_uniquename = undef;

    if ($allele_gene) {
      $gene_uniquename = $allele_gene->uniquename();
    } else {
      die qq(allele "$uniquename" has no gene\n);
    }

    my %props = map {
      ($_->type()->name(), $_->value())
    } $allele->featureprops()->all();

    my $display_name =
      Canto::Curs::Utils::make_allele_display_name($self->config(),
                                                   $allele->name(),
                                                   $props{description},
                                                   $props{allele_type});

    my $allele_type =
      Canto::Curs::Utils::canto_allele_type($self->config(),
                                            $props{allele_type},
                                            $props{description});

    return {
      uniquename => $uniquename,
      display_name => $display_name,
      name => $allele->name(),
      description => $props{description},
      type => $allele_type,
      gene_uniquename => $gene_uniquename,
      synonyms => [],
    }
  }

  return undef;
}

state $cache_by_gene_uniquename = {};
state $cache_by_canto_systematic_id = {};

sub _fill_allele_caches
{
  my $self = shift;

  my $schema = $self->schema();

  my $allele_rs = $schema->resultset('Feature')
    ->search({ 'type.name' => 'allele',
               'type_2.name' => 'instance_of',
               'type_3.name' => 'gene',
             },
             { join => ['type',
                        { feature_relationship_subjects =>
                          ['type',
                           { object => 'type' } ] }],
               prefetch => { feature_relationship_subjects => 'object',
                             featureprops => 'type' }});

  map {
    my $allele = $_;

    my @featureprops = $allele->featureprops()->all();

    my $description;
    my $allele_type;
    my @canto_allele_systematic_ids = ();

    map {
      my $prop_type = $_->type()->name();

      if ($prop_type eq 'description') {
        $description = $_->value();
      } else {
        if ($prop_type eq 'allele_type') {
          $allele_type = $_->value();
        } else {
          if ($prop_type eq 'canto_allele_systematic_id') {
            push @canto_allele_systematic_ids, $_->value();
          }
        }
      }
    } @featureprops;

    my $gene_uniquename = $allele->feature_relationship_subjects()->first()->object()->uniquename();

    my $allele_details = {
      gene_systematic_id => $gene_uniquename,
      name => $allele->name(),
      type => $allele_type,
      description => $description,
      allele_systematic_id => $allele->uniquename(),
      canto_allele_systematic_ids => \@canto_allele_systematic_ids,
    };

    push @{$cache_by_gene_uniquename->{$gene_uniquename}}, $allele_details;

    map {
      push @{$cache_by_canto_systematic_id->{$_}}, $allele_details;
    } @canto_allele_systematic_ids;
  } $allele_rs->all();
}


=head2 lookup_by_details

 Usage   : @alleles = $lu->lookup_by_details($gene_uniquename, $allele_type,
                                             $allele_description);
 Function: lookup alleles matching a given type and description

=cut

sub lookup_by_details
{
  my $self = shift;

  my $gene_uniquename = shift;
  my $allele_type = shift;
  my $allele_description = shift // 'NO_DESCRIPTION';

  if (scalar(keys %$cache_by_gene_uniquename) == 0) {
    $self->_fill_allele_caches();
  }

  if (defined $cache_by_gene_uniquename->{$gene_uniquename}) {
    my @alleles =  @{$cache_by_gene_uniquename->{$gene_uniquename}};

    return grep {
      my $_test_allele = $_;

      $_test_allele->{type} eq $allele_type &&
        ($allele_type =~ /^(deletion|wild[ _]type)$/ ||
         ($_test_allele->{description} // 'NO_DESCRIPTION') eq $allele_description);
    } @alleles;
  } else {
    return ();
  }
}


=head2 lookup_by_canto_systematic_id

 Usage   : my @alleles = $self->lookup_by_canto_systematic_id($canto_systematic_id);

=cut

sub lookup_by_canto_systematic_id
{
  my $self = shift;
  my $canto_systematic_id = shift;

  if (scalar(keys %$cache_by_canto_systematic_id) == 0) {
    $self->_fill_allele_caches();
  }

  if (defined $cache_by_canto_systematic_id->{$canto_systematic_id}) {
    return @{$cache_by_canto_systematic_id->{$canto_systematic_id}};
  } else {
    return ();
  }
}

1;
