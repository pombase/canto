package Canto::Curs::MetadataStorer;

=head1 NAME

Canto::Curs::MetadataStorer - Code for storing Curs metadata

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::MetadataStorer

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

use Canto::Curs::State;

with 'Canto::Role::MetadataAccess';
with 'Canto::Curs::Role::GeneResultSet';

has config => (is => 'ro', isa => 'Canto::Config',
               required => 1);

has state => (is => 'ro', init_arg => undef,
              isa => 'Canto::Curs::State',
              lazy_build => 1);

use constant {
  # the session was pre-populated with genes from Chado associated with
  # the publication
  SESSION_HAS_EXISTING_GENES => "session_has_existing_genes",
};

sub _build_state
{
  my $self = shift;
  my $state = Canto::Curs::State->new(config => $self->config());

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

=head2 store_counts

 Usage   : $metadata_storer->store_counts($curs_schema);
 Function: Update the counts that are cached in the metadata table, then
           call State::store_statuses()
 Args    : $curs_schema - the CursDB to update
 Return  : nothing

=cut

sub store_counts
{
  my $self = shift;
  my $schema = shift;

  if (!defined $schema) {
    die "no schema passed to _store_counts()";
  }

  my $ontology_lookup =
    Canto::Track::get_adaptor($self->config(), 'ontology');

  my $ann_rs = $schema->resultset('Annotation')->search();

  my $term_suggestion_count = 0;
  my $unknown_conditions_count = 0;

  while (defined (my $ann = $ann_rs->next())) {
    next if $ann->status() eq 'deleted';

    my $data = $ann->data();

    $unknown_conditions_count +=
      _count_unknown_conditions($ontology_lookup, $data->{conditions});

    if (defined $data->{term_suggestion} &&
        ($data->{term_suggestion}->{name} || $data->{term_suggestion}->{definition})) {
      $term_suggestion_count++;
    }
  }

  $self->set_metadata($schema, Canto::Curs::State::TERM_SUGGESTION_COUNT_KEY(),
                      $term_suggestion_count);
  $self->set_metadata($schema, Canto::Curs::State::UNKNOWN_CONDITIONS_COUNT_KEY(),
                      $unknown_conditions_count);

  $self->state()->store_statuses($schema);
}

1;
