package Canto::Curs::AlleleManager;

=head1 NAME

Canto::Curs::AlleleManager - Curs Allele CRUD functions

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::AlleleManager

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

use utf8;

has curs_schema => (is => 'rw', isa => 'Canto::CursDB', required => 1);
has gene_manager => (is => 'rw', isa => 'Canto::Curs::GeneManager',
                     lazy_build => 1);

with 'Canto::Role::Configurable';
with 'Canto::Curs::Role::GeneResultSet';

use Canto::Curs::GeneProxy;

sub _build_gene_manager
{
  my $self = shift;

  return Canto::Curs::GeneManager->new(config => $self->config(),
                                       curs_schema => $self->curs_schema());
}

sub _create_allele_uniquename
{
  my $gene_primary_identifier = shift;
  my $schema = shift;
  my $curs_key = shift;

  my $prefix = "$gene_primary_identifier:$curs_key-";

  my $rs;

  if ($gene_primary_identifier =~ /^aberration/) {
    $rs = $schema->resultset('Allele')
      ->search({ 'me.primary_identifier' => { -like => "$prefix%" } });
  } else {
    $rs = $schema->resultset('Allele')
      ->search({ 'gene.primary_identifier' => $gene_primary_identifier,
                 'me.primary_identifier' => { -like => "$prefix%" } },
               { join => 'gene' });
  }

  my $new_index = 1;

  while (defined (my $allele = $rs->next())) {
    if ($allele->primary_identifier() =~ /^$prefix(\d+)$/) {
       if ($1 >= $new_index) {
         $new_index = $1 + 1;
       }
     }
   }

   return "$gene_primary_identifier:$curs_key-$new_index";
}

sub set_allele_synonyms
{
  my $schema = shift;
  my $allele = shift;
  my $allele_synonyms = shift;

  my $rs = $allele->allelesynonyms()->search();

  my @existing = ();

  while (defined (my $syn = $rs->next())) {
    if ($syn->edit_status() eq 'existing') {
      push @existing, $syn->synonym();
    }
  }

  $rs->search({ edit_status => 'new' })->delete();

  map {
    my $syn = $_;
    if ($syn->{edit_status} eq 'new' ||
      !grep { $_ eq $syn->{synonym} } @existing) {
      $schema->create_with_type('Allelesynonym', {
        allele => $allele->allele_id(),
        synonym => $syn->{synonym},
        edit_status => $syn->{edit_status},
      });
    }
  } @$allele_synonyms;
}

sub autopopulate_name
{
  my $allele_type = shift;
  my $config = shift;
  my $gene = shift;

  my $allele_config = $config->{allele_types}->{$allele_type};

  if (!defined $allele_config) {
    return undef;
  }

  my $name_template = $allele_config->{autopopulate_name};

  if (!$name_template) {
    return undef;
  }

  my $gene_proxy =
    Canto::Curs::GeneProxy->new(config => $config, cursdb_gene => $gene);

  my $gene_display_name = $gene_proxy->display_name();

  return $name_template =~ s/\@\@gene_display_name\@\@/$gene_display_name/r;
}

