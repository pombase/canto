package Canto::Curs::State;

=head1 NAME

Canto::Curs::State - Code for setting and getting the sessions state

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Curs::State

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2012-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use feature "switch";
use Moose;
use Carp qw(carp croak longmess);
use Scalar::Util qw(reftype);

use Canto::Util;

use Canto::Track::CuratorManager;

with 'Canto::Role::MetadataAccess';
with 'Canto::Curs::Role::GeneResultSet';
with 'Canto::Role::Configurable';

use constant {
  # user needs to confirm name and email address
  SESSION_CREATED => "SESSION_CREATED",
  # no genes in database, user needs to upload some
  SESSION_ACCEPTED => "SESSION_ACCEPTED",
  # session can be used for curation
  CURATION_IN_PROGRESS => "CURATION_IN_PROGRESS",
  # session has been paused by the user
  CURATION_PAUSED => "CURATION_PAUSED",
  # user has indicated that they are finished
  NEEDS_APPROVAL => "NEEDS_APPROVAL",
  # sessions is being checked by a curator
  APPROVAL_IN_PROGRESS => "APPROVAL_IN_PROGRESS",
  # session has been checked by a curator
  APPROVED => "APPROVED",
  # session has been exported to JSON
  EXPORTED => "EXPORTED",
};

my @approval_not_started_states = (SESSION_CREATED, SESSION_ACCEPTED, CURATION_IN_PROGRESS,
                                   CURATION_PAUSED);

sub approval_not_started_states
{
  return @approval_not_started_states;
}

use constant {
  SESSION_CREATED_TIMESTAMP_KEY => 'session_created_timestamp',
  CURATION_PAUSED_TIMESTAMP_KEY => 'curation_paused_timestamp',
  CURATION_IN_PROGRESS_TIMESTAMP_KEY => 'curation_in_progress_timestamp',
  NEEDS_APPROVAL_TIMESTAMP_KEY => 'needs_approval_timestamp',
  APPROVED_TIMESTAMP_KEY => 'approved_timestamp',
  ACCEPTED_TIMESTAMP_KEY => 'accepted_timestamp',
  APPROVAL_IN_PROGRESS_TIMESTAMP_KEY => 'approval_in_progress_timestamp',
  EXPORTED_TIMESTAMP_KEY => 'exported_timestamp',
  TERM_SUGGESTION_COUNT_KEY => 'term_suggestion_count',
  UNKNOWN_CONDITIONS_COUNT_KEY => 'unknown_conditions_count',
  APPROVER_NAME_KEY => 'approver_name',
  APPROVER_EMAIL_KEY => 'approver_email',
  NO_ANNOTATION_REASON_KEY => 'no_annotation_reason',
  REACTIVATED_TIMESTAMP_KEY => 'reactivated_timestamp',
};

use Sub::Exporter -setup => {
  exports => [ qw/SESSION_CREATED SESSION_ACCEPTED CURATION_IN_PROGRESS
                  CURATION_PAUSED
                  NEEDS_APPROVAL APPROVAL_IN_PROGRESS APPROVED EXPORTED
                  approval_not_started_states/ ],
};

has status_adaptor => (is => 'ro', init_arg => undef, lazy_build => 1);

has curator_manager => (is => 'ro', init_arg => undef,
                        lazy_build => 1,
                        isa => 'Canto::Track::CuratorManager');

sub _build_status_adaptor
{
  my $self = shift;

  return Canto::Track::get_adaptor($self->config(), 'status');
}

sub _build_curator_manager
{
  my $self = shift;

  return Canto::Track::CuratorManager->new(config => $self->config());
}

=head2 get_state

 Usage   : my ($current_state, $submitter, $gene_count, $datestamp) =
             $state->get_state($curs_schema);
 Function: Return a constant describing the state of the application,
           eg. SESSION_ACCEPTED or APPROVED and some details about the current
           state
 Args    : $curs_schema - the CursDB object for a session
 Return  : $current_state - a constant describing the state (eg. EXPORTED)
           $submitter - a hash_ref with the details of the current curator if the
                        state isn't SESSION_CREATED.  the keys of the hash_ref are:
                         - email_address
                         - name
           $gene_count - the number of genes added to the session, if the state
                         isn't SESSION_CREATED or SESSION_ACCEPTED
           $datestamp - the date and time when the session entered the given
                        state, if known

