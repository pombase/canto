package PomCur::Chado::AlleleLookup;

=head1 NAME

PomCur::Chado::AlleleLookup - Look up alleles in Chado

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Chado::AlleleLookup

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;

with 'PomCur::Role::Configurable';
with 'PomCur::Chado::ChadoLookup';


sub lookup
{
  my $self = shift;

  my %args = @_;

  my $search_string = $args{search_string};
  if (!defined $search_string) {
    die "no search_string parameter passed to lookup()";
  }

  my $max_results = $args{max_results} || 10;

  my $schema = $self->schema();

  my $rs = $schema->resultset('Cv')
    ->search({ 'me.name' => 'sequence' })
    ->search_related('cvterms', { 'cvterms.name' => 'allele' })
    ->search_related('features')
    ->search({ 'features.name' => { -like => "$search_string\%" } },
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

  return [sort { $a->{name} cmp $b->{name} } values %res];
}

1;

