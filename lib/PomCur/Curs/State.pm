package PomCur::Curs::State;

=head1 NAME

PomCur::Curs::State - Code for setting and getting the sessions state

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PomCur::Curs::State

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use feature "switch";
use Moose::Role;
use Carp;

requires 'get_metadata', 'set_metadata';

use constant {
  # user needs to confirm name and email address
  SESSION_CREATED => "SESSION_CREATED",
  # no genes in database, user needs to upload some
  SESSION_ACCEPTED => "SESSION_ACCEPTED",
  # session can be used for curation
  CURATION_IN_PROGRESS => "CURATION_IN_PROGRESS",
  # user has indicated that they are finished
  NEEDS_APPROVAL => "NEEDS_APPROVAL",
  # sessions is being checked by a curator
  APPROVAL_IN_PROGRESS => "APPROVAL_IN_PROGRESS",
  # session has been checked by a curator
  APPROVED => "APPROVED",
  # session has been exported to JSON
  EXPORTED => "EXPORTED",
};

use constant {
  NEEDS_APPROVAL_TIMESTAMP_KEY => 'needs_approval_timestamp',
  APPROVED_TIMESTAMP_KEY => 'approved_timestamp',
  APPROVAL_IN_PROGRESS_TIMESTAMP_KEY => 'approval_in_progress_timestamp',
  EXPORTED_TIMESTAMP_KEY => 'exported_timestamp',
  TERM_SUGGESTION_COUNT_KEY => 'term_suggestion_count'
};

use Sub::Exporter -setup => {
  exports => [ qw/SESSION_CREATED SESSION_ACCEPTED CURATION_IN_PROGRESS
                  NEEDS_APPROVAL APPROVAL_IN_PROGRESS APPROVED EXPORTED/ ],
};

# Return a constant describing the state of the application, eg. SESSION_ACCEPTED
# or DONE.  See the %state hash above for details
sub get_state
{
  my $schema = shift;

  my $submitter_email = get_metadata($schema, 'submitter_email');

  my $state = undef;
  my $gene_count = undef;

  if (defined $submitter_email) {
    my $gene_rs = get_ordered_gene_rs($schema);
    $gene_count = $gene_rs->count();

    if ($gene_count > 0) {
      if (defined get_metadata($schema, EXPORTED_TIMESTAMP_KEY)) {
        $state = EXPORTED;
      } else {
        if (defined get_metadata($schema, APPROVED_TIMESTAMP_KEY)) {
          $state = APPROVED;
        } else {
          if (defined get_metadata($schema, APPROVAL_IN_PROGRESS_TIMESTAMP_KEY)) {
            $state = APPROVAL_IN_PROGRESS;
          } else {
            if (defined get_metadata($schema, NEEDS_APPROVAL_TIMESTAMP_KEY)) {
              $state = NEEDS_APPROVAL;
            } else {
              $state = CURATION_IN_PROGRESS;
            }
          }
        }
      }
    } else {
      $state = SESSION_ACCEPTED;
    }
  } else {
    $state = SESSION_CREATED;
  }

  return ($state, $submitter_email, $gene_count);
}

=head2

 Usage   : PomCur::Controller::Curs::store_statuses($config, $schema)
 Function: Store all the current state via the status adaptor
 Args    : $config - the Config object
           $schema - the CursDB object
 Returns : nothing

