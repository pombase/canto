package Canto::Controller::Curs;

use base 'Catalyst::Controller::HTML::FormFu';

=head1 NAME

Canto::Controller::Curs - curs (curation session) controller

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Controller::Curs

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009-2013 University of Cambridge, all rights reserved.

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=head1 FUNCTIONS

=cut

use Carp;
use Moose;

use Canto::Curs::State qw/:all/;

use IO::String;
use Clone qw(clone);
use Hash::Merge;
use Carp qw(cluck);
use JSON;
use List::MoreUtils;
use Try::Tiny;
use Data::JavaScript::Anon;

use Canto::Track;
use Canto::Curs::Utils;
use Canto::Curs::MetadataStorer;
use Canto::Curs::AlleleManager;
use Canto::Curs::GeneManager;
use Canto::Curs::GenotypeManager;
use Canto::MailSender;
use Canto::EmailUtil;
use Canto::Curs::State;
use Canto::Curs::ServiceUtils;
use Canto::Util qw(trim);

use Canto::Curs 'EXTERNAL_NOTES_KEY';

use constant {
  MESSAGE_FOR_CURATORS_KEY => 'message_for_curators',
};

# actions to execute for each state, undef for special cases
my %state_dispatch = (
  SESSION_CREATED, 'introduction',
  SESSION_ACCEPTED, 'gene_upload',
  CURATION_IN_PROGRESS, undef,
  CURATION_PAUSED, 'curation_paused',
  NEEDS_APPROVAL, 'finished_publication',
  APPROVAL_IN_PROGRESS, undef,
  APPROVED, 'finished_publication',
  EXPORTED, 'session_exported',
);

# used by the tests to find the most recently created annotations
our $_debug_annotation_ids = undef;

has state => (is => 'rw', init_arg => undef,
              isa => 'Canto::Curs::State');

has metadata_storer => (is => 'rw', init_arg => undef,
                        isa => 'Canto::Curs::MetadataStorer');

has curator_manager => (is => 'rw', init_arg => undef,
                        isa => 'Canto::Track::CuratorManager');

with 'Canto::Role::MetadataAccess';
with 'Canto::Role::GAFFormatter';
with 'Canto::Curs::Role::GeneResultSet';
with 'Canto::Curs::Role::CuratorSet';

=head2 top

 Action to set up stash contents for curs

=cut
sub top : Chained('/') PathPart('curs') CaptureArgs(1)
{
  my ($self, $c, $curs_key) = @_;

  if (!defined $self->state()) {
    $self->state(Canto::Curs::State->new(config => $c->config()));
  }
  if (!defined $self->metadata_storer()) {
    $self->metadata_storer(Canto::Curs::MetadataStorer->new(config => $c->config()));
  }
  if (!defined $self->curator_manager()) {
    $self->curator_manager(Canto::Track::CuratorManager->new(config => $c->config()));
  }

  my $st = $c->stash();

  $st->{curs_key} = $curs_key;
  my $schema = Canto::Curs::get_schema($c);

  if (!defined $schema) {
    $c->forward('not_found');
    $c->detach();
  }

  $st->{schema} = $schema;

  my $path = $c->req->uri()->path();
  $st->{current_path_uri} = $path;

  (my $controller_name = __PACKAGE__) =~ s/.*::(.*)/\L$1/;
  $st->{controller_name} = $controller_name;

  my $root_path = "/$controller_name/$curs_key";
  $st->{curs_root_path} = $root_path;

  my $root_uri = $c->uri_for($root_path);
  $st->{curs_root_uri} = $root_uri;

  my $config = $c->config();

  $st->{annotation_types} = $config->{annotation_types};
  $st->{annotation_type_list} = $config->{annotation_type_list};

  my ($state, $submitter, $gene_count) = $self->state()->get_state($schema);
  my $submitter_email = $submitter->{email_address};
  my $submitter_name = $submitter->{name};

  $st->{state} = $state;

  if ($state eq APPROVAL_IN_PROGRESS) {
    my $approver_name = $self->get_metadata($schema, 'approver_name');
    my $approver_email = $self->get_metadata($schema, 'approver_email');
    push @{$st->{notice}},
      "Session is being checked by $approver_name <$approver_email>";
  }

  if (defined $config->{message_of_the_day}) {
    push @{$st->{notice}}, $config->{message_of_the_day};
  }

  $st->{is_admin_session} =
    $self->get_metadata($schema, 'admin_session');

  $st->{instance_organism} = $config->{instance_organism};
  $st->{multi_organism_mode} = !defined $st->{instance_organism};
  $st->{strains_mode} = $config->{strains_mode};
  $st->{pathogen_host_mode} = $config->{pathogen_host_mode};
  $st->{split_genotypes_by_organism} = $config->{split_genotypes_by_organism};
  $st->{show_genotype_management_genes_list} = $config->{show_genotype_management_genes_list};

  $st->{flybase_mode} = $config->{flybase_mode};
  $st->{annotation_figure_field} = $config->{annotation_figure_field};

  $st->{show_metagenotype_links} = 0;
  $st->{edit_organism_page_valid} = 0;

  if ($st->{pathogen_host_mode}) {
    ($st->{show_metagenotype_links}, $st->{show_host_genotype_link},
     $st->{has_pathogen_genes},
     $st->{has_host_genotypes}, $st->{has_pathogen_genotypes},
     $st->{has_pathogen_host_metagenotypes},
     $st->{edit_organism_page_valid}) =
      _metagenotype_flags($config, $schema);
  }

  my $with_gene_evidence_codes =
    { map { ( $_, 1 ) }
      grep { $config->{evidence_types}->{$_}->{with_gene} } keys %{$config->{evidence_types}} };
  $st->{with_gene_evidence_codes} = $with_gene_evidence_codes;

  my $genotype_annotation_configured = 0;

  map {
    if ($_->{feature_type} eq 'genotype') {
      $genotype_annotation_configured = 1;
    }
  } @{$config->{annotation_type_list}};

  $st->{genotype_annotation_configured} = $genotype_annotation_configured;

  # curation_pub_id will be set if we are annotating a particular publication,
  # rather than annotating genes without a publication
  my $pub_id = $self->get_metadata($schema, 'curation_pub_id');
  $st->{pub} = $schema->find_with_type('Pub', $pub_id);

  die "internal error, can't find Pub for pub_id $pub_id"
    if not defined $st->{pub};

  $st->{submitter_email} = $submitter_email;
  $st->{submitter_name} = $submitter_name;

  my $message_to_curators = $self->get_metadata($schema, MESSAGE_FOR_CURATORS_KEY);
  $st->{message_to_curators} = $message_to_curators;

  my $external_notes = $self->get_metadata($schema, Canto::Curs->EXTERNAL_NOTES_KEY);

  # enabled by default and disabled on /session_reassigned page
  $st->{show_curator_in_title} = 1;

  $st->{gene_count} = $schema->resultset('Gene')->count();
  $st->{genotype_count} = $schema->resultset('Genotype')->count();

  if ($path =~ m!/ro/?$!) {
    $st->{read_only_curs} = 1;
    my $message;
    if ($state eq EXPORTED) {
      $message = "Review only - this session has been exported so no changes are possible";
    } else {
      if ($state eq NEEDS_APPROVAL || $state eq APPROVAL_IN_PROGRESS) {
        $message = "Review only - this session has been submitted for approval.  Please contact the helpdesk to make further changes.";
      } else {
        $message = "Review only - this session can be viewed but not edited";
      }
    }
    $st->{message} = [$message];
  }

  my $use_dispatch = 1;

  my $current_user = $c->user();

  if (defined $current_user && $current_user->is_admin()) {
    $st->{current_user_is_admin} = 1;

    $self->set_metadata($schema, 'annotation_mode', 'advanced');

    if ($external_notes) {
      $st->{external_notes} = [split /\n+/, $external_notes];
    }
  } else {
    $st->{current_user_is_admin} = 0;
  }

  if ($st->{current_user_is_admin} &&
      ($state eq NEEDS_APPROVAL || $state eq APPROVAL_IN_PROGRESS || $state eq APPROVED) &&
      defined $message_to_curators && $message_to_curators !~ /^\s*$/) {
    push @{$st->{notice}}, qq|This session has a message to curators: $message_to_curators|;
  }

  if ($config->{canto_offline} && !$st->{read_only_curs} &&
        (!defined $current_user || !$current_user->is_admin()) &&
        $path !~ m:/(ws/\w+/list):) {
    $c->detach('offline_message');
    $use_dispatch = 0;
  }

  if ($st->{pathogen_host_mode} && !$st->{edit_organism_page_valid} &&
        $state eq CURATION_IN_PROGRESS && $path !~ m:(/ws/|/gene_upload/):) {
    $c->detach('edit_genes');
  }

  if ($state eq APPROVAL_IN_PROGRESS) {
    if ($c->user_exists() && $c->user()->role()->name() eq 'admin') {
      # fall through, use dispatch table
      my $unused_genotype_count = _unused_genotype_count($c);

      # front page only:
      if ($unused_genotype_count > 0 && $root_path eq $path) {
        if ($st->{message}) {
          if (!ref $st->{message}) {
            $st->{message} = [$st->{message}];
          }
        } else {
          $st->{message} = [];
        }

        if ($unused_genotype_count == 1) {
          push @{$st->{message}}, "Warning: there is an unused genotype in this session";
        } else {
          push @{$st->{message}}, "Warning: there are $unused_genotype_count unused genotypes in this session";
        }
      }
    } else {
      if ($path !~ m!/ro/?$|ws/\w+/list!) {
        $c->detach('finished_publication');
      }
    }
  }

  if ($state ne SESSION_CREATED && $state ne SESSION_ACCEPTED &&
      $path =~ m|/view_genes_and_strains(?:/(?:ro)?)?$|) {
    if ($st->{pathogen_host_mode}) {
      $c->detach('view_genes_and_strains');
    } else {
      if ($state eq NEEDS_APPROVAL || $state eq APPROVAL_IN_PROGRESS ||
          $state eq APPROVED || $state eq EXPORTED) {
        $c->detach('finished_publication');
      } else {
        $c->detach('front');
      }
    }
  }

  if ($state eq SESSION_ACCEPTED &&
      $path =~ m:/(gene_upload|edit_genes|genotype_manage|metagenotype_manage|confirm_genes|finish_form|ws):) {
    $use_dispatch = 0;
  }

  if (($state eq NEEDS_APPROVAL || $state eq APPROVED) &&
      $path =~ m:/(ro|finish_form|reactivate_session|set_exported_state|begin_approval|restart_approval|annotation/zipexport|ws/):) {
    $use_dispatch = 0;
  }

  if ($state eq CURATION_PAUSED && $path =~ m:/(ws/settings/(set/paused_message|get_all)|ws/.*/list|restart_curation|ro):) {
    $use_dispatch = 0;
  }

  if ($state eq SESSION_CREATED && $path =~ m:/assign_session:) {
    $use_dispatch = 0;
  }

  if (($state eq SESSION_CREATED ||
       $state eq SESSION_ACCEPTED ||
       $state eq CURATION_IN_PROGRESS ||
       $state eq CURATION_PAUSED) && $path =~ m:/reassign_session|/session_reassigned:) {
    $use_dispatch = 0;
  }

  if ($state eq EXPORTED && $path =~ m:/unexport_session|/ro/?$|/ws/:) {
    $use_dispatch = 0;
  }

  if ($state eq CURATION_IN_PROGRESS) {
    my $existing_genes =
      $self->get_metadata($schema, Canto::Curs::MetadataStorer::SESSION_HAS_EXISTING_GENES);

    if (defined $existing_genes) {
      $self->unset_metadata($schema, Canto::Curs::MetadataStorer::SESSION_HAS_EXISTING_GENES);
      my $pub_uniquename = $st->{pub}->uniquename();
      push @{$st->{message}}, qq|Note: This session has been populated with genes from the $pub_uniquename abstract, PubMed keywords and other sources. Use the "Add more genes" link to add missing genes. You can also add, or remove, genes at any time during curation.|;
      $c->detach('edit_genes');
      $use_dispatch = 0;
    }
  }

  if ($use_dispatch) {
    my $dispatch_dest = $state_dispatch{$state};
    if (defined $dispatch_dest) {
      $c->detach($dispatch_dest);
    }
  }
}

