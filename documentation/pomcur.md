# Introduction
Canto is a generic gene annotation tool with a focus on community curation.
This document describes Canto from the adminstrators perspective.

# Requirements
- Linux, BSD or UNIX
- Perl, clucene

# Getting the code
Currently the easiest way to get the code is via GitHub.  Run this command
to get a copy of the code:

    git clone https://github.com/pombase/canto.git

This creates a directory called "`pomcur`".  The directory can be updated
later with the command:

    git pull

# Installation
## Installing basic prerequisites
### Debian and Ubuntu
To improve the installation speed, these packages can be installed using the
package manager before preceeding:

    sudo apt-get install perl gcc g++ tar gzip bzip2 make libmodule-install-perl
    sudo apt-get install libhash-merge-perl \
      libhtml-mason-perl libplack-perl libdbix-class-perl \
      libdbix-class-schema-loader-perl libcatalyst-modules-perl libio-all-lwp-perl \
      libwww-perl perl gcc g++ tar gzip bzip2 make libmodule-install-perl \
      libclucene-dev libclucene0ldbl libjson-xs-perl libio-all-perl \
      libio-string-perl libmemoize-expirelru-perl libtry-tiny-perl \
      libarchive-zip-perl libtext-csv-xs-perl liblingua-en-inflect-number-perl \
      libcatalyst-modules-perl libmoose-perl libdata-compare-perl \
      libmoosex-role-parameterized-perl libfile-copy-recursive-perl \
      libxml-simple-perl libtext-csv-perl libtest-deep-perl
    sudo cpan Dist::CheckConflicts
    sudo cpan Module::Install::Catalyst


If installing from the `git` repository, the git executable will be needed:

    sudo apt-get install git-core

### CPAN tip
Use these commands at the `cpan` prompt avoid lots of questions while
installing:

    o conf prerequisites_policy follow
    o conf build_requires_install_policy no
    o conf commit

This command at the CPAN prompt will update CPAN and install Readline
support:

    install Bundle::CPAN

### Install dependencies

    perl Makefile.PL
    make

# Quick start guide
## Initialising the data directory
From the in the `pomcur` directory:

   `./script/pomcur_start --init <some_directory>`

## Running the server

   `./script/pomcur_start`

## Visit the application start page
The application should now be running at:

   http://localhost:5000

# Configuration
## pomcur.yaml
### name
A one word name for the site.
### long_name
A longer description of the site.
### database_name
Database name for prefixing identifiers when exporting.
### header_image
A the path relative to `root/static` of the logo to put in the header.
### app_version
The software version.
### home_path
The path to use for the home link.
### authentication
Configuration for the Catalyst authentication code.
### view_options
Configuration for the view.
#### max_inline_results_length
The maximum number of lines of results to show in a table on an object
page.
### db_initial_data
Data needed to initialise a Canto instance.
### class_info
Descriptions of table in the database used by the interface.  This
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
The name of the directory used for the ontology Lucene index.  This index
is used to do autocompeletion in the interface.
### external_sources
URLs of external services.
### implementation_classes
Names of classes used to implement database query and storage.  This
allows the implementations to be swapped from the defaults.
#### gene_adaptor
Used to lookup gene identifier, name, synonyms and products.  The default
is to use the internal Canto database ("track").
### evidence_types
Short name (codes) and long names of evidence types.  Any evidence type
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
### test_config_file
### test_gene_identifiers
### test_publication_uniquename
### help_text
### external_links
### webservices
### ontology_external_links
### chado

## Loading data
### Organisms

    ./script/pomcur_load.pl --organism "<genus> <species> <taxon_id>"

### Gene data

    ./script/pomcur_load.pl --genes genes_file.tsv --for-taxon 4896

#### gene data format
Four tab separated columns with no header line:
- systematic identifier
- gene primary name
- synonyms (comma separated)
- product
### Ontology terms

    ./script/pomcur_load.pl --ontology ontology_file.obo

The ontology must be configured in the [annotation_type_list](#annotation_type_list) section of the
`pomcur.yaml` file.

# Implementation details
## Structure
There are two parts to the system.

"Track" run is the part that the adminstrator uses to add people,
publications and curation sessions to the database.

"Curs" handles the user curation sessions.
### Track - user, publication and session tracking
#### Database storage
##### SQLite for main database
### Curs - curation sessions
Each curation session has a cooresponding SQLite database.

## Databases
## Database structure
## Code
Canto is written in Perl, implemented using the Catalyst framework and
running on a Plack server.
## Autocomplete searching
- implemented using CLucene
- short names are weighted more highly so they appear at the top of the search list
- the term names are passed to CLucene for indexing
- all words appearing in the name or synonyms are joined into one string
  for separate indexing by CLucene

# Developing Canto
## Running tests
In general the tests can be run with: `make test` in the main pomcur
directory.  If the schema or test genes or ontologies are is changed the
test data will need to be re-initialised.

## Helper scripts
Scripts to help developers:

- `etc/db_initialise.pl` :: create empty template database from the schemas
  and recreate the database classes in lib/Canto/TrackDB and
  lib/Canto/CursDB
- `etc/test_data_initialise.pl` :: re-create test data files that don't change
  very often.  eg. the test PubMed XML file.  Currently this script only
  needs to be run if the list of publications for the test database
  changes
- `etc/test_initialise.pl` :: initialise the test databases in t/data with
  a small number of genes and a mini version of the Gene Ontology
  database
- `etc/local_initialise.pl` :: create a test instance of Canto in ./local

## Initialising test data
Run the following commands in the pomcur directory to create the test
database and to populate it with test data:

    ./etc/db_initialise.pl
    ./etc/test_initialise.pl

That will need to be done each time the schemas or test data change.

To create a local test instance of Canto, run `local_initialise.pl`

## Running the test instance
The server can be run from the top level directory with this command:

    POMCUR_CONFIG_LOCAL_SUFFIX=local PERL5LIB=lib ./script/pomcur_server.pl -p 5000 -r -d

"5000" is the local port to connect on.  The server should then be
available at http://localhost:5000/

# Contact
For questions or help please contact helpdesk@pombase.org or kim@pombase.org.

Requests of new features can be made by email or by adding an issue on the
[GitHub Canto issue tracker](https://github.com/pombase/canto/issues)