=cut

sub get_state
{
  my $self = shift;
  my $schema = shift;

  if (@_ > 0) {
    croak "too many arguments for get_state()";
  }

  if (!defined $schema) {
    croak "no schema passed to get_state()";
  }

  my $curs_key = $self->get_metadata($schema, 'curs_key');

  my ($submitter_email, $submitter_name, $submitter_known_as, $accepted_date) =
    $self->curator_manager()->current_curator($curs_key);
  my $state = undef;

  my $gene_rs = $self->get_ordered_gene_rs($schema);
  my $gene_count = $gene_rs->count();

  my %all_metadata = $self->all_metadata($schema);

  my $datestamp = undef;

  if (defined $all_metadata{EXPORTED_TIMESTAMP_KEY()}) {
    $state = EXPORTED;
    $datestamp = $all_metadata{EXPORTED_TIMESTAMP_KEY()};
  } else {
    if (defined $all_metadata{APPROVED_TIMESTAMP_KEY()}) {
      $state = APPROVED;
      $datestamp = $all_metadata{APPROVED_TIMESTAMP_KEY()};
    } else {
      if (defined $all_metadata{APPROVAL_IN_PROGRESS_TIMESTAMP_KEY()}) {
        $state = APPROVAL_IN_PROGRESS;
        $datestamp = $all_metadata{APPROVAL_IN_PROGRESS_TIMESTAMP_KEY()};
      } else {
        if (defined $all_metadata{NEEDS_APPROVAL_TIMESTAMP_KEY()}) {
          $state = NEEDS_APPROVAL;
          $datestamp = $all_metadata{NEEDS_APPROVAL_TIMESTAMP_KEY()};
        } else {
          if (defined $all_metadata{CURATION_PAUSED_TIMESTAMP_KEY()}) {
            $state = CURATION_PAUSED;
            $datestamp = $all_metadata{CURATION_PAUSED_TIMESTAMP_KEY()};
          } else {
            if (defined $submitter_email && defined $accepted_date) {
              if ($gene_count > 0) {
                $state = CURATION_IN_PROGRESS;
                $datestamp = $all_metadata{CURATION_IN_PROGRESS_TIMESTAMP_KEY()};
              } else {
                $state = SESSION_ACCEPTED;
                $datestamp = $accepted_date;
              }
            } else {
              $state = SESSION_CREATED;
              $datestamp = $all_metadata{SESSION_CREATED_TIMESTAMP_KEY()};
            }
          }
        }
      }
    }
  }

  my $submitter = undef;

  if (defined $submitter_email && defined $submitter_name) {
    $submitter = {
      email_address => $submitter_email,
      name => $submitter_name
    }
  }

  return ($state, $submitter, $gene_count, $datestamp);
}

=head2

 Usage   : $self->store_statuses($schema)
 Function: Store all the current state via the status adaptor
 Args    : $schema - the CursDB object
 Returns : nothing