sub _unused_genotype_count
{
  my $c = shift;
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $genotype_rs = $schema->resultset('Genotype')
    ->search({}, { where => \"genotype_id NOT IN (SELECT genotype FROM genotype_annotation)" });

  return $genotype_rs->count();
}

sub _metagenotype_flags
{
  my $config = shift;
  my $schema = shift;

  my $organism_lookup = Canto::Track::get_adaptor($config, 'organism');

  my $rs = $schema->resultset('Organism');

  my $has_host = 0;
  my $has_pathogen_genes = 0;
  my $has_host_genes = 0;
  my $has_host_genotypes = 0;
  my $has_pathogen_genotypes = 0;
  my $has_pathogen_host_metagenotypes = 0;

  my $organism_page_valid = 1;

  while (defined (my $org = $rs->next())) {
    my $organism_details = $organism_lookup->lookup_by_taxonid($org->taxonid());

    if (!defined $organism_details->{pathogen_or_host}) {
      next;
    }

    if ($organism_details->{pathogen_or_host} eq 'host') {
      $has_host = 1;
      my $org_genotypes_rs = $org->genotypes();

      while (defined (my $genotype = $org_genotypes_rs->next())) {
        if ($genotype->alleles()->count() > 0) {
          $has_host_genotypes = 1;
          last;
        }
      }

      if ($org->genes()->count() > 0) {
        $has_host_genes = 1;
      }
    }

    if ($organism_details->{pathogen_or_host} eq 'pathogen') {
      if ($org->genotypes()->count() > 0) {
        $has_pathogen_genotypes = 1;
      }
      if ($org->genes()->count() > 0) {
        $has_pathogen_genes = 1;
      }
    }

    if ($org->strains()->count() == 0) {
      $organism_page_valid = 0;
    }
  }

  if (!$has_pathogen_genes) {
    $organism_page_valid = 0;
  }

  if ($has_pathogen_genes) {
    my $rs = $schema->resultset('Metagenotype')
      ->search({}, { prefetch => { first_genotype => 'organism',
                                   second_genotype => 'organism' } });

    while (defined (my $metagenotype = $rs->next())) {
      my $first_genotype = $metagenotype->first_genotype();
      my $first_organism = $first_genotype->organism();

      my $first_org_details =
        $organism_lookup->lookup_by_taxonid($first_organism->taxonid());

      if (!defined $first_org_details->{pathogen_or_host}) {
        next;
      }

      my $second_genotype = $metagenotype->second_genotype();
      my $second_organism = $second_genotype->organism();

      my $second_org_details =
        $organism_lookup->lookup_by_taxonid($second_organism->taxonid());

      if (!defined $second_org_details->{pathogen_or_host}) {
        next;
      }

      $has_pathogen_host_metagenotypes = 1;
      last;
    }
  }

  return ($has_pathogen_genotypes && $has_host, $has_host_genes,
          $has_pathogen_genes, $has_host_genotypes, $has_pathogen_genotypes,
          $has_pathogen_host_metagenotypes, $organism_page_valid);
};

sub _set_genes_in_session
{
  my $c = shift;
  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $genes_rs = $schema->resultset('Gene');
  my $genes_in_session =
    [map {
      my $gene = $_;
      my $gene_proxy = _get_gene_proxy($config, $gene);

      { id => $gene->gene_id(),
        display_name => $gene_proxy->display_name() } } $genes_rs->all()];
  $st->{genes_in_session} = $genes_in_session;
}

sub not_found: Private
{
  my ($self, $c) = @_;
  $c->forward('Canto::Controller::Root', 'default');
}

sub _redirect_and_detach
{
  my ($c, @path_components) = @_;

  if (@path_components) {
    unshift @path_components, '';
  }

  my $target = $c->stash->{curs_root_uri} . join ('/', @path_components);

  $c->res->redirect($target);
  $c->detach();
}

sub _redirect_to_top_and_detach
{
  my $c = shift;

  my $instance_top_uri = $c->uri_for('/');

  $c->res->redirect($instance_top_uri);
  $c->detach();
}

sub front : Chained('top') PathPart('') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  my $pub_uniquename = $st->{pub}->uniquename();
  $st->{title} = "$pub_uniquename summary";
  # use only in header, not in body:
  $st->{show_title} = 1;
  $st->{template} = 'curs/front.mhtml';

  my $schema = $st->{schema};

  my $total_annotation_count = $schema->resultset('Annotation')->count();

  $st->{total_annotation_count} = $total_annotation_count;

  if ($st->{state} eq APPROVAL_IN_PROGRESS) {
    my $no_annotation_reason =
      $self->get_metadata($schema, Canto::Curs::State::NO_ANNOTATION_REASON_KEY());

    if (defined $no_annotation_reason) {
      push @{$st->{message}}, "Reason given for no annotation: $no_annotation_reason";
    }
  }
}

=head2 read_only_summary

 This action show the summary in readonly mode.

=cut

sub read_only_summary : Chained('top') PathPart('ro') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  my $pub_uniquename = $st->{pub}->uniquename();
  $st->{title} = "Reviewing session for $pub_uniquename";

  # use only in header, not in body:
  $st->{show_title} = 1;
  $st->{template} = 'curs/front.mhtml';

  my $schema = $c->stash()->{schema};

  my $no_annotation_reason =
    $self->get_metadata($schema, Canto::Curs::State::NO_ANNOTATION_REASON_KEY());

  if (defined $no_annotation_reason) {
    push @{$st->{message}}, "Reason given for no annotation: $no_annotation_reason";
  }

  my $total_annotation_count = $schema->resultset('Annotation')->count();

  $st->{total_annotation_count} = $total_annotation_count;
}

sub introduction : Private
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $config = $c->config();

  $st->{title} = 'Welcome to ' . $config->{name};
  if (defined $config->{database_name}) {
    $st->{title} .= ' at ' . $config->{database_name};
  }
  $st->{show_title} = 0;
  $st->{template} = 'curs/introduction.mhtml';
}

sub store_statuses : Chained('top') Args(0) Form
{
  my $self = shift;
  my ($c) = @_;

  $self->state()->store_statuses($c->stash()->{schema});
}

my $gene_list_textarea_name = 'gene_identifiers';

sub _search_highlight
{
  my $highlight_terms = shift;
  my $identifier = shift;

  return '' if !defined $identifier;

  HTML::Mason::Escapes::basic_html_escape(\$identifier);

  if (exists $highlight_terms->{$identifier}) {
    return '<span class="curs-matched-search-term">' . $identifier . '</span>';
  } else {
    return $identifier;
  }
}

sub _make_gene_edit_data
{
  my ($self, $c, $gene_list) = @_;

  my $st = $c->stash();

  my $schema = $st->{schema};

  my $pathogen_host_mode = $st->{pathogen_host_mode};
  my $multi_organism_mode = $st->{multi_organism_mode};

  my @highlight_terms = @{$c->flash()->{highlight_terms} || []};

  my %highlight_terms = ();
  @highlight_terms{@highlight_terms} = @highlight_terms;

  my %all_data = (
    default_organism => {},
  );

  if ($pathogen_host_mode) {
    $all_data{pathogen} = {};
    $all_data{host} = {};
  }

  my $strain_lookup = Canto::Track::StrainLookup->new(config => $c->config());

  my @gene_hashes = map {
    my $gene = $_;
    my $gene_proxy =
      Canto::Curs::GeneProxy->new(config => $c->config(), cursdb_gene => $_);

    my $synonyms_string =
      join (', ', map { _search_highlight(\%highlight_terms, $_) } $gene_proxy->synonyms());
    my $hash = {
      'Systematic identifier' => _search_highlight(\%highlight_terms, $gene_proxy->primary_identifier()),
      Name => _search_highlight(\%highlight_terms, $gene_proxy->primary_name()),
      Product => $gene_proxy->product(),
      Synonyms => $synonyms_string,
      gene_id => $gene_proxy->gene_id(),
      annotation_count => $gene_proxy->cursdb_gene()
        ->all_annotations(include_with=>1)->count(),
      genotype_count => $gene_proxy->cursdb_gene()->genotypes()->count(),
    };

    my $organism_details = $gene_proxy->organism_details();

    my $taxonid = $organism_details->{taxonid};

    my %org_data;
    my $org_type = $organism_details->{pathogen_or_host};

    if ($org_type ne 'pathogen' && $org_type ne 'host') {
      $org_type = 'default_organism';
    }

    if (exists $all_data{$org_type}->{$taxonid}) {
      %org_data = %{$all_data{$org_type}->{$taxonid}};
    } else {
      %org_data = %$organism_details;
      delete $org_data{full_name};
      $org_data{genes} = [];
      $org_data{selected_strains} = [];
      $org_data{available_strains} = [$strain_lookup->lookup($taxonid)];

      $all_data{$org_type}->{$taxonid} = \%org_data;
    }

    push @{$org_data{genes}}, {
      systematic_identifier => $gene_proxy->primary_identifier(),
      name => $gene_proxy->primary_name(),
      product => $gene_proxy->product(),
      synonyms => [$gene_proxy->synonyms()],
      gene_id => $gene_proxy->gene_id(),
      annotation_count => $gene_proxy->cursdb_gene()
        ->all_annotations(include_with=>1)->count(),
      genotype_count => $gene_proxy->cursdb_gene()->genotypes()->count(),
    };

    if ($multi_organism_mode) {
      $hash->{Organism} = $organism_details->{full_name};
      $hash->{taxonid} = $organism_details->{taxonid};
      if ($pathogen_host_mode) {
        $hash->{pathogen_or_host} = $organism_details->{pathogen_or_host};
      }
    }
    $hash
  } @$gene_list;

  my @hosts_with_no_genes = ();

  if ($pathogen_host_mode) {
    use Canto::Track;
    my $organism_lookup = Canto::Track::get_adaptor($c->config(), 'organism');

    my @curs_host_organism_details =
      grep {
        $_->{pathogen_or_host} eq 'host';
      }
      map {
        my $curs_organism = $_;

        my $res = $organism_lookup->lookup_by_taxonid($curs_organism->taxonid());

        $res->{genotype_count} = $curs_organism->genotypes()->count();
        $res;
      } $schema->resultset('Organism')->all();

    my @host_organisms_from_genes = ();

    for my $gene ($schema->resultset('Gene')->all()) {
      my $this_gene_taxonid = $gene->organism()->taxonid();
      my $organism_details = $organism_lookup->lookup_by_taxonid($this_gene_taxonid);
      if ($organism_details->{pathogen_or_host} eq 'host') {
        if (!grep { $_->{taxonid} == $this_gene_taxonid } @host_organisms_from_genes) {
          push @host_organisms_from_genes, $organism_details;
        }
      }
    }

    my @no_gene_host_organisms =
      grep {
        my $host_org = $_;
        !grep { $_->{taxonid} == $host_org->{taxonid} } @host_organisms_from_genes;
      } @curs_host_organism_details;

    @hosts_with_no_genes = @no_gene_host_organisms;
  }

  %all_data = map {
    ($_, [values %{$all_data{$_}}])
  } keys %all_data;

  map {
    $_->{available_strains} = [$strain_lookup->lookup($_->{taxonid})];
  } @hosts_with_no_genes;

  my $gene_list_data_js = Data::JavaScript::Anon->anon_dump(\%all_data);
  my $hosts_with_no_genes_js = Data::JavaScript::Anon->anon_dump(\@hosts_with_no_genes);

  return (\@gene_hashes, $gene_list_data_js, $hosts_with_no_genes_js);
}

