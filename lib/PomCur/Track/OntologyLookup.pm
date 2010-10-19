package PomCur::Track::OntologyLookup;

=head1 NAME

PomCur::Track::OntologyLookup - Lookup/search methods for ontologies

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Track::GOLookup

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

with 'PomCur::Configurable';
with 'PomCur::Track::TrackLookup';

my %terms_by_id = (
  'GO:0004022' => { id => 'GO:0004022',
                    name => 'alcohol dehydrogenase (NAD) activity',
                    definition => 'Catalysis of the reaction: an alcohol + NAD+ = an aldehyde or ketone + NADH + H+.',
                    children => [qw(GO:0004023 GO:0004024 GO:0004025 GO:0010301)],
                  },
  'GO:0004023' => { id => 'GO:0004023',
                    name => 'alcohol dehydrogenase activity, metal ion-independent',
                    definition => 'Catalysis of the reaction: an alcohol + NAD+ = an aldehyde or ketone + NADH + H+; can proceed in the absence of a metal ion.',
                  },
  'GO:0004024' => { id => 'GO:0004024',
                    name => 'alcohol dehydrogenase activity, zinc-dependent',
                    definition => 'Catalysis of the reaction: an alcohol + NAD+ = an aldehyde or ketone + NADH + H+, requiring the presence of zinc.',
                  },
  'GO:0004025' => { id => 'GO:0004025',
                    name => 'alcohol dehydrogenase activity, iron-dependent',
                    definition => 'Catalysis of the reaction: an alcohol + NAD+ = an aldehyde or ketone + NADH + H+, requiring the presence of iron.',
                  },
  'GO:0010301' => { id => 'GO:0010301',
                    name => 'xanthoxin dehydrogenase activity',
                  },
  'GO:0016614' => { id => 'GO:0016614',
                    name => 'oxidoreductase activity, acting on CH-OH group of donors',
                    definition => 'Catalysis of an oxidation-reduction (redox) reaction in which a CH-OH group act as a hydrogen or electron donor and reduces a hydrogen or electron acceptor.',
                    children => [qw(GO:0016616)],
                  },
  'GO:0016616' => { id => 'GO:0016616',
                    name => 'oxidoreductase activity, acting on the CH-OH group of donors, NAD or NADP as acceptor',
                    definition => 'Catalysis of an oxidation-reduction (redox) reaction in which a CH-OH group acts as a hydrogen or electron donor and reduces NAD+ or NADP.',
                    children => [qw(GO:0004022 GO:0016509 GO:0004471 GO:0004473 GO:0050491 GO:0050492)],
                  },
  'GO:0016509' => { id => 'GO:0016509',
                    name => 'long-chain-3-hydroxyacyl-CoA dehydrogenase activity',
                  },
  'GO:0004471' => { id => 'GO:0004471',
                    name => 'malate dehydrogenase (decarboxylating) activity',
                  },
  'GO:0004473' => { id => 'GO:0004473',
                    name => 'malate dehydrogenase (oxaloacetate-decarboxylating) (NADP+) activity',
                  },
  'GO:0050491' => { id => 'GO:0050491',
                    name => 'sulcatone reductase activity',
                  },
  'GO:0050492' => { id => 'GO:0050492',
                    name => 'glycerol-1-phosphate dehydrogenase [NAD(P)+] activity',
                  },
);

my %terms_by_name = ();

for my $go_id (keys %terms_by_id) {
  my $term_hash = $terms_by_id{$go_id};
  $terms_by_name{$term_hash->{name}} = $term_hash;
}

=head2 web_service_lookup

 Usage   : my $lookup = PomCur::Track::OntologyLookup->new(...);
           my $result =
             $lookup->web_service_lookup($c, $search_type,
                                         $ontology_name, $search_string);
 Function: Return matching ontology terms
 Args    : $c - the Catalyst object
           $ontology_name - the ontology to search
           $search_string - the text to use when searching
 Returns : for search_type "term", returns [ { match => 'description ...' }, ...
=cut
sub web_service_lookup
{
  my $self = shift;
  my %args = @_;

  my $ontology_name = $args{ontology_name};
  my $search_string = $args{search_string};
  my $max_results = $args{max_results};
  my $include_definition = $args{include_definition};
  my $include_children = $args{include_children};

  my @ret = ();

  for my $key (keys %terms_by_id) {
    my $term = $terms_by_id{$key};

    if ($key =~ /^$search_string/i || $term->{name} =~ /^$search_string/i) {
      my %ret_term = %$term;

      delete $ret_term{children};

      if (!$include_definition) {
        delete $ret_term{definition};
      }

      if ($include_children) {
        my @children = ();

        if (defined $term->{children}) {
          for my $child_id (@{$term->{children}}) {
            my $child = $terms_by_id{$child_id};
            push @children, $child;
          }
        }

        @{$ret_term{children}} = @children;
      }

      push @ret, \%ret_term;

      if (@ret >= $max_results) {
        last;
      }
    }
  }

  return \@ret;
}

1;
