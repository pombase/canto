package Canto::Chado::GenotypeLookup;

=head1 NAME

Canto::Chado::GenotypeLookup - Look up genotypes in Chado

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Chado::GenotypeLookup

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use perl5i::2;
use Moose;

use Canto::Curs::Utils;

with 'Canto::Role::Configurable';
with 'Canto::Chado::ChadoLookup';

sub lookup
{
  my $self = shift;

  my %options = @_;

  if ($options{gene_primary_identifiers}) {
    my $schema = $self->schema();
    my $genotype_rs =
      $schema->resultset('Feature')->search({ 'type.name' => 'genotype' },
                                            { join => 'type' });

    my $gene_identifiers = $options{gene_primary_identifiers};

    my @sub_queries = map {
      my $gene_identifier = $_;
      my $sub_query =
        $schema->resultset('Feature')
          ->search({ 'type.name' => 'genotype',
                     'object_2.uniquename' => $gene_identifier,
                     'type_2.name' => 'allele',
                     'type_3.name' => 'gene',
                   },
                   { join => [ 'type',
                               {
                                 feature_relationship_subjects =>
                                   {
                                     object => [
                                       'type',
                                       {
                                         feature_relationship_subjects =>
                                           {
                                             object => 'type',
                                           }
                                         }
                                     ]
                                   }
                                 }
                             ]
                   });
      {
        'me.feature_id' =>
          {
            -in => $sub_query->get_column('feature_id')->as_query()
          }
        }
    } @$gene_identifiers;

    my $search_arg = {
      -and => \@sub_queries,
    };

    if ($options{max_results}) {
      $genotype_rs = $genotype_rs->search({}, { rows => $options{max_results} });
    }

    return
      {
        results => [
          map {
            {
              primary_identifier => $_->uniquename()
            }
          } $genotype_rs->search($search_arg)->all(),
        ],
      };
  } else {
    die "no gene_primary_identifiers option passed to lookup()";
  }
}

1;