# $confirm_genes will be true if we have just uploaded some genes
sub _edit_genes_helper
{
  my ($self, $c, $confirm_genes) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $form = $self->form();
  $form->attributes({ action => '?' });

  my @all_elements = (
      {
        name => 'gene-select', label => 'gene-select',
        label_tag => 'formfu-label',
        type => 'Checkbox', default_empty_value => 1
      },
      {
        name => 'host-org-select', label => 'host-org-select',
        label_tag => 'formfu-label',
        type => 'Checkbox', default_empty_value => 1
      },
    );


  $form->elements([@all_elements]);

  $form->process();

  my $pathogen_host_mode = $c->config()->{pathogen_host_mode};

  if (defined $c->req->param('continue')) {
    _redirect_and_detach($c);
  }

  if (defined $c->req->param('submit')) {
    if ($c->req()->param('submit')) {
      my @gene_ids = grep {
        length $_ > 0;
      } @{$form->param_array('gene-select')};
      my @host_org_taxonids = grep {
        length $_ > 0;
      } @{$form->param_array('host-org-select')};

      if (@gene_ids == 0 &&
          (!$pathogen_host_mode || $pathogen_host_mode && @host_org_taxonids == 0)) {
        if ($pathogen_host_mode) {
          push @{$st->{message}}, 'No genes or hosts selected for deletion';
        } else {
          push @{$st->{message}}, 'No genes selected for deletion';
        }
      } else {
        my $delete_sub = sub {
          my %deleted_gene_organisms = ();
          for my $gene_id (@gene_ids) {
            my $gene = $schema->find_with_type('Gene', $gene_id);
            $deleted_gene_organisms{$gene->organism()->taxonid()} = 1;
            $gene->delete();
          }

          my $organism_lookup = Canto::Track::get_adaptor($config, 'organism');
          my $organism_manager =
            Canto::Curs::OrganismManager->new(config => $c->config(), curs_schema => $schema);

          for my $taxonid (keys %deleted_gene_organisms) {
            my $organism_details = $organism_lookup->lookup_by_taxonid($taxonid);
            if ($organism_details->{pathogen_or_host} &&
                $organism_details->{pathogen_or_host} eq 'pathogen') {
              my $organism = $schema->resultset("Organism")->find({ taxonid => $taxonid });
              if ($organism->genes()->count() == 0 &&
                  $organism->genotypes()->count() == 0) {
                $organism_manager->delete_organism_by_taxonid($taxonid);
              }
            }
          }

          for my $host_org_taxonid (@host_org_taxonids) {
            $organism_manager->delete_organism_by_taxonid($host_org_taxonid);
          }
        };
        $schema->txn_do($delete_sub);

        $self->state()->store_statuses($c->stash()->{schema});

        if ($self->get_ordered_gene_rs($schema)->count() == 0) {
          $self->unset_metadata($schema, Canto::Curs::State::CURATION_IN_PROGRESS_TIMESTAMP_KEY());
          push @{$c->flash()->{message}}, 'All genes removed from the list';
          _redirect_and_detach($c, 'gene_upload');
        } else {
          my $plu = scalar(@gene_ids) != 1 ? 's' : '';
          my $message = 'Removed ' . scalar(@gene_ids) . " gene$plu from list";
          if (@host_org_taxonids) {
            $message .= ', removed ' . scalar(@host_org_taxonids) . ' host' .
              (scalar(@host_org_taxonids) != 1 ? 's' : '');
          }

          push @{$st->{message}}, $message;
        }
      }
    }
  }

  $st->{confirm_genes} = $confirm_genes;

  if ($confirm_genes) {
    $st->{title} = 'Confirm gene ';
    if ($pathogen_host_mode) {
      $st->{title} .= 'and host organism ';
    }
    $st->{title} .= 'list for ' . $st->{pub}->uniquename();
  } else {
    $st->{title} = 'Gene ';
    if ($pathogen_host_mode) {
      $st->{title} .= 'and host organism ';
    }
    $st->{title} .= 'list for ' . $st->{pub}->uniquename();
  }
  $st->{show_title} = 0;
  $st->{template} = 'curs/gene_list_edit.mhtml';

  $st->{form} = $form;

  my $gene_list =
    [Canto::Controller::Curs->get_ordered_gene_rs($schema, 'primary_identifier')->all()];

  my ($gene_hashes, $gene_list_data_js, $hosts_with_no_genes_js) =
    $self->_make_gene_edit_data($c, $gene_list);

  $st->{gene_hashes} = $gene_hashes;
  $st->{gene_list_data_js} = $gene_list_data_js;
  $st->{hosts_with_no_genes_js} = $hosts_with_no_genes_js;
}

sub edit_genes : Chained('top') Args(0) Form
{
  my $self = shift;
  my ($c) = @_;

  $self->_edit_genes_helper(@_, 0);
}

sub view_genes_and_strains : Chained('top')
{
  my $self = shift;
  my ($c) = @_;

  my $st = $c->stash();

  my $pathogen_host_mode = $c->config()->{pathogen_host_mode};

  my $gene_list =
    [Canto::Controller::Curs->get_ordered_gene_rs($st->{schema}, 'primary_identifier')->all()];

  my ($gene_hashes, $gene_list_data_js, $hosts_with_no_genes_js) =
    $self->_make_gene_edit_data($c, $gene_list);

  $st->{gene_hashes} = $gene_hashes;
  $st->{gene_list_data_js} = $gene_list_data_js;
  $st->{hosts_with_no_genes_js} = $hosts_with_no_genes_js;

  $st->{title} = 'Genes, organisms and strains from this session';
  $st->{template} = 'curs/view_genes_and_strains.mhtml';
}

sub confirm_genes : Chained('top') Args(0) Form
{
  my $self = shift;
  my ($c) = @_;

  $self->_edit_genes_helper(@_, 1);
}

sub gene_upload : Chained('top') Args(0) Form
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  my $return_path = $c->req()->param("return_path");

  if (defined $return_path) {
    $st->{title} = 'Add to gene list for ' . $st->{pub}->uniquename();
  } else {
    $st->{title} = 'Create gene list for ' . $st->{pub}->uniquename();
  }

  $st->{show_title} = 0;

  $st->{template} = 'curs/gene_upload.mhtml';

  my $form = $self->form();

  # to prevent AngularJS from doing preventDefault on the form
  $form->action('?');
  my @submit_buttons = ("Continue");

  my $schema = $st->{schema};

  my @no_genes_elements = ();
  my @no_genes_reasons =
    ( [ '', 'Choose a reason...' ],
      map { [ $_, $_ ] } @{$c->config()->{curs_config}->{no_genes_reasons}} );

  if ($st->{gene_count} > 0) {
    push @submit_buttons, "Cancel";
  } else {
    @no_genes_elements = (
      {
        name => 'no-genes', type => 'Checkbox',
        label => 'If this paper does not mention any genes individually, ' .
          'check this box and select a reason from the pulldown menu that will appear:',
        label_tag => 'formfu-label',
        default_empty_value => 1,
        attributes => { 'ng-model' => 'data.noAnnotation',
                        'ng-disabled' => 'data.geneIdentifiers.length > 0'  },
      },
      {
        name => 'no-genes-reason',
        type => 'Select', options => [ @no_genes_reasons ],
        attributes => { 'ng-model' => 'data.noAnnotationReason',
                        'ng-show' => 'data.noAnnotation' },
      },
      {
        name => 'no-genes-other', type => 'Text',
        attributes => { 'ng-show' => 'data.noAnnotation && data.noAnnotationReason === "Other"',
                        'ng-model' => 'data.otherText',
                        placeholder => 'Please specify' },
      },
    );
  }

  my $not_valid_message = "Please enter some gene identifiers or choose a " .
    "reason for this paper having no annotatable genes";

  my @all_elements = (
      { name => $gene_list_textarea_name, type => 'Textarea', cols => 80, rows => 10,
        attributes => { 'ng-model' => 'data.geneIdentifiers',
                        'ng-disabled' => 'data.noAnnotation',
                        placeholder => "{{ data.noAnnotation ? 'No genes in this publication ' : '' }}" },
      }
    );

  if ($c->config()->{pathogen_host_mode}) {
    my $pub_uniquename = $st->{pub}->uniquename();

    push @all_elements,
      {
        type => 'Block', tag => 'div',
        content => "Add host organisms (where the paper has a host with no specified genes):",
      },
      {
        type => 'Block', tag => 'organism-picker',
        content => '',
        attributes => {
          'disabled' => 'data.noAnnotation',
          'selected-organisms' => "data.selectedHostOrganisms",
        }
      };
  }

  push @all_elements,
    { name => 'return_path_input', type => 'Hidden',
      value => $return_path // '',
    },
      (map {
        my $ret = {
          name => $_, type => 'Submit', value => $_,
          attributes => {
            class => 'btn btn-primary curs-finish-button button',
            title => "{{ isValid() ? '' : '$not_valid_message' }}",
          },
        };
        if ($_ eq 'Continue') {
          $ret->{attributes}->{'ng-disabled'} = '!isValid()';
        }
        if ($_ eq 'Cancel') {
          $ret->{attributes}->{'class'} =~ s/btn-primary/btn-warning/;
        }
        $ret;
      } @submit_buttons),
        @no_genes_elements;


  $form->elements([@all_elements]);

  $form->process();

  $st->{form} = $form;

  if ($form->submitted()) {
    if (defined $c->req->param('Cancel')) {
      my $return_path = $form->param_value('return_path_input');

      if (defined $return_path && length $return_path > 0) {
        $c->res->redirect($return_path, 302);
        $c->detach();
        return 0;
      } else {
        _redirect_and_detach($c, 'edit_genes');
      }
    }
  }

  if ($form->submitted_and_valid()) {
    if ($form->param_value('no-genes')) {
      my $no_genes_reason =
        $form->param_value('no-genes-other') || $form->param_value('no-genes-reason');

      $no_genes_reason =~ s/^\s+//;
      $no_genes_reason =~ s/\s+$//;
      if (length $no_genes_reason > 0) {
        $self->set_metadata($schema, Canto::Curs::State::NO_ANNOTATION_REASON_KEY(),
                            $no_genes_reason);
      } else {
        push @{$st->{message}}, $not_valid_message;
      }

      push @{$c->flash()->{message}}, "Annotation complete";

      _redirect_and_detach($c, 'finish_form');

      return;
    }

    my $search_terms_text = $form->param_value($gene_list_textarea_name);
    my @search_terms = grep { length $_ > 0 } split /[\s,]+/, $search_terms_text;

    $st->{search_terms_text} = $search_terms_text;

    my $gene_manager =
      Canto::Curs::GeneManager->new(config => $c->config(),
                                    curs_schema => $schema);

    my @res_list = ();

    my @host_taxon_ids = ();

    if ($c->config()->{pathogen_host_mode}) {
      my $taxon_ids_text = $c->req->param('host_organism_taxon_ids');

      # will be undefined if the form is submitted before the organism picker
      # has finished initialising (ie. the spinner is still spinning)
      if (defined $taxon_ids_text) {
        @host_taxon_ids = grep { length $_ > 0 && /^\d+$/ } split /[\s,]+/, $taxon_ids_text;

        my $organism_manager =
          Canto::Curs::OrganismManager->new(config => $c->config(), curs_schema => $schema);

        map {
          $organism_manager->add_organism_by_taxonid($_);
        } @host_taxon_ids
      }
    }

    if (!@host_taxon_ids || @search_terms) {
      @res_list = $gene_manager->find_and_create_genes(\@search_terms);
    }

    if (@res_list > 1) {
      # there was a problem
      my ($result, $identifiers_matching_more_than_once,
          $genes_matched_more_than_once) = @res_list;

      my @missing = @{$result->{missing}};
      my $error_title;
      my $error_text;
      if (@missing) {
        $error_title = "No genes found for these identifiers: @missing";
      } else {
        if (keys %$identifiers_matching_more_than_once > 0) {
          if (keys %$identifiers_matching_more_than_once > 1) {
            $error_title = 'Some of your identifiers match more than one gene: ';
          } else {
            $error_title = 'One of your identifiers matches more than one gene: ';
          }

          my @bits = ();
          while (my ($identifier, $gene_list) = each %$identifiers_matching_more_than_once) {
            my @gene_identifiers = map { qq("$_") } @$gene_list;
            my $last_identifier = pop @gene_identifiers;
            my $this_message = "$identifier matches ";
            $this_message .= join ', ', @gene_identifiers;
            $this_message .= " and $last_identifier";
            push @bits, $this_message;
          }

          $error_title .= join '; ', @bits;
        } else {
          if (keys %$genes_matched_more_than_once > 0) {
            $error_title = 'Some of your identifiers match the same gene: ';

            my @bits = ();
            while (my ($identifier, $gene_list) = each %$genes_matched_more_than_once) {
              my @gene_identifiers = map { qq("$_") } @$gene_list;
              my $last_identifier = pop @gene_identifiers;
              my $this_message = "found gene $identifier with ";
              $this_message .= join ', ', @gene_identifiers;
              $this_message .= " and $last_identifier";
              push @bits, $this_message;
            }

            $error_title .= join '; ', @bits;
          } else {
            die "internal error";
          }
        }

        $error_text = 'Enter only systematic identifiers to avoid this problem.';
      }

      $st->{error} = { title => $error_title };
      if (defined $error_text) {
        $st->{error}->{text} = $error_text;
      }
      $st->{gene_upload_unknown} = [@missing];
    } else {
      # no problems, so the result is the list of matching genes
      my ($result) = @res_list;

      my $matched_count = scalar(keys %$result);

      my $message = "Added $matched_count gene";
      $message .= 's' if ($matched_count != 1);

      if (@host_taxon_ids > 0) {
        $message .= ', added ' . scalar(@host_taxon_ids) .
          ' host organism' . (@host_taxon_ids != 1 ? 's' : '');
      }

      push @{$c->flash()->{message}}, $message;

      if (!defined $self->get_metadata($schema, Canto::Curs::State::CURATION_IN_PROGRESS_TIMESTAMP_KEY())) {
        $self->set_metadata($schema, Canto::Curs::State::CURATION_IN_PROGRESS_TIMESTAMP_KEY(),
                            Canto::Util::get_current_datetime());
      }

      $self->state()->store_statuses($schema);

      my $return_path = $form->param_value('return_path_input');

      if (defined $return_path && length $return_path > 0) {
        $c->res->redirect($return_path, 302);
        $c->detach();
        return 0;
      } else {
        $c->flash()->{highlight_terms} = [@search_terms];
        _redirect_and_detach($c, 'confirm_genes');
      }
    }
  }
}

