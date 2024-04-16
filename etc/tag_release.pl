#!/usr/bin/perl -w

# This script will tag the current master with the next available
# version number (eg. v321) and then push the changes to GitHub
# and Bitbucket

use strict;
use warnings;
use Carp;

my $current_branch = `git rev-parse --abbrev-ref HEAD`;
chomp $current_branch;

if ($current_branch ne 'master') {
  warn "not on master branch - exiting\n";
  exit 1;
}

my $version_prefix = "v";

sub get_current_version
{
  my $describe = `git describe --tags --always --match "$version_prefix*"`;

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

  local $/ = undef;

  open my $config_fh, '<', 'canto.yaml' or die "$!";
  my $contents = <$config_fh>;
  close $config_fh or die "$!";

  my $old_contents = $contents;

  $contents =~ s/(app_version:\s*)(.*)/$1$new_version/m;

  open $config_fh, '>', 'canto.yaml' or die "$!";
  print $config_fh $contents;
  close $config_fh or die "$!";

  system "git commit -m 'Update to version $new_version' canto.yaml";

#  system "git tag -s -a -m 'Version $new_version' $new_version"
  system "git tag -a -m 'Version $new_version' $new_version"
}

sub make_release_branch
{
  my $new_version = shift;
  system "git branch release/$version_prefix$new_version";
  system "git branch -f release/latest release/$version_prefix$new_version";
}

sub stash
{
  open my $stash_fh, 'git stash|' or die "$!";

  my $stashed = 0;
  my $nothing_to_save = 0;

  my $save = '';

  while (defined (my $line = <$stash_fh>)) {
    if ($line =~ /No local changes to save/) {
      $nothing_to_save = 1;
    }
    if ($line =~ /Saved working directory/) {
      $stashed = 1;
    }

    $save .= $line;
  }

  close $stash_fh or die "$!";

  if (!$stashed && !$nothing_to_save) {
    die "couldn't parse git stash output:\n$save";
  }

  return $stashed;
}

print 'current version: ', `git describe --always`, "\n";

my $stashed = stash();

print "pulling from GitHub\n";
system "git pull";

my $new_version = get_new_version();
print 'new version: ', $new_version, "\n";
tag_version($new_version);

# make_release_branch($new_version);

print "pushing to GitHub\n";
system "git push --tags github master";
print "done\n\n";

if (@ARGV > 0 && $ARGV[0] eq '-a') {
  print "pushing to Bitbucket\n";
  system "git push --tags bitb master";
  print "done\n\n";
}

END {
  if ($stashed) {
    system "git stash pop";
  }
}
