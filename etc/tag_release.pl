#!/usr/bin/perl -w

# This script will tag the current master with the next available
# version number (v321), then creates a branch release/v321 and
# updates the release/latest branch to point to latest release

use strict;
use warnings;
use Carp;

my $version_prefix = "v";

sub move_to_master
{
  system "git checkout master";
}

sub get_current_version
{
  my $describe = `git describe --always --match "$version_prefix*"`;

  if ($describe =~ /^$version_prefix(\d+)/) {
    if ($describe =~ /^$version_prefix(\d+)$/) {
      die "no changes since last version\n";
    } else {
      return $1;
    }
  } else {
    warn "git describe didn't return a version starting with: $version_prefix\n";
    return undef;
  }
}

sub get_new_version
{
  my $current_version = get_current_version();

  if (defined $current_version) {
    return $current_version + 1;
  } else {
    0;
  }
}

sub tag_version
{
  my $new_version = $version_prefix . get_new_version();

  system "git tag -s -a -m 'Version $new_version' $new_version"
}

sub make_release_branch
{
  my $new_version = shift;
  system "git branch release/$version_prefix$new_version";
  system "git branch -f release/latest release/$version_prefix$new_version";
}

move_to_master();
print 'current version: ', `git describe --always`, "\n";

my $new_version = get_new_version();
print 'new version: ', $new_version, "\n";
tag_version($new_version);

make_release_branch($new_version);