sub _genotype_manage_helper
{
  my ($self, $c, $flag, $genotype_type) = @_;

  my $st = $c->stash();

  if (defined $flag && $flag eq 'ro') {
    $st->{read_only_curs} = 1;
  }

  $st->{title} = 'Genotypes for: ' . $st->{pub}->uniquename();
  $st->{genotype_switch_select} = $genotype_type;
  $st->{template} = 'curs/genotype_switch.mhtml';
}

sub genotype_manage : Chained('top')
{
  my ($self, $c, $flag) = @_;

  $self->_genotype_manage_helper($c, $flag, 'genotype');
}

sub pathogen_genotype_manage : Chained('top')
{
  my ($self, $c, $flag) = @_;

  $self->_genotype_manage_helper($c, $flag, 'pathogen-genotype');
}

sub host_genotype_manage : Chained('top')
{
  my ($self, $c, $flag) = @_;

  $self->_genotype_manage_helper($c, $flag, 'host-genotype');
}

sub metagenotype_manage : Chained('top')
{
  my ($self, $c, $flag) = @_;

  my $st = $c->stash();

  if (defined $flag && $flag eq 'ro') {
    $st->{read_only_curs} = 1;
  }

  $st->{title} = 'Metagenotypes for: ' . $st->{pub}->uniquename();
  $st->{genotype_switch_select} = 'metagenotype';
  $st->{template} = 'curs/genotype_switch.mhtml';
}

sub _delete_annotation : Private
{
  my ($self, $c, $annotation_id, $other_gene_identifier) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation = $schema->resultset('Annotation')->find($annotation_id);
  my $annotation_type_name = $annotation->type();
  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};
  if ($annotation_config->{category} eq 'interaction') {
    Canto::Curs::Utils::delete_interactor($annotation, $other_gene_identifier);
  } else {
    $annotation->delete();
  }

  push @{$c->flash()->{message}}, "Annotation deleted";
}

sub annotation_delete : Chained('annotation') PathPart('delete')
{
  my ($self, $c, $other_gene_identifier) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation = $st->{annotation};

  my $delete_sub = sub {
    $self->_delete_annotation($c, $annotation->annotation_id(), $other_gene_identifier);
    $self->metadata_storer()->store_counts($schema);
  };

  $schema->txn_do($delete_sub);

  _redirect_and_detach($c);
}

sub annotation_delete_suggestion : Chained('annotation') PathPart('delete_suggestion')
{
  my ($self, $c) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation = $st->{annotation};

  my $delete_sub = sub {
    my $data = $annotation->data();
    delete $data->{term_suggestion};
    $annotation->data($data);
    $annotation->update();
    $self->metadata_storer()->store_counts($schema);
  };

  $schema->txn_do($delete_sub);

  _redirect_and_detach($c);
}

# change the annotation data of an existing annotation
sub _re_edit_annotation
{
  my $c = shift;
  my $annotation_config = shift;
  my $annotation_id = shift;
  my $new_annotation_data = shift // {};

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation = $schema->find_with_type('Annotation',
                                           {
                                             annotation_id => $annotation_id,
                                           });
  my $data = $annotation->data();

  my $merge = Hash::Merge->new('RIGHT_PRECEDENT');
  my $new_data = $merge->merge($data, $new_annotation_data);

  $annotation->data($new_data);
  $annotation->update();

  return $annotation;
}

sub _create_annotation
{
  my ($self, $c, $annotation_type_name, $feature_type,
      $features, $annotation_data) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};

  if ($annotation_config->{category} eq 'ontology' &&
      !$annotation_data->{term_ontid}) {
    die "internal error: no term ontology ID (term_ontid) passed to _create_annotation()";
  }

  my $guard = $schema->txn_scope_guard;

  my $annotation =
      $schema->create_with_type('Annotation',
                                {
                                  type => $annotation_type_name,
                                  status => 'new',
                                  pub => $st->{pub},
                                  creation_date => Canto::Curs::Utils::get_iso_date(),
                                  data => clone $annotation_data,
                                });

  if ($feature_type eq 'gene') {
    my @genes = map {
      $_->cursdb_gene();
    } @$features;

    $annotation->set_genes(@genes);
  } else {
    if ($feature_type eq 'genotype') {
      $annotation->set_genotypes(@$features);
    } else {
      if ($feature_type eq 'metagenotype') {
        $annotation->set_metagenotypes(@$features);
      } else {
        die "unknown feature type: ", $feature_type;
      }
    }
  }

  $self->set_annotation_curator($annotation);
  $guard->commit();

  $self->metadata_storer()->store_counts($schema);

  $_debug_annotation_ids = [$annotation->annotation_id()];

  $self->state()->store_statuses($schema);

  return $annotation;
}

sub annotation_ontology_edit
{
  my ($self, $c, $feature, $annotation_config) = @_;

  my $annotation_type_name = $annotation_config->{name};

  my $st = $c->stash();
  my $category = $annotation_config->{category};

  $st->{annotation_type_name} = $annotation_type_name;

  $st->{template} = "curs/modules/$category.mhtml";
}

sub annotation_interaction_edit
{
  my ($self, $c, $gene_proxy, $annotation_config) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation_type_name = $annotation_config->{name};

  my $category = $annotation_config->{category};

  # don't set stash title - use default
  $st->{annotation_type_name} = $annotation_type_name;
  $st->{template} = "curs/modules/$category.mhtml";
}

sub _get_gene_proxy
{
  my $config = shift;
  my $gene = shift;

  if (!defined $gene) {
    confess "no gene passed to _get_gene_proxy()";
  }

  return Canto::Curs::GeneProxy->new(config => $config,
                                      cursdb_gene => $gene);
}


sub annotate : Chained('feature') CaptureArgs(1)
{
  my ($self, $c, $id) = @_;

  my $st = $c->stash();
  my $config = $c->config();

  my $feature_type = $st->{feature_type};

  my $feature = $st->{schema}->find_with_type($feature_type, $feature_type . "_id", $id);

  if ($feature_type eq 'gene') {
    $feature = _get_gene_proxy($config, $feature);
  }

  $st->{feature} = $feature;
  $st->{features} = [$feature];
}

sub start_annotation : Chained('annotate') PathPart('start') Args(1)
{
  my ($self, $c, $annotation_type_name) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $feature = $st->{feature};
  my @features = @{$st->{features}};

  my $annotation_config = $config->{annotation_types}->{$annotation_type_name};

  if (!defined $annotation_config) {
    die "no configuration for $annotation_type_name";
  }

  $st->{annotation_type_config} = $annotation_config;
  $st->{annotation_type_name} = $annotation_type_name;

  my $annotation_display_name = $annotation_config->{display_name};

  my $display_names = join ',', map {
    if ($annotation_config->{feature_type} eq 'gene') {
      $_->display_name();
    } else {
      $_->display_name($config);
    }
  } @features;

  $st->{title} = "Create annotation";
  $st->{show_title} = 1;

  my %type_dispatch = (
    ontology => \&annotation_ontology_edit,
    interaction => \&annotation_interaction_edit,
  );

  $self->state()->store_statuses($schema);

  my $category = $annotation_config->{category};

  if (!defined $category) {
    die "no category configured for annotation type: $annotation_type_name\n";
  }

  my $edit_func = $type_dispatch{$category};

  if (!defined $edit_func) {
    die qq(unknown category "$category" for annotation type: $annotation_type_name\n);
  }

  &{$edit_func}($self, $c, $feature, $annotation_config);
}

sub annotation : Chained('top') CaptureArgs(1)
{
  my ($self, $c, $annotation_ids) = @_;

  my $st = $c->stash();

  my @annotations = $self->_check_annotation_exists($c, $annotation_ids);

  $st->{annotations} = \@annotations;

  $st->{annotation} = $annotations[0];
}

=head2 annotation_features

 Usage   : my ($feature_type, @features) =
             annotation_features($config, $annotation);
 Function: Return the features and type of features for an annotation
 Args    : $config - an Canto::Config object
           $annotation - an Annotation object
 Return  : $feature_type - "gene" or "genotype"
           @features - the features of an annotation

=cut

sub annotation_features
{
  my $config = shift;
  my $annotation = shift;

  my @genes = $annotation->genes();

  if (@genes) {
    return ('gene', map { _get_gene_proxy($config, $_); } @genes);
  } else {
    return ('genotype', $annotation->genotypes());
  }
}

sub _check_annotation_exists
{
  my $self = shift;
  my $c = shift;
  my $annotation_ids = shift;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my @annotation_ids = split /,/, $annotation_ids;

  my @annotations = ();

  for my $annotation_id (@annotation_ids) {
    my $annotation =
      $schema->resultset('Annotation')->find($annotation_id);

    if (defined $annotation) {
      $c->stash()->{annotation} = $annotation;

      push @annotations, $annotation;
    } else {
      $c->flash()->{error} = qq|No annotation found with id "$annotation_id" |;
      _redirect_and_detach($c);
      return ();
    }
  }

  return @annotations;
}

sub _generate_evidence_options
{
  my $evidence_types = shift;
  my $annotation_type_config = shift;

  my @codes = map {
    my $code = $_;
    my $type_conf = $evidence_types->{$_};
    if (!defined $type_conf) {
      die "no configuration for $_\n";
    }
    my $description = $type_conf->{name};
    if (!defined $description) {
      die "missing description for $_\n";
    }
    if ($description !~ /^$code/) {
      $description .= " ($_)";
    }
    [ $_, $description]
  } @{$annotation_type_config->{evidence_codes}};

  return @codes;
}

