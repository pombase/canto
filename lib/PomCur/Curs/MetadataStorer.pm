package PomCur::Curs::MetadataStorer;

=head1 NAME

PomCur::Curs::MetadataStorer - Code for storing Curs metadata

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Curs::MetadataStorer

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;

with 'PomCur::Role::MetadataAccess';
with 'PomCur::Curs::Role::GeneResultSet';

has state => (is => 'ro', init_arg => undef,
              isa => 'PomCur::Curs::State',
              lazy_build => 1);

sub _build_state
{
  my $self = shift;
  my $state = PomCur::Curs::State->new();

  return $state;
}

sub _count_unknown_conditions
{
  my $lookup = shift;
  my $conditions = shift;

  return 0 unless defined $conditions;

  my $unknown_conditions_count = 0;

  for my $condition (@$conditions) {
    eval {
      my $result = $lookup->lookup_by_id(id => $condition);
      if (!defined $result) {
        $unknown_conditions_count++;
      }
    };
    if ($@) {
      $unknown_conditions_count++;
    }
  }

  return $unknown_conditions_count;
}

sub store_counts
{
  my $self = shift;
  my $config = shift;
  my $schema = shift;

  if (!defined $schema) {
    die "no schema passed to _store_counts()";
  }

  my $ontology_lookup =
    PomCur::Track::get_adaptor($config, 'ontology');

  my $ann_rs = $schema->resultset('Annotation')->search();

  my $term_suggestion_count = 0;
  my $unknown_conditions_count = 0;

  while (defined (my $ann = $ann_rs->next())) {
    my $data = $ann->data();

    $unknown_conditions_count +=
      _count_unknown_conditions($ontology_lookup, $data->{conditions});

    if (defined $data->{term_suggestion}) {
      $term_suggestion_count++;
    }
  }

  $self->set_metadata($schema, PomCur::Curs::State::TERM_SUGGESTION_COUNT_KEY(),
                      $term_suggestion_count);
  $self->set_metadata($schema, PomCur::Curs::State::UNKNOWN_CONDITIONS_COUNT_KEY(),
                      $unknown_conditions_count);

  $self->state()->store_statuses($config, $schema);
}

1;
