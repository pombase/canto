package Canto::Role::GAFFormatter;

=head1 NAME

Canto::Role::GAFFormatter - Code for putting annotations in GAF format

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::Role::GAFFormatter

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

use Moose::Role;
use Archive::Zip qw(:CONSTANTS :ERROR_CODES);
use Try::Tiny;
use IO::String;

use Canto::Curs::ExtensionData;

=head2 get_all_curs_annotation_zip

 Usage   : my $annotations = $self->get_all_curs_annotation_zip(...)
  Usage   : my $zip_data = get_all_curs_annotation_zip($config, $curs_resultset);
 Function: return a data string containing all the annotations from all the of
           sessions the given by the $curs_resultset
 Args    : $config - the Config object
           $curs_resultset - the A TrackDB 'Curs' ResultSet
 Returns : the Zip data

=cut

sub get_all_curs_annotation_zip
{
  my $self = shift;
  my $config = shift;
  my $curs_resultset = shift;

  my $zip = Archive::Zip->new();
  my %all_results_by_type = ();

  my $session_count = 0;

  while (defined (my $curs = $curs_resultset->next())) {
    my $curs_key = $curs->curs_key();
    my $cursdb = Canto::Curs::get_schema_for_key($config, $curs_key,
                                                 { cache_connection => 0 });

    my $results = $self->get_all_annotation_tsv($config, $cursdb);

    if (keys %$results > 0) {
      for my $type_name (keys %$results) {
        $all_results_by_type{$type_name} //= '';
        $all_results_by_type{$type_name} .= $results->{$type_name}
      }

      $session_count++;
    }
  }

  my @annotation_type_names = keys %{$config->{annotation_types}};

  for my $type_name (@annotation_type_names) {
    my $file_name = "$type_name.tsv";
    my $annotation_tsv = $all_results_by_type{$type_name} // '';
    my $member = $zip->addString($annotation_tsv, $file_name);
    $member->desiredCompressionMethod(COMPRESSION_DEFLATED);
  }

  my $io = IO::String->new();
  $zip->writeToFileHandle($io);

  return ($session_count, ${$io->string_ref()})
}

=head2 get_curs_annotation_zip

 Usage   : my $zip_data = get_curs_annotation_zip($config, $schema);
 Function: return a data string containing all the annotations from the given
           CursDB, stored in Zip format
 Args    : $config - the Config object
           $schema - the CursDB object
 Returns : the Zip data, or undef if there are no annotations

=cut
sub get_curs_annotation_zip
{
  my $self = shift;
  my $config = shift;
  my $schema = shift;

  my $results = $self->get_all_annotation_tsv($config, $schema);

  if (keys %$results > 0) {
    my $zip = Archive::Zip->new();
    for my $annotation_type_name (keys %$results) {

      my $annotation_type = $config->{annotation_types}->{$annotation_type_name};

      if ($annotation_type->{category} ne 'ontology') {
        next;
      }

      my $annotation_tsv = $results->{$annotation_type_name};
      my $file_name = "$annotation_type_name.tsv";
      my $member = $zip->addString($annotation_tsv, $file_name);
      $member->desiredCompressionMethod(COMPRESSION_DEFLATED);
    }

    my $io = IO::String->new();

    $zip->writeToFileHandle($io);

    return ${$io->string_ref()}
  } else {
    return undef;
  }
}

=head2 get_annotation_table_tsv

 Usage   : my $annotations = $self->get_annotation_table_tsv(...)
 Function: Return a string in GAF format containing the annotations of a
           given type from a session
 Args    : $config - the Config object
           $schema - the CursDB object
           $annotation_type_name - the name of the type of annotation to
                                   retrieve as given in canto.yaml
 Return  : a string in GAF format