sub annotation_set_term : Chained('annotate') PathPart('set_term') Args(1)
{
  my ($self, $c, $annotation_type_name) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $body_data = _decode_json_content($c);

  my $term_ontid = $body_data->{term_ontid};
  my $evidence_code = $body_data->{evidence_code};
  my $extension = $body_data->{extension} || [];

  my @conditions = ();

  if (defined $body_data->{conditions}) {
    my $lookup = Canto::Track::get_adaptor($config, 'ontology');

    my @condition_names = map {
      $_->{name};
    } @{$body_data->{conditions}};

    my @conditions_with_ids =
      Canto::Curs::ConditionUtil::get_conditions_from_names($lookup,
                                                            \@condition_names);
    @conditions =
      map { $_->{term_id} // $_->{name} } @conditions_with_ids;
  }

  my $annotation_config = $st->{annotation_type_config};
  my $feature_type = $st->{feature_type};
  my $feature = $st->{feature};

  my $module_category = $annotation_config->{category};

  $st->{annotation_config} = $annotation_config;
  $st->{annotation_category} = $module_category;

  my %annotation_data = (term_ontid => $term_ontid,
                         evidence_code => $evidence_code,
                         conditions => \@conditions,
                         extension => $extension,
                       );

  my $suggested_name = trim($body_data->{term_suggestion_name});
  my $suggested_definition = trim($body_data->{term_suggestion_definition});

  $annotation_data{term_suggestion} = {
    name => $suggested_name,
    definition => $suggested_definition
  };

  if ($body_data->{with_gene_id}) {
    my $with_gene = $schema->find_with_type('Gene', $body_data->{with_gene_id});

    $annotation_data{with_gene} = $with_gene->primary_identifier();
  }

  if ($body_data->{submitter_comment}) {
    $annotation_data{submitter_comment} = $body_data->{submitter_comment};
  }

  if ($body_data->{figure}) {
    $annotation_data{figure} = $body_data->{figure};
  }

  my $annotation =
    $self->_create_annotation($c, $annotation_type_name,
                                  $feature_type, [$feature], \%annotation_data);

  my $location = $st->{curs_root_uri} . "/feature/$feature_type/view/" .
    $feature->feature_id();

  $c->stash->{json_data} = {
    status => "success",
    location => $location,
  };

  $c->forward('View::JSON');
}

sub annotation_add_interaction : Chained('annotate') PathPart('add_interaction') Args(1)
{
  my ($self, $c, $annotation_type_name) = @_;

  my $config = $c->config();
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $body_data = _decode_json_content($c);

  my $evidence_code = $body_data->{evidence_code};
  my @prey_gene_ids = @{$body_data->{prey_gene_ids}};

  my $annotation_config = $st->{annotation_type_config};
  my $feature_type = $st->{feature_type};
  my $feature = $st->{feature};

  my $module_category = $annotation_config->{category};

  my $annotation_type_config = $config->{annotation_types}->{$annotation_type_name};
  my $evidence_types = $config->{evidence_types};

  for my $prey_gene_id (@prey_gene_ids) {
    my $prey_gene = $schema->find_with_type('Gene', $prey_gene_id);

    my %annotation_data = (evidence_code => $evidence_code,
                           interacting_genes =>
                             [{ primary_identifier => $prey_gene->primary_identifier() }]);

    my $annotation =
      $self->_create_annotation($c, $annotation_type_name,
                                $feature_type, [$feature], \%annotation_data);
  }

  $c->stash->{json_data} = {
    status => "success",
    location => $st->{curs_root_uri} . "/feature/$feature_type/view/" .
      $feature->feature_id(),
  };

  $c->forward('View::JSON');
}

sub allele_remove_action : Chained('annotation') PathPart('remove_allele_action') Args(1)
{
  my ($self, $c, $allele_id) = @_;

  my $annotation = $c->stash()->{annotation};

  my $data = $annotation->data();
  my $alleles_in_progress = $data->{alleles_in_progress} // { };

  delete $alleles_in_progress->{$allele_id};

  $data->{alleles_in_progress} = $alleles_in_progress;
  $annotation->data($data);
  $annotation->update();

  $c->stash->{json_data} = {
    allele_id => $allele_id,
    annotation_id => $annotation->annotation_id(),
  };
  $c->forward('View::JSON');
}

sub _trim
{
  my $str = shift;

  return undef unless defined $str;

  $str =~ s/\s+$//;
  $str =~ s/^\s+//;

  return $str;
}

sub _get_all_alleles
{
  my $config = shift;
  my $schema = shift;
  my $gene = shift;

  my %results = ();

  my $allele_rs =
    $schema->resultset('Allele')->search({
      gene => $gene->gene_id(),
    });

  while (defined (my $allele = $allele_rs->next())) {
    my $allele_display_name = $allele->display_name($config);
    $results{$allele_display_name} = {
      name => $allele->name(),
      description => $allele->description(),
      primary_identifier => $allele->primary_identifier(),
      allele_type => $allele->type(),
    };
  }

  return %results;
}

sub _set_allele_select_stash
{
  my ($c, $annotation_type_name) = @_;

  my $config = $c->config();
  my $st = $c->stash();

  $st->{allele_type_config} = $config->{allele_types};

  $st->{allele_type_names} = [
    map {
      $_->{name};
    } @{$config->{allele_type_list}}
  ];

  if (defined $annotation_type_name) {
    my $evidence_types = $config->{evidence_types};

    my $annotation_type_config = $config->{annotation_types}->{$annotation_type_name};
    my @evidence_codes = _generate_evidence_options($evidence_types, $annotation_type_config);

    $st->{evidence_select_options} = \@evidence_codes;
  }
}


sub feature : Chained('top') CaptureArgs(1)
{
  my ($self, $c, $feature_type) = @_;

  my $st = $c->stash();

  $st->{feature_type} = $feature_type;
}

sub feature_view : Chained('feature') PathPart('view')
{
  my ($self, $c, $ids, $flag) = @_;

  my $st = $c->stash();
  $st->{show_title} = 1;
  my $feature_type = $st->{feature_type};
  my $schema = $st->{schema};
  my $config = $c->config();

  if (defined $flag && $flag eq 'ro') {
    $st->{read_only_curs} = 1;
  }

  my @ids = split /,/, $ids;

  if ($feature_type eq 'gene') {
    my @gene_proxies = map {
      my $gene = $schema->find_with_type('Gene', $_);
      _get_gene_proxy($config, $gene);
    } @ids;

    my $first_gene_proxy = $gene_proxies[0];

    _set_genes_in_session($c);

    $st->{gene} = $first_gene_proxy;
    $st->{genes} = [@gene_proxies];

    $st->{feature} = $st->{gene};
    $st->{features} = $st->{genes};

    my $display_name = $st->{feature}->display_name();
    $st->{title} = "Gene: $display_name";
 } else {
    if ($feature_type eq 'genotype') {
      my $genotype;

      my $genotype_id = $ids[0];

      # a bit hacky: if the ID is an integer assume it's CursDB Genotype,
      # otherwise it's an identifier of a Genotype from Chado
      if ($genotype_id =~ /^\d+$/) {
        $genotype = $schema->find_with_type('Genotype', $genotype_id);
      } else {
        my $genotype_manager =
          Canto::Curs::GenotypeManager->new(config => $c->config(),
                                            curs_schema => $schema);

        # pull from Chado and store in CursDB, $genotype_id is an
        # identifier/uniquename
        $genotype =
          $genotype_manager->find_and_create_genotype($genotype_id);
      }

      $st->{genotype} = $genotype;
      $st->{annotation_count} = $genotype->annotations()->count();

      $st->{feature} = $genotype;
      $st->{features} = [$genotype];

      my $display_name = $st->{feature}->display_name($config);
      $st->{title} = "Genotype: $display_name";
    } else {
      if ($feature_type eq 'metagenotype') {
        my $metagenotype_id = $ids[0];

        my $metagenotype = $schema->find_with_type('Metagenotype', $metagenotype_id);

        $st->{metagenotype} = $metagenotype;
        $st->{annotation_count} = $metagenotype->annotations()->count();

        $st->{feature} = $metagenotype;
        $st->{features} = [$metagenotype];

        my $display_name = $st->{feature}->display_name($config);
        $st->{title} = "Metagenotype details";

      } else {
        die "no such feature type: $feature_type\n";
      }
    }
  }

  $st->{template} = "curs/${feature_type}_page.mhtml";
}

sub _feature_edit_helper
{
  my ($self, $c, $edit_or_duplicate, $genotype_id) = @_;

  my $st = $c->stash();
  $st->{show_title} = 1;
  my $feature_type = $st->{feature_type};

  $st->{edit_or_duplicate} = $edit_or_duplicate;

  my $schema = $st->{schema};

  if ($feature_type eq 'genotype') {
    my $genotype = $schema->find_with_type('Genotype', $genotype_id);

    # store the changes
    my $body_data = _decode_json_content($c);

    my @alleles_data = @{$body_data->{alleles}};
    my $genotype_name = $body_data->{genotype_name};
    my $genotype_background = $body_data->{genotype_background};
    my $genotype_comment = $body_data->{genotype_comment};
    my $genotype_taxonid = $body_data->{taxonid};
    my $strain_name = $body_data->{strain_name} || undef;

    if (defined $genotype_name && length $genotype_name > 0) {
      my $trimmed_name = $genotype_name =~ s/^\s*(.*?)\s*$/$1/r;
      my $existing_genotype =
        $schema->resultset('Genotype')->find({ name => $genotype_name }) //
        $schema->resultset('Genotype')->find({ name => $trimmed_name });

      if ($existing_genotype && $existing_genotype->genotype_id() != $genotype_id) {
        $c->stash->{json_data} = {
          status => "error",
          message => "Storing changes failed: a genotype with " .
            "that name already exists",
        };
        $c->forward('View::JSON');
        return;
      }
    }

    try {
      my $allele_manager =
        Canto::Curs::AlleleManager->new(config => $c->config(),
                                        curs_schema => $schema);

      my $genotype_manager =
        Canto::Curs::GenotypeManager->new(config => $c->config(),
                                          curs_schema => $schema);

      die "no genotype taxonid" unless $genotype_taxonid;

      my $existing_genotype =
        $genotype_manager->find_genotype($genotype_taxonid, $genotype_background,
                                         $strain_name, \@alleles_data);

      if ($existing_genotype &&
            $existing_genotype->genotype_id() != $genotype->genotype_id()) {
        my $alleles_string = "allele";
        if (@alleles_data > 1) {
          $alleles_string = "alleles";
        }

        $c->stash->{json_data} = {
          status => "existing",
          genotype_display_name => $existing_genotype->display_name($c->config(), $strain_name),
          genotype_id => $existing_genotype->genotype_id(),
          taxonid => $existing_genotype->organism()->taxonid(),
          comment => $existing_genotype->comment(),
          strain_name => $strain_name,
        };

      } else {
        my $guard = $schema->txn_scope_guard();

        $genotype_manager->store_genotype_changes($genotype,
                                                  $genotype_name, $genotype_background,
                                                  $genotype_taxonid, \@alleles_data,
                                                  $strain_name, $genotype_comment);

        $guard->commit();

        $c->stash->{json_data} = {
          status => "success",
          location => $st->{curs_root_uri} . "/genotype_manage#/select/" . $genotype->genotype_id(),
        };
      }
    } catch {
      $c->stash->{json_data} = {
        status => "error",
        message => "Storing changes to genotype failed: internal error - " .
          "please report this to the Canto developers",
      };
      warn $_;
    };

    $c->forward('View::JSON');
  } else {
    die "can't edit feature type: $feature_type\n";
  }
}

sub feature_duplicate : Chained('feature') PathPart('duplicate')
{
  my ($self, $c, $genotype_id) = @_;

  $self->_feature_edit_helper($c, 'duplicate', $genotype_id);
}

sub feature_edit : Chained('feature') PathPart('edit')
{
  my ($self, $c, $genotype_id) = @_;

  $self->_feature_edit_helper($c, 'edit', $genotype_id);
}

sub _decode_json_content
{
  my $c = shift;

  my $content_file = $c->req()->body();
  my $json_content;

  # FIXME
  # body() returns a file name, so read the contents into a string - there
  # must be a better way
  {
    local $/;
    open my $fh, '<', $content_file or die "can't open $content_file\n";
    $json_content = <$fh>;
  }

  return decode_json($json_content);
}

sub feature_store : Chained('feature') PathPart('store')
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $feature_type = $st->{feature_type};

  if ($feature_type eq 'genotype') {
    $self->_genotype_store($c);
  } else {
    if ($feature_type eq 'metagenotype') {
      $self->_metagenotype_store($c);
    } else {
      $c->stash->{json_data} = {
        status => "error",
        message => "can't store feature of type: $feature_type",
      };
      warn $_;
      $c->forward('View::JSON');
    };
  }
}

