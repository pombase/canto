# Configuration settings
## canto.yaml
The default configuration is stored in `canto.yaml` in the top level
directory.  Any installation specific settings can be added to
`canto_deploy.yaml`, and will override the defaults.  The `canto_deploy.yaml`
will be created automatically by the `canto_start` start script when it is run
with the `--init` argument. 

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
Canto has two modes: single or multi organism. In multi organism mode, genes
from any number of organisms can be annotated in each session. In this mode
after uploading a list of gene identifiers, the user will be shown the
organism name as well as the names, synonyms and products. The organism is
shown so the user can confirm that the identifier they gave matched the gene
from the right organism. In single organism mode the organism is not
displayed.

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
### annotation_type_list
Configuration of the type of annotations possible in this Canto instance.
#### name
The identifier for this annotation type, used internally and in URLs.
#### category
One of: "ontology" or "interaction", used to select which Perl package
should be used for rendering and storing these annotation type.
### messages
## test_config_file
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