=cut
sub get_annotation_table_tsv
{
  my $self = shift;
  my $config = shift;
  my $schema = shift;
  my $annotation_type_name = shift;

  my $annotation_type = $config->{annotation_types}->{$annotation_type_name};

  if (!defined $annotation_type) {
    die qq|no configuration for annotation type "$annotation_type_name"\n|;
  }

  my $ontology_lookup = Canto::Track::get_adaptor($config, 'ontology');

  my ($completed_count, $annotations_ref, $columns_ref);

  try {
    ($completed_count, $annotations_ref, $columns_ref) =
      Canto::Curs::Utils::get_annotation_table($config, $schema,
                                               $annotation_type_name);

  } catch {
    my $conn = $schema->storage()->connect_info()->[0];
    warn "error writing annotation table for $conn: $_";
  };

  if (!defined $completed_count) {
    return;
  }

  my @annotations = @$annotations_ref;
  my %common_values = %{$config->{export}->{gene_association_fields}};

  $common_values{db_object_type} = $annotation_type->{feature_type};

  if ($common_values{db_object_type} eq 'gene') {
    $common_values{db_object_type} = 'protein';
  }

  my @ontology_column_names =
    qw(db gene_identifier gene_name_or_identifier
       qualifiers term_ontid publication_uniquename
       evidence_code with_or_from_identifier
       annotation_type_abbreviation
       gene_product gene_synonyms_string db_object_type taxonid
       creation_date_short assigned_by extension);

  my @phenotype_column_names =
    qw(db genotype_identifier
       term_ontid publication_uniquename
       evidence_code
       db_object_type
       creation_date_short assigned_by extension);

  my @column_names;

  if ($annotation_type->{category} eq 'ontology') {
    if ($annotation_type->{feature_type} eq 'gene') {
      @column_names = @ontology_column_names;
    } else {
      @column_names = @phenotype_column_names;
    }
  } else {
    return '';
  }

  my $db_prefix = $config->{export}->{gene_association_fields}->{db};

  my $results = '';

  for my $annotation (@annotations) {
    next unless $annotation->{completed};


    my $extension_string = '';
    my @extra_qualifiers = ();

    try {

    if (defined $annotation->{extension}) {
      my $qualifier_list;

      ($extension_string, $qualifier_list) =
        Canto::Curs::ExtensionData::as_strings($ontology_lookup, $schema, $db_prefix,
                                               $annotation->{extension});

      @extra_qualifiers = @$qualifier_list;
    }

    $results .= join "\t", map {
      my $column_name = $_;
      my $val = $common_values{$column_name};
      if (!defined $val) {
        $val = $annotation->{$column_name};
      }
      if ($column_name eq 'taxonid') {
        if (!defined $val) {
          use Data::Dumper;
          die "no value for column: $column_name from: ", Dumper([$annotation]);
        }
        $val = "taxon:$val";
      }
      if ($column_name eq 'with_or_from_identifier') {
        if (defined $val && length $val > 0) {
          $val = "$db_prefix:$val";
        } else {
          $val = '';
        }
      }

      if ($column_name eq 'qualifiers') {
        my @quals = ();

        if (defined $val) {
          @quals = @$val;
        }

        push @quals, @extra_qualifiers;

        $val = join(",", @quals);
      }

      if ($column_name eq 'extension') {
        $val = $extension_string;
      }

      if (!defined $val) {
        die "no value for field $column_name\n";
      }

      $val;
    } @column_names;
    $results .= "\n";

    } catch {
      my $conn = $schema->storage()->connect_info()->[0];
      warn "error writing output line for $conn: $_";
    }
  }

  return $results;
}

=head2 get_all_annotation_tsv

 Usage   : my $results_hash = get_all_annotation_tsv($config, $schema);
 Function: Return a hashref containing all the current annotations in tab
           separated values format.  The hash has the form:
             { 'cellular_component' => "...",
               'phenotype' => "..." }
           where the values are the TSV strings.
 Args    : $config - the Config object
           $schema - the CursDB object
 Returns : a hashref of results

=cut
sub get_all_annotation_tsv
{
  my $self = shift;
  my $config = shift;
  my $schema = shift;

  my %results = ();

  for my $annotation_type (@{$config->{annotation_type_list}}) {
    my $annotation_type_name = $annotation_type->{name};
    my $results =
      $self->get_annotation_table_tsv($config, $schema, $annotation_type_name);
    if (length $results > 0) {
      $results{$annotation_type_name} = $results;
    }
  }

  return \%results;
}

1;