sub _genotype_store
{
  my ($self, $c) = @_;
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $config = $c->config();

  my $body_data = _decode_json_content($c);

  my @alleles_data = @{$body_data->{alleles}};
  my $genotype_name = $body_data->{genotype_name};
  my $genotype_background = $body_data->{genotype_background};
  my $genotype_comment = $body_data->{genotype_comment};
  my $genotype_taxonid = $body_data->{taxonid};

  my $instance_organism = $config->{instance_organism};

  if (defined $instance_organism) {
    # If this Canto is for a single organism then all genotype will be from
    # that organism.  This handles the case where a foreign gene is used in
    # a genotype.  eg. Gal4
    # See: https://github.com/pombase/canto/issues/2317
    $genotype_taxonid = $instance_organism->{taxonid};
  }

  my $strain_name = $body_data->{strain_name} || undef;

  if ($genotype_name && $schema->resultset('Genotype')->find( { name => $genotype_name } )) {
    $c->stash->{json_data} = {
      status => "error",
      message => qq(A genotype already exists with the name "$genotype_name" - ) .
        "please choose another",
    };
  } else {
    try {
      my $curs_key = $st->{curs_key};

      die "no genotype taxonid" unless $genotype_taxonid;

      my $genotype_manager =
        Canto::Curs::GenotypeManager->new(config => $c->config(),
                                          curs_schema => $schema);

      my $existing_genotype =
        $genotype_manager->find_genotype($genotype_taxonid, $genotype_background,
                                         $strain_name, \@alleles_data);

      if ($existing_genotype) {
        my $alleles_string = "allele";
        if (@alleles_data > 1) {
          $alleles_string = "alleles";
        }
        my $message;
        if (defined $existing_genotype->name()) {
          $message = qq(Using existing genotype with the same $alleles_string: ") .
            $existing_genotype->name() . '"'
        } else {
          $message = "Using existing genotype with the same $alleles_string";
        }

        if ($genotype_background) {
          $message .= " and background";
        }

        push @{$c->flash()->{message}}, $message;

        $c->stash->{json_data} = {
          status => "existing",
          genotype_display_name => $existing_genotype->display_name($config, $strain_name),
          genotype_id => $existing_genotype->genotype_id(),
          taxonid => $existing_genotype->organism()->taxonid(),
          comment => $existing_genotype->comment(),
          strain_name => $strain_name,
        };
      } else {
        my $guard = $schema->txn_scope_guard();

        my $genotype =
          $genotype_manager->make_genotype($genotype_name, $genotype_background,
                                           \@alleles_data, $genotype_taxonid, undef,
                                           $strain_name, $genotype_comment);

        $guard->commit();

        my $genotype_display_name = $genotype->display_name($config);

        push @{$c->flash()->{message}}, 'Created new genotype: ' . $genotype_display_name;

        $c->stash->{json_data} = {
          status => "success",
          genotype_display_name => $genotype_display_name,
          genotype_id => $genotype->genotype_id(),
          taxonid => $genotype->organism()->taxonid(),
          strain_name => $strain_name,
        };
      }
    } catch {
      $c->stash->{json_data} = {
        status => "error",
        message => "Storing new genotype failed: internal error - " .
          "please report this to the Canto developers",
      };

      warn $_;
    };
  }

  $c->forward('View::JSON');
}

sub _metagenotype_store
{
  my ($self, $c) = @_;
  my $st = $c->stash();
  my $schema = $st->{schema};

  my $config = $c->config();

  my $body_data = _decode_json_content($c);

  my $pathogen_genotype_id = $body_data->{pathogen_genotype_id};
  my $pathogen_taxonid = $body_data->{pathogen_taxon_id};
  my $pathogen_strain_name = $body_data->{pathogen_strain_name};
  
  my $host_genotype_id = $body_data->{host_genotype_id};
  my $host_taxonid = $body_data->{host_taxon_id};
  my $host_strain_name = $body_data->{host_strain_name};

  if (!$host_genotype_id && !$host_taxonid) {
    $c->stash->{json_data} = {
      status => "error",
      message => "Storing new metagenotype failed: internal error - " .
        "metagenotype call must have 'host_genotype_id' or 'host_taxonid' param",
    };

    $c->forward('View::JSON');

    return;
  }

  if ($host_genotype_id && $host_taxonid) {
    $c->stash->{json_data} = {
      status => "error",
      message => "Storing new metagenotype failed: internal error - " .
        "metagenotype call has both 'host_genotype_id' and 'host_taxonid' params",
    };

    $c->forward('View::JSON');

    return;
  }

  if (!$pathogen_genotype_id && !$pathogen_taxonid) {
    $c->stash->{json_data} = {
      status => "error",
      message => "Storing new metagenotype failed: internal error - " .
        "metagenotype call must have 'pathogen_genotype_id' or 'pathogen_taxonid' param",
    };

    $c->forward('View::JSON');

    return;
  }

  if ($pathogen_genotype_id && $pathogen_taxonid) {
    $c->stash->{json_data} = {
      status => "error",
      message => "Storing new metagenotype failed: internal error - " .
        "metagenotype call has both 'pathogen_genotype_id' and 'pathogen_taxonid' params",
    };

    $c->forward('View::JSON');

    return;
  }

  my @alleles = ();

  try {
    my $genotype_manager =
      Canto::Curs::GenotypeManager->new(config => $c->config(), curs_schema => $schema);

    my $pathogen_genotype;
    
    if ($pathogen_genotype_id) {
      $pathogen_genotype = $schema->find_with_type('Genotype', $pathogen_genotype_id);
    } else {
      $pathogen_genotype = $genotype_manager->get_wildtype_genotype($pathogen_taxonid, $pathogen_strain_name);
    }

    my $host_genotype;

    if ($host_genotype_id) {
      $host_genotype = $schema->find_with_type('Genotype', $host_genotype_id);
    } else {
      $host_genotype = $genotype_manager->get_wildtype_genotype($host_taxonid, $host_strain_name);
    }

    my $existing_metagenotype =
      $genotype_manager->find_metagenotype(pathogen_genotype => $pathogen_genotype,
                                           host_genotype => $host_genotype);

    if ($existing_metagenotype) {
        $c->stash->{json_data} = {
          status => "existing",
          metagenotype_display_name => $existing_metagenotype->display_name($config),
          metagenotype_id => $existing_metagenotype->metagenotype_id(),
        };
    } else {
      my $guard = $schema->txn_scope_guard();

      my $metagenotype =
        $genotype_manager->make_metagenotype(pathogen_genotype => $pathogen_genotype,
                                             host_genotype => $host_genotype);

      $guard->commit();

      $c->stash->{json_data} = {
        status => "success",
        metagenotype_display_name => $metagenotype->display_name($config),
        metagenotype_id => $metagenotype->metagenotype_id(),
      };
    }
  } catch {
    $c->stash->{json_data} = {
      status => "error",
      message => "Storing new metagenotype failed: internal error - " .
        "please report this to the Canto developers",
    };
    warn $_;
  };

  $c->forward('View::JSON');
}

sub annotation_export : Chained('top') PathPart('annotation_export') Args(1)
{
  my ($self, $c, $annotation_type_name) = @_;

  my $schema = $c->stash()->{schema};
  my $config = $c->config();

  my $results = $self->get_annotation_table_tsv($config, $schema, $annotation_type_name);

  $c->res->content_type('text/plain');
  $c->res->body($results);
}

sub annotation_zipexport : Chained('top') PathPart('annotation_zipexport') Args(0)
{
  my ($self, $c) = @_;

  my $schema = $c->stash()->{schema};
  my $config = $c->config();

  my $zip_data = $self->get_curs_annotation_zip($config, $schema);

  if (defined $zip_data) {
    my $st = $c->stash();
    my $pub_uniquename = $st->{pub}->uniquename();

    my $zip_file_name =
      'curation_' . $st->{curs_key} . '_' . $pub_uniquename . '.zip';

    $c->res->headers->header("Content-Disposition" =>
                               "attachment; filename=$zip_file_name");
    $c->res->content_type('application/zip');
    $c->res->body($zip_data);
  } else {
    die "annotation_zipexport() called with no results to export";
  }
}

sub finish_session : Chained('top') Arg(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};
  my $form = $self->form();

  my @all_elements = (
      {
        name => 'submit', type => 'Submit', value => 'Submit to curators',
      },
      {
        name => 'reasonText', type => 'Hidden',
      },
      {
        name => 'otherReason', type => 'Text',
      }
    );

  $form->elements([@all_elements]);

  $form->process();

  $st->{form} = $form;

  if ($form->submitted_and_valid()) {
    my $no_annotation = $form->param_value('no-annotation');
    my $reason = $form->param_value('reasonText');
    my $other_reason = $form->param_value('otherReason');

    if ($no_annotation eq 'on' && !defined $reason) {
      push @{$c->stash()->{message}}, 'No reason given for having no annotation';
      _redirect_and_detach($c);
    } else {
      if (lc $reason eq 'other' && defined $other_reason) {
        $reason = $other_reason;
      }

      $self->set_metadata($schema, Canto::Curs::State::NO_ANNOTATION_REASON_KEY(), $reason);
      _redirect_and_detach($c, 'finish_form');
    }
  } else {
    _redirect_and_detach($c);
  }
}

sub finish_form : Chained('top') Args(0)
{
  my ($self, $c, $arg) = @_;

  my $schema = $c->stash()->{schema};
  my $config = $c->config();

  my $st = $c->stash();

  $st->{title} = 'Curation finished';
  $st->{show_title} = 1;
  $st->{template} = 'curs/finish_form.mhtml';

  $st->{finish_help} = $c->config()->{messages}->{finish_form};

  my $form = $self->form();
  $form->attributes({ action => '?' });
  my @submit_buttons = ("Finish", "Back");

  my $finish_textarea = 'finish_textarea';

  my @all_elements = (
      {
        name => $finish_textarea,
        type => 'Textarea',
        cols => 80,
        rows => 3,
        attributes => {
          class => 'curs-final-comments-field'
        },
        default => $self->get_metadata($schema, MESSAGE_FOR_CURATORS_KEY) // '',
      },
      map {
          {
            name => $_, type => 'Submit', value => $_,
              attributes => {
                class => 'btn btn-primary curs-' . lc $_ . '-button',
              },
            }
        } @submit_buttons,
    );

  $form->elements([@all_elements]);

  $form->process();

  $st->{form} = $form;

  if ($form->submitted_and_valid()) {
    if (defined $c->req->params->{Finish}) {
      my $text = $form->param_value($finish_textarea);
      $text = trim($text);

      if (length $text > 0) {
         $self->set_metadata($schema, MESSAGE_FOR_CURATORS_KEY, $text);
      } else {
        $self->unset_metadata($schema, MESSAGE_FOR_CURATORS_KEY);
      }

      _redirect_and_detach($c, 'finished_publication');
    } else {
      _redirect_and_detach($c, 'reactivate_session');
    }
  } else {
    my $force = {};
    my $no_annotation_reason =
      $self->get_metadata($schema, Canto::Curs::State::NO_ANNOTATION_REASON_KEY());
    if (defined $no_annotation_reason) {
      # user ticked the "no genes" checkbox on the gene upload page
      $force = { force => SESSION_ACCEPTED };

      $st->{no_annotation_reason} = $no_annotation_reason;
    }

    $self->state()->set_state($schema, NEEDS_APPROVAL, $force);
  }
}

sub finished_publication : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Finished publication';
  $st->{show_title} = 0;
  $st->{template} = 'curs/finished_publication.mhtml';

  my $schema = $c->stash()->{schema};

  my $no_annotation_reason =
    $self->get_metadata($schema, Canto::Curs::State::NO_ANNOTATION_REASON_KEY());

  if (defined $no_annotation_reason) {
    $st->{no_annotation_reason} = $no_annotation_reason;
  }
}

sub offline_message : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Canto preview';
  $st->{show_title} = 0;
  $st->{template} = 'curs/offline_message.mhtml';
}

