package Canto::Role::ChadoExtensionDisplayer;

=head1 NAME

Canto::Role::ChadoExtensionDisplayer -
   Code for creating a human readable string (GAF file style) from an
   annotation extension.

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Role::ChadoExtensionDisplayer

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2016 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Carp;
use Moose::Role;

requires 'schema';
requires 'gene_lookup';

sub _systematic_id_to_name
{
  my $self = shift;
  my $systematic_id = shift;

  if (!defined $systematic_id) {
    return "UNKNOWN";
  }

  my $res = $self->gene_lookup()->lookup([$systematic_id]);

  my $found = $res->{found};

  if (!defined $found) {
    warn "internal error: can't find gene for $systematic_id using gene_lookup";
    return "UNKNOWN";
  }

  my @found_genes = grep {
    $_->{primary_identifier} eq $systematic_id;
  } @{$found};

  if (@found_genes > 1) {
    warn "internal error: lookup returned more than one gene for $systematic_id";
  }

  if (@found_genes == 0) {
    warn "lookup failed for gene: $systematic_id using gene_lookup";
    return "UNKNOWN";
  }

  return $found_genes[0]->{primary_name} || $systematic_id;
}

sub _id_of_cvterm
{
  my $cvterm = shift;

  my $dbxref = $cvterm->dbxref();
  return $dbxref->db()->name() . ':' . $dbxref->accession();
}


=head2 make_gaf_extension

 Usage   : my ($extension_text, $parent_term) = $self->make_gaf_extension($feature_cvterm);
 Function: If the FeatureCvterm has a Cvterm with an extension, return
           the "column 16" extension text for the term and the parent
           (GO) term, otherwise return an empty list.

=cut
sub make_gaf_extension
{
  my $self = shift;
  my $feature_cvterm = shift;

  my $extension_term = $feature_cvterm->cvterm();

  if ($extension_term->cv()->name() ne 'PomBase annotation extension terms') {
    return ();
  }

  my $parent_rels_rs =
    $self->schema()->resultset("CvtermRelationship")->
    search({ 'subject_id' => $extension_term->cvterm_id() },
           {
             prefetch => { object => { dbxref => 'db' }, type => 'cv' },
           });

  my @parents = ();

  my $isa_parent_term = undef;

  while (defined (my $rel = $parent_rels_rs->next())) {
    if ($rel->type()->name() eq 'is_a') {
      $isa_parent_term = $rel->object();
    } else {
      my $rel_cv_name = $rel->type()->cv()->name();
      push @parents, { rel_type_name => $rel->type()->name(),
                       detail => _id_of_cvterm($rel->object()) };
    }
  }

  if (!defined $isa_parent_term) {
    croak "can't find parent term for: ", $extension_term->name();
  }

  my $annotation_ex_prefix = "annotation_extension_relation-";

  my $props_rs =
    $feature_cvterm->cvterm()->cvtermprops()->
    search({ 'type.name' => { -like => "$annotation_ex_prefix%" }, },
           { join => 'type' });

  my $db_name = $self->config()->{database_name};

  while (defined (my $prop = $props_rs->next())) {
    if ($prop->type()->name() =~ /^$annotation_ex_prefix(.*)/) {
      my $identifier = $prop->value();
      my $rel_name = $1;
      if ($identifier !~ /:/) {
        # hopefully it's a gene name, or at least some sort of PomBase ID
        $identifier = $self->_systematic_id_to_name($identifier);
        $identifier = "$db_name:$identifier";
      }
      push @parents, { rel_type_name => $rel_name,
                       detail => $identifier, };
    } else {
      die "internal error - unexpected name: ", $prop->type()->name();
    }
  }

  @parents =
    sort { $a->{rel_type_name} cmp $b->{rel_type_name}
             ||
           $a->{detail} cmp $b->{detail} } @parents;

  my $extension_parts =
    [
      map {
        {
          relation => $_->{rel_type_name},
          rangeValue => $_->{detail},
        };
      } @parents
    ];
  my $extension_text = join ",", map { $_->{rel_type_name} . "(" . $_->{detail} . ")" } @parents;

  return ([$extension_parts], $extension_text, $isa_parent_term);
}

1;
