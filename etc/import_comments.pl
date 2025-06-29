#!/usr/bin/env perl

# Import annotation comments, exported by export_comments.pl
# usage:
#   import_comments.pl original_comments_filename new_comments_filename
#
# the original comments file is used to check that no comments have been
# edited in Canto since exporting
#
# See also: pombe-embl/supporting_files/canto-annotation-comments.txt

use strict;
use warnings;
use Carp;

use Digest::SHA qw(sha1_base64);
use Encode;

use File::Basename;

BEGIN {
  my $script_name = basename $0;

  if (-f $script_name && -d "../etc") {
    chdir "..";
  }
};

use open ':std', ':encoding(UTF-8)';

use lib qw(lib);

use Canto::Config;
use Canto::TrackDB;
use Canto::ChadoDB;
use Canto::Meta::Util;


my $app_name = Canto::Config::get_application_name();

$ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';

my $suffix = $ENV{CANTO_CONFIG_LOCAL_SUFFIX};

if (!Canto::Meta::Util::app_initialised($app_name, $suffix)) {
  die "The application is not yet initialised, try running the canto_start " .
    "script\n";
}

my $config = Canto::Config::get_config();
my $track_schema = Canto::TrackDB->new(config => $config);
my $chado_schema = Canto::ChadoDB->new(config => $config);


my $orig_comments_filename = shift;
my $new_comments_filename = shift;


sub read_comments
{
  my $filename = shift;
  my $is_orig = shift;

  my %comments = ();

  open my $fh, '<', $filename or die;

 COMMENT:
  while (1) {
    if (defined (my $header = <$fh>)) {
      if ($header =~ /^COMMENT: ([a-f0-9]{4,}) (\d+) ([a-zA-Z\d=+\/]+)/) {
        my $curs_key = $1;
        my $annotation_id = $2;
        my $hash = $3;

        my @comment_lines = ();

        while (defined (my $line = <$fh>)) {
          chomp $line;
          if ($line eq '-------') {
            my $comment = join "\n", @comment_lines;
            my $checksum = sha1_base64(Encode::encode_utf8($comment));

            if ($is_orig && $checksum ne $hash) {
              die "checksum failed: $comment\n";
            }

            $comments{"$curs_key $annotation_id"} = {
              hash => $hash,
              comment => $comment,
            };
            next COMMENT;
          } else {
            push @comment_lines, $line;
          }
        }
      } else {
        die "can't parse header: $header\n";
      }
    } else {
      last COMMENT;
    }
  }

  return %comments;
}


my %orig_comments = read_comments($orig_comments_filename, 1);
my %new_comments = read_comments($new_comments_filename, 0);


my $proc = sub {
  my $curs = shift;
  my $cursdb = shift;
  my $curs_key = $curs->curs_key();

  my $annotation_rs = $cursdb->resultset('Annotation');

  while (defined (my $annotation = $annotation_rs->next())) {
    my $data = $annotation->data();

    if ($data->{submitter_comment}) {
      my $db_comment = $data->{submitter_comment};
      $db_comment =~ s/\s+/ /g;

      my $key = "$curs_key " . $annotation->annotation_id();

      my $orig_comment = $orig_comments{$key};
      if ($orig_comment) {
        $orig_comment->{comment} =~ s/\s+/ /g;
      }

      my $new_comment = $new_comments{$key};
      next unless defined $new_comment;
      $new_comment->{comment} =~ s/\s+/ /g;

      if (defined $orig_comment->{comment} &&
          $orig_comment->{comment} ne $db_comment) {
        if (lc $db_comment ne lc $new_comment->{comment} &&
          lc $db_comment ne lc $new_comment->{comment} =~ s/\(comment: /(/r) {
          warn "comment has changed since export: $key:\n";
          warn "  was: ", $orig_comment->{comment}, "\n";
          warn "  now: $db_comment\n";
          warn "  new comment: ", $new_comment->{comment}, "\n";
        }
        next;
      }

      if (!$db_comment || $new_comment->{comment} ne $db_comment) {
        $data->{submitter_comment} = $new_comment->{comment};
        $annotation->data($data);
        $annotation->update();
      }
    }
  }
};

my $txn_proc = sub {
  Canto::Track::curs_map($config, $track_schema, $proc);
};

$track_schema->txn_do($txn_proc);