sub session_exported : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Curation session exported';
  $st->{show_title} = 0;
  $st->{template} = 'curs/session_exported.mhtml';
}

sub pause_curation : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  $self->state()->set_state($schema, CURATION_PAUSED);

  _redirect_and_detach($c);
}

sub _assign_session :Private
{
  my ($self, $c, $reassign) = @_;

  my $st = $c->stash();

  if ($c->stash()->{state} eq EXPORTED) {
    die "This session has now been exported and cannot be assigned or " .
      "reassigned";
  }

  if ($reassign) {
    $st->{title} = 'Reassign session';
  } else {
    $st->{title} = 'Curator details';
  }

  $st->{show_title} = 0;
  $st->{reassign} = $reassign;

  $st->{template} = 'curs/assign_session.mhtml';

  my $config = $c->config();

  my $introduction_text_name = 'submitter_name';
  my $introduction_text_email = 'submitter_email';

  my $curator_manager = $self->curator_manager();

  my ($current_submitter_email, $current_submitter_name, $known_as,
      $accepted_date, $community_curated, $row_creation_date,
      $curs_curator_id, $current_submitter_orcid) =
        $curator_manager->current_curator($st->{curs_key});

  $st->{current_submitter_email} = $current_submitter_email;
  $st->{current_submitter_orcid} = $current_submitter_orcid;

  my $form = $self->form();
  $form->attributes({ autocomplete => 'on', action => '?' });

  my @all_elements = ();

  # $current_submitter_* will be set if the session has been assigned and sent
  # out by the curators
  my $default_submitter_name = ($reassign ? undef : $current_submitter_name);
  my $default_submitter_email = ($reassign ? undef : $current_submitter_email);
  my $default_submitter_orcid = ($reassign ? undef : $current_submitter_orcid);;

  my $demo_user_name = $config->{curs_config}->{demo_user_name};
  my $demo_user_email_address = $config->{curs_config}->{demo_user_email_address};

  if ($reassign && !defined $current_submitter_email) {
    my $last_reassigner_name = $c->session()->{last_reassigner_name};
    my $last_reassigner_email_address = $c->session()->{last_reassigner_email_address};

    if ($config->{demo_mode}) {
      $last_reassigner_name //= $demo_user_name;
      $last_reassigner_email_address //= $demo_user_email_address;
    }

    push @all_elements, (
      {
        type => 'Block', tag => 'p',
        content => 'Please let us know your name and email address for our records:'
      },
      {
        name => 'reassigner_name', label => 'Your name', type => 'Text', size => 40,
        label_tag => 'formfu-label',
        constraints => [ { type => 'Length',  min => 1 }, 'Required' ],
        default => $last_reassigner_name,
      },
      {
        name => 'reassigner_email', label => 'Your email address', type => 'Text', size => 40,
        label_tag => 'formfu-label',
        constraints => [ { type => 'Length',  min => 1 }, 'Required', 'Email' ],
        default => $last_reassigner_email_address,
      },
      {
        type => 'Block', tag => 'p',
        content =>
          'Please enter name and email address of the person you wish to assign ' .
          'this paper to.  ' .
          'The new curator will receive an email with the link to the entry page to ' .
          'curate the paper.',
      }
    );
  } else {
    if ($config->{demo_mode}) {
      $default_submitter_name //= $demo_user_name;
      $default_submitter_email //= $demo_user_email_address;
    }
  }

  push @all_elements, (
      {
        name => 'submitter_name',
        label => ucfirst (($reassign ? 'new curator ' : '') . 'name'),
        label_tag => 'formfu-label',
        type => 'Text', size => 40,
        constraints => [ { type => 'Length',  min => 1 }, 'Required' ],
        default => $default_submitter_name,
      },
      {
        name => 'submitter_email',
        label => ucfirst (($reassign ? 'new curator ' : '') . 'email'),
        label_tag => 'formfu-label',
        type => 'Text', size => 40,
        constraints => [ { type => 'Length',  min => 1 }, 'Required', 'Email' ],
        default => $default_submitter_email,
     },
    );

  if (!$reassign) {
    my $orcid_help_uri = $c->uri_for('/docs/orcid_canto');

    push @all_elements,
      {
        type => 'Block', tag => 'p',
        attributes => { style => 'margin-top: 15px', },
        content_xml => 'Your <a href="http://www.orcid.org">ORCID</a> (optional but recommended):'
      },
      {
        name => 'submitter_orcid',
        label_tag => 'formfu-label',
        type => 'Text', size => 40,
        default => $default_submitter_orcid
      },
      {
        type => 'Block', tag => 'p',
        attributes => { style => 'margin: 5px', },
        content_xml => '<a href="' . $orcid_help_uri . '">Why we collect ORCIDs</a>',
      };
  }

  push @all_elements,
    {
      name => 'submit', type => 'Submit', value => 'Continue',
      attributes => { class => 'btn btn-primary curs-finish-button', },
    };

  $form->elements([@all_elements]);

  $form->process();

  $st->{form} = $form;

  if ($form->submitted_and_valid()) {
    my $reassigner_name_value = $form->param_value('reassigner_name');
    if (defined $reassigner_name_value) {
      $reassigner_name_value = trim($reassigner_name_value);
      if ($reassigner_name_value =~ /\@/) {
        push @{$c->stash()->{message}},
          "Names can't contain the '\@' character: $reassigner_name_value - please " .
            "try again";
        return;
      }
    }

    my $reassigner_name = $reassigner_name_value // $current_submitter_name;
    my $reassigner_email =
      $form->param_value('reassigner_email') // $current_submitter_email;

    if (defined $reassigner_email) {
      $reassigner_email = trim($reassigner_email);
    }

    my $submitter_name = trim($form->param_value('submitter_name'));
    my $submitter_email = trim($form->param_value('submitter_email'));
    my $submitter_orcid = trim($form->param_value('submitter_orcid'));

    if ($submitter_name =~ /\@/) {
      push @{$c->stash()->{message}},
        "Names can't contain the '\@' character: $submitter_name - please " .
        "try again";
      return;
    }

    my $schema = Canto::Curs::get_schema($c);
    my $curs_key = $st->{curs_key};

    my $add_submitter = sub {
      if (!defined $current_submitter_email && defined $reassigner_email) {
        # used to pre-populate the reassign form next time
        $c->session()->{last_reassigner_name} = $reassigner_name;
        $c->session()->{last_reassigner_email} = $reassigner_email;
        $curator_manager->set_curator($curs_key, $reassigner_email,
                                      $reassigner_name);
      }
      if (!defined $current_submitter_email ||
          $submitter_email ne $current_submitter_email ||
          $submitter_name ne $current_submitter_name) {
        $curator_manager->set_curator($curs_key, $submitter_email,
                                      $submitter_name, $submitter_orcid);
      }
      if (!$reassign) {
        $curator_manager->accept_session($curs_key);

        $c->session()->{last_submitter_email} = $submitter_email;
      }
    };

    $schema->txn_do($add_submitter);

    $self->state()->store_statuses($schema);

    my $st = $c->stash();
    my $pub_uniquename = $st->{pub}->uniquename();

    if ($reassign) {
      my $subject = "Session $curs_key reassigned to $submitter_name <$submitter_email>";

      $self->_send_email_from_template($c, 'session_reassigned',
                                       { reassigner_name => $reassigner_name,
                                         reassigner_email => $reassigner_email } );
      $self->_send_email_from_template($c, 'reassigner',
                                       { recipient_name => $reassigner_name,
                                         reassigner_name => $reassigner_name,
                                         recipient_email => $reassigner_email,
                                         reassigner_email => $reassigner_email } );

      push @{$c->flash()->{message}}, "Session has been reassigned to: $submitter_email";

      _redirect_to_top_and_detach($c);
    } else {
      $self->_send_email_from_template($c, 'session_accepted');
      _redirect_and_detach($c);
    }
  }
}

sub reassign_session : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  $self->_assign_session($c, 1);
}

sub assign_session : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  $self->_assign_session($c, 0);
}

sub curation_paused : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();

  $st->{title} = 'Curation paused';
  $st->{show_title} = 0;
  $st->{template} = 'curs/curation_paused.mhtml';
}

sub restart_curation : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  $self->state()->set_state($schema, CURATION_IN_PROGRESS);

  $self->unset_metadata($schema, 'paused_message');

  push @{$c->flash()->{message}}, 'Session has been restarted';

  _redirect_and_detach($c);
}

sub reactivate_session : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  if ($c->stash()->{state} eq EXPORTED) {
    die "can't reactivate an exported session";
  }

  my $schema = $c->stash()->{schema};

  my $state = $c->stash()->{state};

  cluck "invalid state: $state, when reactivating session"
    unless $state eq NEEDS_APPROVAL or $state eq APPROVED;

  $self->state()->set_state($schema, CURATION_IN_PROGRESS,
                   { force => $state });

  $self->unset_metadata($schema, Canto::Curs::State::NO_ANNOTATION_REASON_KEY());

  $self->set_metadata($schema, Canto::Curs::State::REACTIVATED_TIMESTAMP_KEY,
                      Canto::Util::get_current_datetime());
  $self->state()->store_statuses($c->stash()->{schema});

  push @{$c->flash()->{message}}, 'Session has been reactivated';

  _redirect_and_detach($c);
}

sub unexport_session : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $state = $c->stash()->{state};

  if ($state ne EXPORTED) {
    die qq(can't un-export a session that isn't in the "EXPORTED" state);
  }

  my $schema = $c->stash()->{schema};

  my $current_user = $c->user();
  $self->state()->set_state($schema, APPROVED,
                            { force => $state, current_user => $current_user});

  $self->state()->store_statuses($c->stash()->{schema});

  push @{$c->flash()->{message}}, 'Session has been un-exported';

  _redirect_and_detach($c);
}

sub set_exported_state : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $state = $c->stash()->{state};

  if ($state ne APPROVED) {
    die qq(can't un-export a session that isn't in the "EXPORTED" state);
  }

  my $schema = $c->stash()->{schema};

  my $current_user = $c->user();
  $self->state()->set_state($schema, EXPORTED,
                            { force => $state, current_user => $current_user});

  push @{$c->flash()->{message}}, 'Session has been un-exported';

  _redirect_and_detach($c);
}

sub _start_approval
{
  my ($self, $c, $force) = @_;

  my $schema = $c->stash()->{schema};

  my $current_user = $c->user();

  if (defined $current_user && $current_user->is_admin()) {
    $self->state()->set_state($schema, APPROVAL_IN_PROGRESS,
                     {
                       current_user => $current_user,
                       force => $force,
                     });
  } else {
    $c->flash()->{error} = 'Only admin users can approve sessions';
  }

  _redirect_and_detach($c);

}

sub _send_mail
{
  my $self = shift;
  my $c = shift;

  die "@_" unless @_ % 2 == 0;

  my %args = @_;
  my $body = $args{body};
  my $subject = $args{subject};
  my $dest_email = $args{to};
  my $from = $args{from};

  my $config = $c->config();
  my $mail_sender = Canto::MailSender->new(config => $config);

  if ($dest_email eq 'admin') {
    $mail_sender->send_to_admin(subject => $subject,
                                body => $body);
  } else {
    $mail_sender->send(to => $dest_email,
                       from => $from,
                       subject => $subject,
                       body => $body);
  }
}

sub _send_email_from_template
{
  my $self = shift;
  my $c = shift;
  my $type = shift;
  my $extra_template_args = shift;

  my $config = $c->config();

  my $email_util = Canto::EmailUtil->new(config => $config);

  my $st = $c->stash();
  my $curs_key = $st->{curs_key};
  my $pub = $st->{pub};

  my ($submitter_email, $submitter_name, $submitter_known_as) =
    $self->curator_manager()->current_curator($curs_key);

  my $help_index = $c->uri_for($config->{help_path});

  my %args = (
    session_link => $st->{curs_root_uri},
    curator_name => $submitter_name,
    curator_known_as => $submitter_known_as,
    curator_email => $submitter_email,
    publication_uniquename => $pub->uniquename(),
    publication_title => $pub->title(),
    help_index => $help_index,
    logged_in_user => $c->user(),
  );

  @args{keys %{$extra_template_args}} = values %{$extra_template_args};

  my $recipient_email = $args{recipient_email} // $submitter_email;

  my ($subject, $body, $from) = $email_util->make_email($type, %args);

  if (!$from || $from =~ /CONFIGURE_ME_IN_CANTO_DEPLOY/i) {
    warn "config->{email}->{from_address} not configured - no email sent for:\n" .
      "  $subject\n";

    return;
  }

  if ($from eq "DO_NOT_EMAIL") {
    return;
  }

  $self->_send_mail($c, subject => $subject, body => $body, to => $recipient_email,
                    from => $from);
}