=cut
sub store_statuses
{
  my $config = shift;
  my $schema = shift;

  my $adaptor = PomCur::Track::get_adaptor($config, 'status');

  my ($status, $submitter_email, $gene_count) = get_state($schema);

  my $metadata_rs = $schema->resultset('Metadata');
  my $metadata_row = $metadata_rs->find({ key => 'curs_key' });

  if (!defined $metadata_row) {
    warn 'failed to read curs_key from: ', $schema->storage()->connect_info();
    return;
  }

  my $curs_key = $metadata_row->value();

  my $term_suggest_count_row =
    $metadata_rs->search({ key => TERM_SUGGESTION_COUNT_KEY })->first();

  my $term_suggestion_count;

  if (defined $term_suggest_count_row) {
    $term_suggestion_count = $term_suggest_count_row->value();
  } else {
    $term_suggestion_count = 0;
  }

  $adaptor->store($curs_key, 'annotation_status', $status);
  $adaptor->store($curs_key, 'session_genes_count', $gene_count // 0);
  $adaptor->store($curs_key, 'session_term_suggestions_count',
                  $term_suggestion_count);
}

sub _store_suggestion_count
{
  my $schema = shift;

  my $ann_rs = $schema->resultset('Annotation')->search();

  my $count = 0;

  while (defined (my $ann = $ann_rs->next())) {
    my $data = $ann->data();

    if (exists $data->{term_suggestion}) {
      $count++;
    }
  }

  set_metadata($schema, TERM_SUGGESTION_COUNT_KEY, $count);
}


my $iso_date_template = "%4d-%02d-%02d";

sub _get_datetime
{
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
  return sprintf "$iso_date_template %02d:%02d:%02d",
    1900+$year, $mon+1, $mday, $hour, $min, $sec;
}

sub set_state
{
  my $config = shift;
  my $schema = shift;
  my $new_state = shift;
  my $force = shift;

  my $current_state = get_state($schema);

  if ($current_state eq EXPORTED) {
    croak "can't change state from ", EXPORTED;
  }

  my $guard = $schema->txn_scope_guard;

  given ($new_state) {
    when (CURATION_IN_PROGRESS) {
      if (!$force) {
        croak "use force flag to change state to ",
          CURATION_IN_PROGRESS;
      }
      unset_metadata($schema, NEEDS_APPROVAL_TIMESTAMP_KEY);
      unset_metadata($schema, APPROVAL_IN_PROGRESS_TIMESTAMP_KEY);
      unset_metadata($schema, APPROVED_TIMESTAMP_KEY);
      unset_metadata($schema, EXPORTED_TIMESTAMP_KEY);
    }
    when (NEEDS_APPROVAL) {
      if (!$force and $current_state ne CURATION_IN_PROGRESS) {
        croak "trying to approve a session that isn't in the state ",
          CURATION_IN_PROGRESS;
      }
      set_metadata($schema, NEEDS_APPROVAL_TIMESTAMP_KEY, _get_datetime());
      unset_metadata($schema, APPROVAL_IN_PROGRESS_TIMESTAMP_KEY);
      unset_metadata($schema, APPROVED_TIMESTAMP_KEY);
      unset_metadata($schema, EXPORTED_TIMESTAMP_KEY);
    }
    when (APPROVAL_IN_PROGRESS) {
      if ($current_state ne NEEDS_APPROVAL) {
        croak "must be in state ", NEEDS_APPROVAL, " to change to ",
          "state ", APPROVAL_IN_PROGRESS;
      }
      set_metadata($schema, APPROVAL_IN_PROGRESS_TIMESTAMP_KEY, _get_datetime());
      unset_metadata($schema, APPROVED_TIMESTAMP_KEY);
      unset_metadata($schema, EXPORTED_TIMESTAMP_KEY);
    }
    when (APPROVED) {
      if ($current_state ne APPROVAL_IN_PROGRESS) {
        croak "must be in state ", APPROVAL_IN_PROGRESS,
          " to change to state ", APPROVED;
      }
      set_metadata($schema, APPROVED_TIMESTAMP_KEY, _get_datetime());
      unset_metadata($schema, EXPORTED_TIMESTAMP_KEY);
    }
    when (EXPORTED) {
      if ($current_state ne APPROVED) {
        croak "must be in state ", APPROVED, " to change to state ",
          EXPORTED;
      }
      set_metadata($schema, EXPORTED_TIMESTAMP_KEY, _get_datetime());
    }
  };

  $guard->commit();

  store_statuses($config, $schema);
}

1;