=cut
sub store_statuses
{
  my $self = shift;
  my $schema = shift;

  if (@_ > 0) {
    croak "too many arguments for store_statuses()";
  }

  my ($status, $submitter, $gene_count, $datestamp) = $self->get_state($schema);

  my $metadata_rs = $schema->resultset('Metadata');
  my $curs_key_row = $metadata_rs->find({ key => 'curs_key' });

  if (!defined $curs_key_row) {
    warn 'failed to read curs_key from: ', $schema->storage()->connect_info();
    return;
  }
  my $curs_key = $curs_key_row->value();

  my $term_suggest_count_row =
    $metadata_rs->search({ key => TERM_SUGGESTION_COUNT_KEY })->first();

  my $term_suggestion_count;

  if (defined $term_suggest_count_row) {
    $term_suggestion_count = $term_suggest_count_row->value();
  } else {
    $term_suggestion_count = 0;
  }

  my $unknown_conditions_count_row =
    $metadata_rs->search({ key => UNKNOWN_CONDITIONS_COUNT_KEY })->first();

  my $unknown_conditions_count;

  if (defined $unknown_conditions_count_row) {
    $unknown_conditions_count = $unknown_conditions_count_row->value();
  } else {
    $unknown_conditions_count = 0;
  }

  $self->status_adaptor()->store($curs_key, 'annotation_status', $status);
  $self->status_adaptor()->store($curs_key, 'annotation_status_datestamp', $datestamp);
  $self->status_adaptor()->store($curs_key, 'session_genes_count', $gene_count // 0);
  $self->status_adaptor()->store($curs_key, 'session_term_suggestions_count',
                                 $term_suggestion_count);
  $self->status_adaptor()->store($curs_key, 'session_unknown_conditions_count',
                                 $unknown_conditions_count);

  my $reactivated_timestamp_row =
    $metadata_rs->search({ key => REACTIVATED_TIMESTAMP_KEY })->first();

  if (defined $reactivated_timestamp_row) {
    $self->status_adaptor()->store($curs_key, 'session_reactivated_timestamp',
                                   $reactivated_timestamp_row->value());
  }

  my $approver_name_row = $metadata_rs->find({ key => 'approver_name' });
  if (defined $approver_name_row) {
    my $approver_name = $approver_name_row->value();
    $self->status_adaptor()->store($curs_key, 'approver_name', $approver_name);
  } else {
    # remove name
    $self->status_adaptor()->store($curs_key, 'approver_name');
  }
}

sub set_state
{
  my $self = shift;
  my $schema = shift;
  my $new_state = shift;
  my $options = shift // {};

  if (defined $options && reftype($options) ne 'HASH') {
    croak "last argument must be a hash ref of options";
  }

  my $force = $options->{force};
  my $current_user = $options->{current_user};

  my ($current_state) = $self->get_state($schema);

  if ($current_state eq $new_state && $force ne $current_state) {
    # nothing to do, but potentially a bug
    warn "NOOP: setting $current_state to $new_state - $force\n", longmess();
  }

  if ($current_state eq EXPORTED) {
    croak "can't change state from ", EXPORTED;
  }

  my %dispatch = (
    SESSION_ACCEPTED, sub {
      if ($current_state ne SESSION_CREATED && $force ne $current_state) {
        carp "can't accept a session unless it's in the " . SESSION_CREATED .
          qq|state (not "$current_state")|;
      }
      my $curs_key = $self->get_metadata($schema, 'curs_key');
      $self->curator_manager()->accept_session($curs_key);
      $self->set_metadata($schema, ACCEPTED_TIMESTAMP_KEY,
                        Canto::Util::get_current_datetime());
      $self->unset_metadata($schema, CURATION_IN_PROGRESS_TIMESTAMP_KEY);
      $self->unset_metadata($schema, CURATION_PAUSED_TIMESTAMP_KEY);
      $self->unset_metadata($schema, NEEDS_APPROVAL_TIMESTAMP_KEY);
      $self->unset_metadata($schema, APPROVAL_IN_PROGRESS_TIMESTAMP_KEY);
      $self->unset_metadata($schema, APPROVED_TIMESTAMP_KEY);
      $self->unset_metadata($schema, EXPORTED_TIMESTAMP_KEY);
      $self->unset_metadata($schema, APPROVER_NAME_KEY);
      $self->unset_metadata($schema, APPROVER_EMAIL_KEY);
    },
    CURATION_IN_PROGRESS, sub {
      if ($current_state ne CURATION_PAUSED &&
          $force ne $current_state) {
        carp "use force flag to change state to ",
          CURATION_IN_PROGRESS, " from ", $current_state;
      }
      $self->set_metadata($schema, CURATION_IN_PROGRESS_TIMESTAMP_KEY,
                          Canto::Util::get_current_datetime());
      $self->unset_metadata($schema, CURATION_PAUSED_TIMESTAMP_KEY);
      $self->unset_metadata($schema, NEEDS_APPROVAL_TIMESTAMP_KEY);
      $self->unset_metadata($schema, APPROVAL_IN_PROGRESS_TIMESTAMP_KEY);
      $self->unset_metadata($schema, APPROVED_TIMESTAMP_KEY);
      $self->unset_metadata($schema, EXPORTED_TIMESTAMP_KEY);
      $self->unset_metadata($schema, APPROVER_NAME_KEY);
      $self->unset_metadata($schema, APPROVER_EMAIL_KEY);
    },
    CURATION_PAUSED, sub {
      if ($current_state ne CURATION_IN_PROGRESS) {
        carp "trying to pause a session that isn't in the state ",
          CURATION_IN_PROGRESS, " it's currently: ", $current_state;
      }
      $self->set_metadata($schema, CURATION_PAUSED_TIMESTAMP_KEY,
                          Canto::Util::get_current_datetime());
      $self->unset_metadata($schema, NEEDS_APPROVAL_TIMESTAMP_KEY);
      $self->unset_metadata($schema, APPROVAL_IN_PROGRESS_TIMESTAMP_KEY);
      $self->unset_metadata($schema, APPROVED_TIMESTAMP_KEY);
      $self->unset_metadata($schema, EXPORTED_TIMESTAMP_KEY);
      $self->unset_metadata($schema, APPROVER_NAME_KEY);
      $self->unset_metadata($schema, APPROVER_EMAIL_KEY);
    },
    NEEDS_APPROVAL, sub {
      if ($current_state ne CURATION_IN_PROGRESS &&
          $force ne $current_state) {
        carp "trying to start approving a session that isn't in the state ",
          CURATION_IN_PROGRESS, " it's currently: ", $current_state;
      }
      $self->set_metadata($schema, NEEDS_APPROVAL_TIMESTAMP_KEY,
                          Canto::Util::get_current_datetime());
      $self->unset_metadata($schema, APPROVAL_IN_PROGRESS_TIMESTAMP_KEY);
      $self->unset_metadata($schema, APPROVED_TIMESTAMP_KEY);
      $self->unset_metadata($schema, EXPORTED_TIMESTAMP_KEY);
      $self->unset_metadata($schema, APPROVER_NAME_KEY);
      $self->unset_metadata($schema, APPROVER_EMAIL_KEY);
    },
    APPROVAL_IN_PROGRESS, sub {
      if ($current_state ne NEEDS_APPROVAL && $force ne $current_state) {
        carp "must be in state ", NEEDS_APPROVAL,
          " (not $current_state) to change to ",
          "state ", APPROVAL_IN_PROGRESS;
      }
      if (defined $current_user && $current_user->is_admin()) {
        $self->set_metadata($schema, APPROVER_NAME_KEY,
                            $current_user->name());
        $self->set_metadata($schema, APPROVER_EMAIL_KEY,
                            $current_user->email_address());
      } else {
        croak "must be admin user to start approval";
      }

      $self->set_metadata($schema, APPROVAL_IN_PROGRESS_TIMESTAMP_KEY,
                          Canto::Util::get_current_datetime());
      $self->unset_metadata($schema, APPROVED_TIMESTAMP_KEY);
      $self->unset_metadata($schema, EXPORTED_TIMESTAMP_KEY);
    },
    APPROVED, sub {
      unless (defined $current_user && $current_user->is_admin()) {
        croak "only admin users can approve sessions\n";
      }
      if ($current_state ne APPROVAL_IN_PROGRESS && !$force) {
        carp "must be in state ", APPROVAL_IN_PROGRESS,
          " (not $current_state) to change to state ", APPROVED;
      }
      $self->set_metadata($schema, APPROVED_TIMESTAMP_KEY,
                          Canto::Util::get_current_datetime());
      $self->unset_metadata($schema, EXPORTED_TIMESTAMP_KEY);
    },
    EXPORTED, sub {
      if ($current_state ne APPROVED) {
        carp "must be in state ", APPROVED,
          " (not $current_state) to change to state ", EXPORTED;
      }
      $self->set_metadata($schema, EXPORTED_TIMESTAMP_KEY,
                          Canto::Util::get_current_datetime());
    },
  );

  my $dispatch_sub = $dispatch{$new_state};

  if (defined $dispatch_sub) {
    $dispatch_sub->();
  } else {
    croak "can't handle state: $new_state";
  }

  my $approved_timestamp = $self->get_metadata($schema, APPROVED_TIMESTAMP_KEY);
  my $approver_email = $self->get_metadata($schema, APPROVER_EMAIL_KEY);
  if (defined $approved_timestamp && !defined $approver_email) {
    warn "inconsistent state after set_state():";
    warn longmess(), "\n";
  }

  $self->store_statuses($schema);
}

1;