sub begin_approval : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  if ($c->stash()->{state} eq EXPORTED) {
    die "can't start approval of an exported session";
  }

  _start_approval(@_);
}

sub restart_approval : Chained('top') Args(0)
{
  _start_approval(@_, APPROVED);
}

sub complete_approval : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $schema = $c->stash()->{schema};

  my @messages = ();

  my $obsolete_term_count = 0;

  my $lookup = Canto::Track::get_adaptor($c->config(), 'ontology');

  my $ann_rs = $schema->resultset('Annotation');

  ANNOTATION:
  while (defined (my $ann = $ann_rs->next())) {
    my $data = $ann->data();

    if (defined $data) {
      my $term_ontid = $data->{term_ontid};

      if (defined $term_ontid) {
        my $term_details = $lookup->lookup_by_id(id => $term_ontid);

        if (defined $term_details) {
          if ($term_details->{is_obsolete}) {
            push @messages, {
              title => "Session can't be approved as there an obsolete term: $term_ontid",
            };
            last ANNOTATION;
          }
        } else {
          push @messages, {
            title => "Session can't be approved as a term ID is not in the database: $term_ontid",
          };
          last ANNOTATION;
        }
      }
    }
  }

  my $term_sugg_count = $self->get_metadata($schema, Canto::Curs::State::TERM_SUGGESTION_COUNT_KEY);
  if (defined $term_sugg_count && $term_sugg_count > 0) {
    push @messages, {
      title => q|Session can't be approved as there are outstanding term requests|,
    };
  }

  my $unknown_cond_count = $self->get_metadata($schema, Canto::Curs::State::UNKNOWN_CONDITIONS_COUNT_KEY);
  if (defined $unknown_cond_count && $unknown_cond_count > 0) {
    push @messages, {
      title => q|Session can't be approved as there are conditions that aren't in the condition ontology|,
    };
  }

  if (@messages) {
    $c->flash()->{error} = [@messages];
  } else {
    my $current_user = $c->user();

    $self->state()->set_state($schema, APPROVED,
                              {
                                current_user => $current_user,
                              });
    push @{$c->flash()->{message}}, 'Session approved';
  }

  _redirect_and_detach($c);
}


sub ws : Chained('top') CaptureArgs(1)
{
  my ($self, $c, $type) = @_;

  $c->stash()->{ws_type} = $type;
}

=head2 ws_list

 Function: Web service for returning the data from a Curs as lists
 Args    : None - the $type comes from the stash

=cut

sub ws_list : Chained('ws') PathPart('list')
{
  my ($self, $c, @args) = @_;

  my $type = $c->stash()->{ws_type};
  my $schema = $c->stash()->{schema};
  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  my $json_data = $c->req()->body_data();

  if ($json_data) {
    push @args, $json_data;
  }

  $c->stash->{json_data} = $service_utils->list_for_service($type, @args);

  $c->forward('View::JSON');
}

=head2 ws_details

 Function: Web service for returning information about a Curs object
 Args    : $ws_type - object type from the stash (from sub ws)
           $id   - the object id (eg. genotype_id)

=cut

sub ws_details : Chained('ws') PathPart('details')
{
  my ($self, $c, @args) = @_;

  my $type = $c->stash()->{ws_type};
  my $schema = $c->stash()->{schema};
  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  my $json_data = $c->req()->body_data();

  if ($json_data) {
    push @args, $json_data;
  }

  $c->stash->{json_data} = $service_utils->details_for_service($type, @args);

  $c->forward('View::JSON');
}

sub ws_annotation : Chained('top') PathPart('ws/annotation') CaptureArgs(2)
{
  my ($self, $c, $annotation_id, $status) = @_;

  $c->stash()->{annotation_id} = $annotation_id;
  $c->stash()->{annotation_status} = $status;
}

sub ws_change_annotation : Chained('ws_annotation') PathPart('change')
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $annotation_id = $st->{annotation_id};

  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  my $json_data = $c->req()->body_data();

  $c->stash->{json_data} =
    $service_utils->change_annotation($annotation_id, $json_data);

  $c->forward('View::JSON');
}

sub _set_annotation_data
{
  my $annotation = shift;
  my $key = shift;
  my $value = shift;

  my $data = $annotation->data();

  if ($value) {
    $data->{$key} = $value;
  } else {
    delete $data->{$key};
  }

  $annotation->data($data);
  $annotation->update();
}

sub ws_annotation_data_set : Chained('top') PathPart('ws/annotation/data/set') Args(3)
{
  my ($self, $c, $annotation_id, $key, $value) = @_;

  my $st = $c->stash();

  my $schema = $st->{schema};

  my $allowed_keys = $c->config()->{curs_settings_service}->{allowed_data_keys};

  if (!$allowed_keys->{$key}) {
    $st->{json_data} = {
      status => 'error',
      message => qq(setting with key "$key" not allowed),
    };
    $c->forward('View::JSON');
    return;
  }

  $st->{json_data} = {
    status => 'success',
  };

  $schema->txn_begin();

  if ($annotation_id =~ /^\d+$/) {
    my $annotation = $schema->resultset('Annotation')->find($annotation_id);
    _set_annotation_data($annotation, $key, $value);
  } else {
    if ($annotation_id eq 'all') {
      my @annotations = $schema->resultset('Annotation')->all();

      map {
        _set_annotation_data($_, $key, $value);
      } @annotations;
    } else {
      $st->{json_data} = {
        status => 'error',
        message => qq(no annotation with id "$annotation_id"),
      };
    }
  }

  $schema->txn_commit();

  $c->forward('View::JSON');
}

sub ws_annotation_create : Chained('top') PathPart('ws/annotation/create')
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  my $json_data = $c->req()->body_data();

  $c->stash->{json_data} = $service_utils->create_annotation($json_data);

  $c->forward('View::JSON');
}

sub ws_annotation_delete : Chained('top') PathPart('ws/annotation/delete')
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  my $json_data = $c->req()->body_data();

  $c->stash->{json_data} = $service_utils->delete_annotation($json_data);

  $c->forward('View::JSON');
}

sub ws_allele_set_note : Chained('top') PathPart('ws/allele_note/set')
{
  my ($self, $c, $allele_primary_identifier, $key, $value) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $guard = $schema->txn_scope_guard();

  my $allele_manager =
    Canto::Curs::AlleleManager->new(config => $c->config(),
                                    curs_schema => $schema);

  if (!$value) {
    # it's a POST
    $value = $c->request()->body_data()->{data};
  }

  $allele_manager->set_note($allele_primary_identifier, $key, $value);

  $c->stash->{json_data} = {
    status => 'success',
  };

  $guard->commit();

  $c->forward('View::JSON');
}

sub ws_allele_delete_note : Chained('top') PathPart('ws/allele_note/delete')
{
  my ($self, $c, $allele_primary_identifier, $key) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $guard = $schema->txn_scope_guard();

  my $allele_manager =
    Canto::Curs::AlleleManager->new(config => $c->config(),
                                    curs_schema => $schema);

  $allele_manager->set_note($allele_primary_identifier, $key, undef);

  $c->stash->{json_data} = {
    status => 'success',
  };

  $guard->commit();

  $c->forward('View::JSON');
}

sub ws_genotype_delete : Chained('top') PathPart('ws/genotype/delete')
{
  my ($self, $c, $feature_id) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  my $json_data = $c->req()->body_data();

  $c->stash->{json_data} = $service_utils->delete_genotype($feature_id, $json_data);

  $c->forward('View::JSON');
}

sub ws_metagenotype_delete : Chained('top') PathPart('ws/metagenotype/delete')
{
  my ($self, $c, $feature_id) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  my $json_data = $c->req()->body_data();

  my $guard = $schema->txn_scope_guard();

  $c->stash->{json_data} = $service_utils->delete_metagenotype($feature_id, $json_data);

  $guard->commit();

  $c->forward('View::JSON');
}

sub ws_add_gene : Chained('top') PathPart('ws/gene/add')
{
  my ($self, $c, $gene_identifier) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  $st->{json_data} = $service_utils->add_gene_by_identifier($gene_identifier);

  $c->forward('View::JSON');
}

sub ws_add_organism : Chained('top') PathPart('ws/organism/add')
{
  my ($self, $c, $taxonid) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};


  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  $st->{json_data} = $service_utils->add_organism_by_taxonid($taxonid);

  $c->forward('View::JSON');
}

sub ws_add_strain_by_id : Chained('top') PathPart('ws/strain_by_id/add')
{
  my ($self, $c, $track_strain_id) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  $st->{json_data} = $service_utils->add_strain_by_id($track_strain_id);

  $c->forward('View::JSON');
}

sub ws_add_strain_by_name : Chained('top') PathPart('ws/strain_by_name/add')
{
  my ($self, $c, $taxon_id, @strain_name_parts) = @_;

  my $strain_name = join '/', @strain_name_parts;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  $st->{json_data} = $service_utils->add_strain_by_name($taxon_id, $strain_name);

  $c->forward('View::JSON');
}

sub ws_delete_organism : Chained('top') PathPart('ws/organism/delete')
{
  my ($self, $c, $taxonid) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};


  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  $st->{json_data} = $service_utils->delete_organism_by_taxonid($taxonid);

  $c->forward('View::JSON');
}

sub ws_delete_strain_by_id : Chained('top') PathPart('ws/strain_by_id/delete')
{
  my ($self, $c, $track_strain_id) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};


  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  $st->{json_data} = $service_utils->delete_strain_by_id($track_strain_id);

  $c->forward('View::JSON');
}

sub ws_delete_strain_by_name : Chained('top') PathPart('ws/strain_by_name/delete')
{
  my ($self, $c, $taxon_id, @strain_name_parts) = @_;

  my $strain_name = join '/', @strain_name_parts;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $service_utils = Canto::Curs::ServiceUtils->new(curs_schema => $schema,
                                                     config => $c->config());

  $st->{json_data} = $service_utils->delete_strain_by_name($taxon_id, $strain_name);

  $c->forward('View::JSON');
}

sub ws_settings_get_all : Chained('top') PathPart('ws/settings/get_all')
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $data = {
    $self->all_metadata($schema),
  };

  $st->{json_data} = $data;

  $c->forward('View::JSON');
}

sub ws_settings_set : Chained('top') PathPart('ws/settings/set')
{
  my ($self, $c, $key) = @_;

  my $body_data = _decode_json_content($c);

  my $value = $body_data->{value};

  my $st = $c->stash();
  my $schema = $st->{schema};

  my $allowed_keys = $c->config()->{curs_settings_service}->{allowed_keys};

  if ($allowed_keys->{$key}) {
    $self->set_metadata($schema, $key, $value);

    $st->{json_data} = {
      status => 'success',
    }
  } else {
    $st->{json_data} = {
      status => 'error',
      message => qq(setting with key "$key" not allowed),
    }
  }

  $c->forward('View::JSON');
}

sub cancel_approval : Chained('top') Args(0)
{
  my ($self, $c) = @_;

  my $schema = $c->stash()->{schema};
  $self->state()->set_state($schema, NEEDS_APPROVAL,
                            { force => APPROVAL_IN_PROGRESS });
  push @{$c->flash()->{message}}, 'Session approval cancelled';

  _redirect_and_detach($c);
}

sub end : Private
{
  my ($self, $c) = @_;

  my $st = $c->stash();
  $c->stash()->{error_template} = 'curs/error.mhtml';

  Canto::Controller::Root::end(@_);
}

1;