# create a new Allele from the data or return an existing matching allele
sub allele_from_json
{
  my $self = shift;
  my $json_allele = shift;
  my $curs_key = shift;

  my $config = $self->config();
  my $schema = $self->curs_schema();

  my $primary_identifier = $json_allele->{primary_identifier};
  my $name = $json_allele->{name};

  # store deltas as "delta"
  my @deltas = (
    "\N{GREEK CAPITAL LETTER DELTA}",
    "\N{MATHEMATICAL BOLD CAPITAL DELTA}",
    "\N{MATHEMATICAL ITALIC CAPITAL DELTA}",
    "\N{MATHEMATICAL BOLD ITALIC CAPITAL DELTA}",
    "\N{MATHEMATICAL SANS-SERIF BOLD CAPITAL DELTA}",
    "\N{MATHEMATICAL SANS-SERIF BOLD ITALIC CAPITAL DELTA}",
  );
  my $delta_string = join '|', @deltas;
  if ($name) {
    $name =~ s/($delta_string)$/delta/;
  }

  my $description = $json_allele->{description};
  my $expression = $json_allele->{expression};
  my $promoter_gene = $json_allele->{promoter_gene};
  my $exogenous_promoter = $json_allele->{exogenous_promoter};
  my $allele_type = $json_allele->{type};
  my $gene_id = $json_allele->{gene_id};
  my $comment = $json_allele->{comment};
  my $notes = $json_allele->{notes};

  if ($primary_identifier) {
    # lookup existing allele
    my $allele = undef;

    $allele = $schema->resultset('Allele')
      ->find({
        primary_identifier => $primary_identifier,
      });

    if ($allele) {
      if (($expression // '') eq ($allele->expression() // '') and
          ($promoter_gene // '') eq ($allele->promoter_gene() // '') and
          ($exogenous_promoter // '') eq ($allele->exogenous_promoter() // '')) {
        return $allele;
      } else {
        # fall through and find another allele that matches, or create
        # another
      }
    } else {
      # find the Chado allele and add to the CursDB
      my $lookup = Canto::Track::get_adaptor($config, 'allele');

      my $allele_details = $lookup->lookup_by_uniquename($primary_identifier);

      if (!defined $allele_details) {
        die qq(internal error - allele "$primary_identifier" is missing);
      }

      $allele_type = $allele_details->{type};
      $description = $allele_details->{description};
      $name = $allele_details->{name};

      my $gene_identifier = $allele_details->{gene_uniquename};

      my $gene_rs = $self->get_ordered_gene_rs($schema);
      my $curs_gene = $gene_rs->find({
        primary_identifier => $gene_identifier,
      });

      if (!defined $curs_gene) {
        my $gene_lookup = Canto::Track::get_adaptor($config, 'gene');
        my $lookup_result = $gene_lookup->lookup([$gene_identifier]);
        my %new_gene_details =
          $self->gene_manager()->create_genes_from_lookup($lookup_result);

        $curs_gene = $new_gene_details{$gene_identifier};
      }

      $gene_id = $curs_gene->gene_id();
    }
  }

  my @allele_synonyms = @{$json_allele->{synonyms} // []};

  # find existing or make a new allele in the CursDB

  my %search_args = (
    type => $allele_type,
  );

  if ($allele_type !~ /^aberration/) {
    $search_args{gene} = $gene_id;
  }

  my $allele_rs = $schema->resultset('Allele')
    ->search({ %search_args });

  while (defined (my $allele = $allele_rs->next())) {
    if (($allele->name() // '') eq ($name // '') &&
        ($allele->description() // '') eq ($description // '') &&
        ($allele->expression() // '') eq ($expression // '') &&
        ($allele->promoter_gene() // '') eq ($promoter_gene // '') &&
        ($allele->exogenous_promoter() // '') eq ($exogenous_promoter // '')) {
      set_allele_synonyms($schema, $allele, \@allele_synonyms);

      return $allele;
    }
  }

  if (!$gene_id && $allele_type !~ /^aberration/) {
    use Data::Dumper;
    confess "internal error, no gene_id for: ", Dumper([$json_allele]);
  }

  my $new_primary_identifier;

  if ($allele_type =~ /^aberration/) {
    my $prefix;

    if ($name) {
      $prefix = "$name-$allele_type";
    } else {
      $prefix = $allele_type;
    }

    $prefix =~ s/\s+/_/g;

    $new_primary_identifier = _create_allele_uniquename($prefix, $schema, $curs_key);
  } else {
    my $gene = $schema->find_with_type('Gene', $gene_id);

    $new_primary_identifier =
      _create_allele_uniquename($gene->primary_identifier(), $schema, $curs_key);

    if (!$name) {
      $name = autopopulate_name($allele_type, $config, $gene);
    }
  }

  my %create_args = (
    primary_identifier => $new_primary_identifier,
    %search_args,
    name => $name || undef,
    description => $description || undef,
    comment => $comment || undef,
    expression => $expression || undef,
    promoter_gene => $promoter_gene || undef,
    exogenous_promoter => $exogenous_promoter || undef,
  );

  if ($allele_type =~ /_/) {
    die "internal error, underscore in allele type in Canto - probably an problem";
  }

  my $allele = $schema->create_with_type('Allele', \%create_args);

  set_allele_synonyms($schema, $allele, \@allele_synonyms);

  if ($notes) {
    while (my ($key, $value) = each %$notes) {
      $self->_set_note_with_allele($allele, $key, $value);
    }
  }

  return $allele;
}

=head2 create_simple_allele

 Usage   : my $allele = $allele_manager->create_simple_allele(...);
 Function: Create an Allele object given some allele properties and a gene
 Args    : $primary_identifier - the primary key in the database
           $allele_type
           $name
           $description
           $expression
           $gene - a Gene object
           $synonyms
 Returns : the new Allele

=cut

sub create_simple_allele
{
  my $self = shift;

  my $primary_identifier = shift;
  my $allele_type = shift;
  my $name = shift;
  my $description = shift;
  my $promoter_gene = shift;
  my $exogenous_promoter = shift;
  my $gene = shift;
  my $synonyms = shift;

  my %create_args = (
    primary_identifier => $primary_identifier,
    type => $allele_type,
    name => $name || undef,
    description => $description || undef,
    promoter_gene => $promoter_gene || undef,
    exogenous_promoter => $exogenous_promoter || undef,
  );

  if ($allele_type !~ /^aberration/) {
    $create_args{gene} = $gene->gene_id();
  }

  my $allele = $self->curs_schema()->create_with_type('Allele', \%create_args);

  if ($synonyms) {
    for my $synonym (@$synonyms) {
      my %synonym_create_args = (
        allele => $allele->allele_id(),
        synonym => $synonym,
        edit_status => 'existing'
      );

      $self->curs_schema()->create_with_type('Allelesynonym', \%synonym_create_args);

    }
  }

  return $allele;
}

sub _set_note_with_allele
{
  my $self = shift;
  my $allele = shift;
  my $key = shift;
  my $value = shift;

  my $existing = $allele->allele_notes()->find({ key => $key });

  if ($existing) {
    if (defined $value) {
      $existing->value($value);
      $existing->update();
    } else {
      $existing->delete();
    }
  } else {
    if (defined $value) {
      $self->curs_schema()
        ->create_with_type('AlleleNote',
                           {
                             allele => $allele->allele_id(),
                             key => $key,
                             value => $value,
                           });
    }
  }
}

=head2 set_note

 Usage   : $allele_manager->set_note($allele_primary_identifier, $key, $value);
 Function: Add a note to an Allele.  If a note with $key as the key exists
           replace the note.  If $value is undef, remove the note.
 Args    : $allele_primary_identifier
           $key - any string
           $value - any string
 Returns : nothing

=cut

sub set_note
{
  my $self = shift;
  my $allele_primary_identifier = shift;
  my $key = shift;
  my $value = shift;

  my $allele = $self->curs_schema()->resultset('Allele')
    ->find({ primary_identifier => $allele_primary_identifier });

  if (!$allele) {
    die qq(can't find allele with primary_identifier "$allele_primary_identifier");
  }

  $self->_set_note_with_allele($allele, $key, $value);
}
1;
