#!/usr/bin/env perl

use perl5i::2;
use Moose;

use File::Temp qw/ tempfile /;

sub usage
{
  my $message = shift;

  if ($message) {
    warn "$message\n";
  }

  die "usage:
  $0 extension_conf_file <OBO file names>
";
}

if (!@ARGV || $ARGV[0] eq '-h' || $ARGV[0] eq '--help') {
  usage();
}

my ($extension_conf_file, @filenames) = @ARGV;

if (!@filenames) {
  usage "missing OBO file name argument(s)";
}

sub parse_conf
{
  my $conf_fh = shift;

  my %res = ();

  while (defined (my $line = <$conf_fh>)) {
    chomp $line;

    my ($domain, $domain_name, $allowed_extension, $range, $display_text) =
      split (/\t/, $line);

    if (!defined $display_text) {
      die "config line has too few fields: $line\n";
    }

    $res{$domain} = {
      domain_name => $domain_name,
      allowed_extension => $allowed_extension,
      range => $range,
      display_text => $display_text,
    };
  }

  return %res;
}

open my $conf_fh, '<', $extension_conf_file
  or die "can't open $extension_conf_file: $!\n";

my %conf = parse_conf($conf_fh);

close $conf_fh or die "$!\n";

for my $filename (@filenames) {
  my ($temp_fh, $temp_filename) = tempfile();

  system ("owltools $filename --save-closure-for-chado $temp_filename") == 0
    or die "can't open pipe from owltools: $?";

  open my $owltools_out, '<', $temp_filename
    or die "can't open owltools output from $temp_filename: $!\n";

  while (defined (my $line = <$owltools_out>)) {
    chomp $line;
    my ($subject, $rel_type, $depth, $object) =
      split (/\t/, $line);

    die $line unless $rel_type;

    next unless $rel_type eq 'is_a' or $rel_type eq 'OBO_REL:is_a';

    if ($conf{$object}) {
      print "$line\n";
    }
  }
}
