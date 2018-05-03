package Canto::Track::OrganismLookup;

=head1 NAME

Canto::Track::OrganismLookup - an adaptor to allow sessions to look up organism
                               details by taxon ID

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Track::OrganismLookup

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;

with 'Canto::Role::Configurable';
with 'Canto::Track::TrackAdaptor';

sub _make_organism_hash
{
  my $config = shift;
  my $organism = shift;

  my $taxonid = undef;

  my @props = grep {
    $_->type()->name() eq 'taxon_id';
  } $organism->organismprops()->all();

  if (@props) {
    $taxonid = $props[0]->value();
  }

  my $pathogen_or_host = 'unknown';

  if ($config->{pathogen_host_mode}) {
    $pathogen_or_host = 'pathogen';

    if (grep { $_ eq $taxonid } @{$config->{host_organism_taxonids}}) {
      $pathogen_or_host = 'host';
    }
  }

  return {
    genus => $organism->genus(),
    species => $organism->species(),
    full_name => $organism->genus() . ' ' . $organism->species(),
    taxonid => $taxonid,
    pathogen_or_host => $pathogen_or_host,
  }
}

=head2 lookup_by_type()

 Usage   : my $lookup = Canto::Track::get_adaptor($config, 'organism');
           my @organisms = $strain_lookup->lookup_by_type('host');
 Function: Retrieve organisms from the TrackDB
 Args    : $lookup_type - can only be "host" at the moment
 Return  : A list of organisms in the format:
           [ { genus => '...', species => '...', taxon_id => '...',
               pathogen_or_host => 'host' },
             { ... },
             ...
           ]

=cut

sub lookup_by_type
{
  my $self = shift;
  my $lookup_type = shift;

  my $schema = $self->schema();
  my $config = $self->config();

  my $organism_rs = $schema->resultset('Organism')->search();

  my @result_organisms = ();

  while (defined (my $organism = $organism_rs->next())) {
    my $organism_hash = _make_organism_hash($config, $organism);

    push @result_organisms, $organism_hash;
  }

  return @result_organisms;
}


sub lookup_by_taxonid
{
  my $self = shift;
  my $taxon_id = shift;

  my $schema = $self->schema();
  my $config = $self->config();

  my $organismprop_rs = $schema->resultset('Organismprop')->search();

  while (defined (my $prop = $organismprop_rs->next())) {
    if ($prop->type()->name() eq 'taxon_id' &&
        $prop->value() == $taxon_id) {
      return _make_organism_hash($config, $prop->organism());
    }
  }

  return undef;
}

1;
