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
use Carp;

with 'Canto::Role::Configurable';
with 'Canto::Track::TrackAdaptor';

our $cache = {};

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
    scientific_name => $organism->scientific_name(),
    full_name => $organism->scientific_name(),
    common_name => $organism->common_name(),
    taxonid => $taxonid,
    pathogen_or_host => $pathogen_or_host,
  }
}

=head2 lookup_by_type()

 Usage   : my $lookup = Canto::Track::get_adaptor($config, 'organism');
           my @organisms = $lookup->lookup_by_type('host');
 Function: Retrieve organisms from the TrackDB
 Args    : $lookup_type - can only be "host" at the moment
 Return  : A list of organisms in the format:
           [ { scientific_name => '...', taxon_id => '...',
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

    if ($lookup_type) {
      if ($organism_hash->{pathogen_or_host}) {
        next unless $lookup_type eq $organism_hash->{pathogen_or_host};
      } else {
        next;
      }
    }

    push @result_organisms, $organism_hash;
  }

  return @result_organisms;
}

=head2 lookup_by_type()

 Usage   : my $lookup = Canto::Track::get_adaptor($config, 'organism');
           my $organism = $lookup->lookup_by_taxonid(4896);
 Function: Retrieve an organism by taxon id from the TrackDB
 Return  : A hash of organism details in the format:
           { scientific_name => '...', taxon_id => '...',
             pathogen_or_host => 'host' }

=cut
sub lookup_by_taxonid
{
  my $self = shift;
  my $taxon_id = shift;

  if (!defined $taxon_id) {
    croak "no taxon ID passed to OrganismLookup::lookup_by_taxonid()\n";
  }

  if (exists $cache->{$taxon_id}) {
    return $cache->{$taxon_id};
  }

  my $schema = $self->schema();
  my $config = $self->config();

  my $organismprop_rs = $schema->resultset('Organismprop')->search();

  while (defined (my $prop = $organismprop_rs->next())) {
    if ($prop->type()->name() eq 'taxon_id' &&
        $prop->value() == $taxon_id) {
      $cache->{$taxon_id} = _make_organism_hash($config, $prop->organism());
      return $cache->{$taxon_id};
    }
  }

  return undef;
}

1;
