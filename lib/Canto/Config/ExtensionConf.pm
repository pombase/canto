package Canto::Config::ExtensionConf;

=head1 NAME

Canto::Config::ExtensionConf - Code for parsing the extension
                                    configuration table

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Config::ExtensionConf

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use strict;
use warnings;

=head2

 Usage   : my $conf = Canto::Config::ExtensionConf::parse($file_name);
 Function: Read the extension configuration table
 Args    : $file_name
 Return  : Returns a list of hashes like:
           [ { domain => 'GO:0004672', domain_name => 'protein kinase activity',
               subset_rel => 'is_a', allowed_extension => 'has_substrate',
               range => 'GO:0008372' }, ... ]
           The range can be a term ID or "GENE"
=cut

sub parse
{
  my $extension_conf_file = shift;

  open my $conf_fh, '<', $extension_conf_file
    or die "can't open $extension_conf_file: $!\n";

  my @res = ();

  while (defined (my $line = <$conf_fh>)) {
    chomp $line;

    my ($domain, $domain_name, $subset_rel, $allowed_extension, $range, $display_text) =
      split (/\t/, $line);

    if (!defined $display_text) {
      die "config line has too few fields: $line\n";
    }

    push @res, {
      domain => $domain,
      domain_name => $domain_name,
      subset_rel => $subset_rel,
      allowed_extension => $allowed_extension,
      range => $range,
      display_text => $display_text,
    };
  }

  close $conf_fh or die "can't close $extension_conf_file: $!\n";

  return @res;
}

1;
