# Configuration settings
## canto.yaml
The default configuration is stored in `canto.yaml` in the top level
directory.  Any installation specific settings can be added to
`canto_deploy.yaml`, and will override the defaults.  The `canto_deploy.yaml`
will be created automatically by the `canto_start` start script when it is run
with the `--initialise` option. 

The configuration files are [YAML format](http://en.wikipedia.org/wiki/YAML).

### name
A one word name for the application. default: Canto

### long_name
A longer description of the site. e.g. The SlugBase community annotation tool

### database_name
The destination database name.  This is used whenever we need to refer to the
destination of the annotations while curating.

### database_url
The URL of the database that this instance is installed for. e.g.
`http://www.pombase.org/`

### instance_front_subtitle
The subtitle to use on the front greeting page.

### header_image
A path (relative to `root/static`) of the logo to put in the header.

### message_of_the_day
If set, show this text as a notice at the top of curation session pages.

### instance_organism
Canto has two modes: single or multi organism.  Single organism mode is
activated by setting an "instance organism".  That organism will be assumed
throughout the interface.  Only genes from that single organism can be
annotated and the user will not be shown the organism name.

In multi organism mode, genes from any number of organisms can be annotated in
each session.  In this mode after uploading a list of gene identifiers, the
user will be shown the organism name as well as the names, synonyms and
products.  The organism is shown so the user can confirm that the identifier
they gave matched the gene from the right organism.  Generally an external
gene adaptor should be configured using the [instance_organism](`instance_organism`)
setting in the multi-organism case.

Example:

    instance_organism:
      taxonid: 4896

### canto_url
The link for the main Canto web site.

### app_version
The software version, automatically updated each release.

### schema_version
The version of the schema. This is incremented when the schema changes in an
incompatible way.

### authentication
Configuration for the Catalyst authentication code. This shouldn't need changing.

### view_options
Configuration for the admin view pages.

#### max_inline_results_length
The maximum number of lines of results to show in a table on an object
page.

### alleles_have_expression
If 1, allow editing of the expression of alleles and show the expression
as a column in the genotype table on the genotype management page.

### split_genotypes_by_organism
If 1, show the organism in a selector on the genotype management pages
and only show genes and genotypes for the selected organism.

### show_genotype_management_genes_list
If 0, hide the list of genes and actions on the left hand side of the
genotype management page.

### notes_on_single_genotypes_only
If 1, allow notes/comments on diploids and multi-locus genotypes.

### allow_single_wildtype_allele
If 0, a wildtype allele is allowed only if there is another non-wildtype or
non-wildtype expression allele from the same gene.

### show_quick_deletion_buttons
If 1 (the default), show the "Deletion" buttons in the gene table on
the genotype management page.

### diploid_mode
If 1, allow diploids to be created and used in genotypes.

### allele_note_types
A list of allele note type name and display names.  The `display_name`
is shown in the note editing dialog.  Example configuration:

```
allele_note_types:
  - name: phenotype
    display_name: Phenotype
  - name: interaction_comment
    display_name: Interaction coment
```

### db_initial_data
Data needed to initialise a Canto instance.

### class_info
Descriptions of table in the database used by the interface. This
information is used for rendering the view and object pages.

### reports
A list of report names to show on the front page.

### export
Configuration for exporting.

### load
Configuration for loading data.

### track_db_template_file
The template database to use when creating a new Canto instance.

### curs_db_template_file
The template database to use when creating a new curation session.

### ontology_index_dir
The name of the directory used for the ontology Lucene index. This index
is used to do autocompeletion in the interface.

### external_sources
URLs of external services.

### implementation_classes
Names of classes used to implement database query and storage. This
allows the implementations to be swapped from the defaults.

#### gene_adaptor
Used to look up gene identifier, name, synonyms and products. The default
is to use the internal Canto database ("track").

### evidence_types
Short name (codes) and long names of evidence types. Any evidence type
configured with the option "with_gene" set to true will cause the
interface to ask for a gene for later storage in the "with/from" column
of a GAF file.

Evidence codes must also be configured for in
`available_annotation_type_list`.  See [`evidence_codes`](#evidence_codes) in
the [Configuring annotation types](configuringannotationtypes) section.

Example:

    evidence_types:
      IMP:
        name: Inferred from Mutant Phenotype
      IDA:
        name: Inferred from Direct Assay
      IGI:
        name: Inferred from Genetic Interaction
        with_gene: 1
      Microscopy: ~

In this case "Microscopy" is treated as an evidence code and an evience
description.

### namespace_term_evidence_codes
A map of defaults for the term to evidence lists configuration.  If
`term_evidence_codes` isn't set in an annotation type definition this
map will be consulted to find defaults for the namespace of the
annotation type.  See
[`term_evidence_codes`](configuration_file#termevidencecodes) for
details.

This example will set `term_evidence_codes` for all annotation types
that are configured with the namespace "fission_yeast_phenotype":

    namespace_term_evidence_codes:
      fission_yeast_phenotype:
        - constraint: "is_a(FYPO:0001985)"
          evidence_codes:
           - Cell growth assay
           - Chromatin immunoprecipitation experiment

### available_annotation_type_list
List of possible annotation type and their configuration details.

See [Configuring annotation types](configuration_file#configuringannotationtypes)
for details.

### enabled_annotation_type_list
The names of the types that are enabled in this Canto instance.  If not set
all annotation types from `available_annotation_type_list` will be enabled.

### test_config_file
The path to the extra configuration file needed while testing.

### help_text
The keys under `help_text` identify a part of Canto's user interface for which
the help text should apply. Under the key is one or both of `inline` or `url`.
The help text and link are rendered as a help icon with a tooltip that appears
on mouse-over. If a `url` is given, clicking the help icon will send the user
to the page specified by the `url`.

### contact_email
This email address is shown anytime a contact address is needed. See the
`contact.mhtml` template.

### email_signature
A custom signature line that is displayed at the end of the generic email
templates. If not set, the signature will default to "The \[database_name\]
team", where the database name is the value of the `database_name` setting.

### external_links
Each external link configuration has three possible parameters:

- `name` - The text to use as the title of the link.
- `icon` - An image from the `root/static/images/logos` to use as the `<img>`
  in the link.
- `url` - The URL to the appropriate page on an external site. This string
  can contain text to substitute in the form `@@key@@`. On the gene page, the
  key can be `primary_identifier` (the gene systematic ID) or `primary_name`
  (the gene name). On the publication page the key should be `uniquename`
  which will substitute the PubMed ID into the URL.
- `sysid_link` - This external link will be used to hyperlink the primary
  identifier on the gene page as well as being shown in the external links
  section on the right of the page.

There are two possible types of external link on the gene pages:

- `generic` - These links will be shown on all gene pages.
- `organism` - These links are specific to the given organism. The keys under
  the `organism` section will be the full organism name (ie "Genus species").

The external links are implemented in the `linkouts.html` template.

## Configuring annotation types
The possible annotation type are set with the
`available_annotation_type_list` configuration.  It should be set to a `YAML`
list of maps.  An example is provided in the `canto.yaml` but can be
overridden in the instance specific `canto_deploy.yaml`.

In `canto_deploy.yaml` you can add an optional
`enabled_annotation_type_list`.  If set only the listed types will be enabled.

For example this would enable just two annotation types:

    enabled_annotation_type_list:
      - molecular_function
      - cellular_component

`enabled_annotation_type_list` exists so that one
`available_annotation_type_list` configuration in `canto.yaml` can be used in
several Canto instances.  It is optional.  If not set, all available types are
enabled.

Each annotation type in `available_annotation_type_list` has the following
settings:

### name
A short internal name or key for this type.  (Required)

### category
This setting selects which code to use for the interface for this type.  There
are currently two possibilities: `ontology` and `interaction`.  (Required)

### display_name
The long name to display in the user for this type.  eg.  for
`molecular_function` PomBase displays `GO molecular function`.  (Required)

### short_display_name
A shorter name for this type.  eg `molecular function`  (Optional)

### very_short_display_name
A very short name for this type.  eg `F` for GO molecular function.  (Optional)

### abbreviation
Currently used only for types from GO (`molecular_function`,
`cellular_component`, and `biological_process`), the abbreviation is used from
exporting annotation to GAF files.  Required only if GO ontologies are enabled.

### can_have_conditions
If 1, this annotation type can have conditions as well as evidence.
Mostly useful for phenotypes.

### single_allele_only
If true, only display/allow genotypes containing a single allele for
this annotation type.  If set to "ignore_accessory", accessory alleles
will be ignored when counting alleles in a genotype.

### single_locus_only
For interactions, restrict the genotype B list to contain only
genotypes for the same locus selected in the genotype A list.

### interaction_term_required
For interactions, selecting a term is required if and only if this
option is set to 1.

### second_feature_organism_selector
For interactions, if set the annotation dialog will have a independent
organism selector for the second feature of the interaction.  Defaults
to 0 (false).

### evidence_codes
Possible evidence codes (or interaction types) for this annotation type.
Each evidence code must
appear in the [`evidence_types`](#evidence_types) list.  (Required)

### admin_evidence_codes
Evidence codes that are only available for logged in admin user.  This
list is added to the `evidence_codes` list.

### term_evidence_codes
Used to restrict the visible evidence codes based on a currently
selected term (if any).  The `constraint` values are used for matching the term.  If
the current term is a descendent of the term before the "-" in the key
and not a descendent of the terms to the right of the "-" the given
evidence codes are shown to the user.  The excluded terms to the right
of the "-" are optional.

The first matching configuration is used.
If the current term doesn't match any of the keys in `term_evidence_codes`,
the default evidence codes from `evidence_codes` are displayed.

example:

    term_evidence_codes:
      - constraint: "is_a(FYPO:0001985)"
        evidence_codes:
        - Cell growth assay
        - Chromatin immunoprecipitation experiment
        - Chromatography evidence

or:

    term_evidence_codes:
      - constraint: "is_a(FYPO:0001985)-is_a(FYPO:0000045)&is_a(FYPO:0000150)"
        evidence_codes:
        - Cell growth assay
        - Chromatography evidence

See also `namespace_term_evidence_codes`.

### term_suggestions_annotation_type
If set to the name of an ontology annotation type, use terms from the
annotations of that type as suggestions.  For example, once a genotype is
selected in the interaction dialog, any phenotypes annotated for that
genotype will be shown to the user.  If unset, no suggestions will be
shown.

### hide_extension_relations
A list of extension relation names to hide.  For hidden relations we just
show the extension value (extension range).
(default: empty list)

### broad_term_suggestions
A few comma separated high level or broad term names for use in help text.
eg. for molecular function: "transporter, transferase activity"  (Required
only for ontology annotation types)

### specific_term_examples:
Comma separated specific term name examples.  eg. "adenylate cyclase activity
or biotin transporter activity"  (Required only for ontology annotation types)

### help_text
Short help to be soon initially to users when they begin an annotation of this
type.  (Required)

### more_help_text
A longer help text shown when the user clicks "more..." under the help_text.
(Optional)

### detailed_help_path
A path in the documentation directory (`root/docs/`) to link to for detailed
help about this type of annotation.

### annotation_comment_help_text
Help text to show once the user finishes annotating a paper, after "Submit to
curators".  (Optional)

## host_organism_taxonids
A list of taxon IDs for the organisms that are treated as host species
in pathogen-host mode.  All the list taxon IDs need to match organisms
in the organism table.  The organisms are loaded using
using `canto_add.pl --organism`.  See the [Canto setup documentation](setup#organisms)
for details.

If this list has any elements, Canto will start in pathogen-host
mode and the internal config setting `pathogen_host_mode` will be
automatically set to 1.  Also `host_organisms` will be set to
a list the Organism objects.  `multi_organism_mode` is also set to
1/true.

Note that when `pathogen_host_mode` is enabled, every organism that is in the organism table but _not_ in `host_organism_taxonids` will be assumed to be a pathogen organism.

## allele_type_list
This list contains the configuration for each allele type

### name
The allele type name to show in the display.  This is also the key
when looking up configuration details so it must be unique.

### export_type
The type name to use when writing the export file. See [Exporting data from Canto](data_export)
for more.

### show_description
If true, show the description input box in the allele edit dialog.

### description_required
If true, an allele of this type can't be created without a description.

### allele_name_required
If true, alleles of this types must have a name.

### allow_expression_change
If true, show the checkboxes for changing the allele expression.

### expression_required
If true, an allele of this type can't be created without setting an expression level.

### autopopulate_name
This template is used when an allele name can be automatically generated
for a given type.  For example, if the user selects "wild type" in the
allele editing dialog, this template when set the name to something like "cdc2+".
The string "@@gene_display_name@@" will be replaced with the current
gene's name or systematic ID.

### do_not_annotate
If true, don't show genotypes containing just this allele in the
genotype selectors.  And ignore alleles of this type when deciding if
a genotype is single or multi allele.

### evidence_code_groups
For the `genotype_interaction` annotation type we need to configure
which interaction types are permitted for a given double mutant
phenotype and for the alleles of the double mutant.

There are three sub-attributes:

#### double_mutant_population_phenotype
Settings and constraints for the case where the double mutant has a
population phenotype.

##### parent_constraint
The term constraint used of populations phenotype terms.

##### evidence_codes
Interaction types to allow when the double mutant is a viable poputatation phenotype.

##### inviable_parent_constraint
The term constraint for inviable population phenotypes.

##### inviable_only_evidence_codes
Interaction types to allow when the double mutant is inviable.

##### not_population_evidence_codes
Types allowed when the double mutant doesn't have a poputation phenotype.

#### both_alleles_deletions
Interaction types allowed when both alleles are deletions.

#### one_allele_overexpressed
Interaction types allowed when at least one allele is overexpressed.

