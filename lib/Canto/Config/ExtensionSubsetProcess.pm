package Canto::Config::ExtensionSubsetProcess;

=head1 NAME

Canto::Config::ExtensionSubsetProcess - Read the domains and ranges from the
  extension configuration and use owltools to find the child terms.  Store
  canto_subset cvtermprops to record this.

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Config::ExtensionSubsetProcess

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;

has config => (is => 'ro', isa => 'Canto::Config',
               required => 1);

use File::Temp qw/ tempfile /;
use List::MoreUtils qw(uniq);

sub get_owltools_results
{
  my $self = shift;
  my $obo_file_name = shift;

  my ($temp_fh, $temp_filename) = tempfile();

  system ("owltools $obo_file_name --save-closure-for-chado $temp_filename") == 0
    or die "can't open pipe from owltools: $?";

  open my $owltools_out, '<', $temp_filename
    or die "can't open owltools output from $temp_filename: $!\n";

  return $owltools_out;
}

=head2 process

 Usage   : $extension_subset_process->process();
 Function: Read the domains and ranges from extension_configuration config,
           then use owtools to find the child terms in the given OBO files.
           Each cvterm gets a canto_subset cvtermprop for each config file
           term it's a child of.  For more details see:
           https://github.com/pombase/canto/wiki/AnnotationExtensionConfig
 Args    : $track_schema - the database to load
           @obo_filenames - the OBO files to process
 Return  : None - dies on failure

=cut

sub process
{
  my $self = shift;
  my $schema = shift;
  my @obo_file_names = @_;

  my $config = $self->config();

  my $ext_conf = $config->{extension_configuration};

  if (!$ext_conf) {
    die "no extension configuration file set\n";
  }

  my @conf = @{$ext_conf};

  my %subsets = ();

  for my $obo_file_name (@obo_file_names) {
    my $pipe_from_owltools = $self->get_owltools_results($obo_file_name);

    while (defined (my $line = <$pipe_from_owltools>)) {
      chomp $line;
      my ($subject, $rel_type, $depth, $object) =
        split (/\t/, $line);

      die $line unless $rel_type;

      $rel_type =~ s/^OBO_REL://;

      for my $conf (@conf) {
        if ($conf->{domain} eq $object && $conf->{subset_rel} eq $rel_type) {
          $subsets{$subject}{$object} = 1;
        }
      }
    }
  }

  # the configuration applies to the domain term ID, not just its descendants
  for my $conf (@conf) {
    $subsets{$conf->{domain}}{$conf->{domain}} = 1;
  }

  my @domains = uniq map { $_->{domain}; } @conf;

  my %db_names = ();

  map {
    if (/(\w+):/) {
      $db_names{$1} = 1;
    }
  } keys %subsets;

  my @db_names = keys %db_names;

  my $cvterm_rs =
    $schema->resultset('Cvterm')->search({
      'db.name' => { -in => \@db_names },
    }, {
      join => { dbxref => 'db' },
      prefetch => { dbxref => 'db' }
    });

  my $canto_subset_term =
    $schema->resultset('Cvterm')->find({ name => 'canto_subset',
                                         'cv.name' => 'cvterm_property_type' },
                                       {
                                         join => 'cv' });

  while (defined (my $cvterm = $cvterm_rs->next())) {
    my $db_accession = $cvterm->db_accession();

    my $prop_rs =
      $cvterm->cvtermprop_cvterms()
      ->search({
        type_id => $canto_subset_term->cvterm_id(),
      });

    my $guard = $schema->txn_scope_guard();

    $prop_rs->delete();

    my $subset_ids = $subsets{$db_accession};

    if ($subset_ids) {
      my @subset_ids = keys %{$subset_ids};

      for (my $rank = 0; $rank < @subset_ids; $rank++) {
        my $subset_id = $subset_ids[$rank];
        $schema->resultset('Cvtermprop')->create({
          cvterm_id => $cvterm->cvterm_id(),
          type_id => $canto_subset_term->cvterm_id(),
          value => $subset_id,
          rank => $rank,
        });
      }
    }

    $guard->commit();
  }
}

1;
