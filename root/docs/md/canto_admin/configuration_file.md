# Configuration settings
## canto.yaml
The default configuration is stored in `canto.yaml` in the top level
directory.  Any installation specific settings can be added to
`canto_deploy.yaml`, and will override the defaults.  The `canto_deploy.yaml`
will be created automatically by the `canto_start` start script when it is run
with the `--initialise` option. 

The configuration files are [YAML format](http://en.wikipedia.org/wiki/YAML).

### name
A one word name for the site. default: Canto

### long_name
A longer description of the site. e.g. The SlugBase community annotation tool

### database_name
The destination database name.  This is used whenever we need to refer to the
destination of the annotations while curating.

### database_url
The URL of the database that this instance is installed for. e.g.
`http://www.pombase.org/`

### header_image
A path (relative to `root/static`) of the logo to put in the header.

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

### available_annotation_type_list
List of possible annotation type and their configuration details.

See [Configuring annotation types](configuration_file#configuringannotationtypes)
for details.

### enabled_annotation_type_list
The names of the types that are enabled in this Canto instance.  If not set
all annotation types from `available_annotation_type_list` will be enabled.

#### name
The identifier for this annotation type, used internally and in URLs.

#### category
One of: "ontology" or "interaction", used to select which Perl package
should be used for rendering and storing these annotation type.

### messages

### test_config_file
The path to the extra configuration file needed while testing.

### help_text
The keys under `help_text` identify a page in Canto and under the key is one
or both of `inline` or `url`. The help text and link is rendered by the
`inline_help.mhtml` template. If a `url` is given, the text under `inline`
will be `title` attribute of a link with that URL. Without a `url` a help link
(a "?" icon) will be shown and the `inline` text will be displayed in a pop-up
DIV.

### contact_email
This email address is shown anytime a contact address is needed. See the
`contact.mhtml` template.

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

### evidence_codes
Possible evidence codes for this annotation type.  Each evidence code must
appear in the [`evidence_types`](#evidence_types) list.  (Required)

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
A longer help text shown when the user clicks "more ..." under the help_text.
(Optional)

### detailed_help_path
A path in the documentation directory (`root/docs/`) to link to for detailed
help about this type of annotation.

### annotation_comment_help_text
Help text to show once the user finishes annotating a paper, after "Submit to
curators".  (Optional)
