# Introduction
[Canto](http://curation.pombase.org/) is a generic genome annotation tool with
a focus on community curation.  This document describes Canto from the
administrators perspective.  It covers installation and maintenance.

The latest version of this document can always be found on the main
[Canto website](http://curation.pombase.org/pombe/docs/canto_admin) and the
source to it
[on GitHub](https://github.com/pombase/canto/blob/master/documentation/canto_admin.md).

# Requirements for Canto
- Linux, BSD or UNIX
- Perl, CLucene library

# Canto in a Virtual machine
Canto can be tested in a virtual machine using
[VirtualBox](http://www.virtualbox.org) and
[Vagrant](http://www.vagrantup.com/).  This combination is available on Linux,
MacOS and Windows.

These instructions have been tested on a 64 bit host.

## Installing VirtualBox

Installation packages for VirtualBox are available here:
  https://www.virtualbox.org/wiki/Downloads

On some operating systems, packages may be available from the default
repositories:

* Debian: https://wiki.debian.org/VirtualBox
* Ubuntu: https://help.ubuntu.com/community/VirtualBox
* Red Hat/Centos: http://wiki.centos.org/HowTos/Virtualization/VirtualBox

## Installing Vagrant

Installation instructions for Vagrant are here:
http://docs.vagrantup.com/v2/installation/index.html

Users of recent versions of Debian and Ubuntu can install with:

    apt-get install vagrant

## Canto via Vagrant

Once VirtualBox and Vagrant are installed, use these commands to create a
virtual machine, install the operating system (Ubuntu) and install Canto and
its dependencies:

    cd canto
    vagrant box add precise64 http://files.vagrantup.com/precise64.box
    vagrant up

The `vagrant` commands will many minutes to complete.  If everything is
successful, once `vagrant up` returns you can `ssh` to the virtual machine
with:

    vagrant ssh

From that shell, the Canto server can be started with:

    cd canto
    ./script/canto_start

Once started the server can be accessed on port 5500 of the host:
http://localhost:5500/

# Manual installation

## Software requirements

The following software is needed for the installation:

- Perl
- Git
- GCC (for compiling part of the Perl libraries)
- Make
- CLucene v0.9.*
- Module::Install and Module::Install::Catalyst

## Installing prerequisites on Debian and Ubuntu

On Debian and Ubuntu, the software requirements can be installed using the
package manager:

    sudo apt-get install perl gcc g++ tar gzip bzip2 make git-core wget \
      libmodule-install-perl libcatalyst-devel-perl \
      libdist-checkconflicts-perl liblocal-lib-perl

To improve the installation speed, these packages can optionally be installed
before preceding:

    sudo apt-get install libhash-merge-perl \
      libhtml-mason-perl libplack-perl libdbix-class-perl \
      libdbix-class-schema-loader-perl libcatalyst-modules-perl libio-all-lwp-perl \
      libwww-perl libjson-xs-perl libio-all-perl \
      libio-string-perl libmemoize-expirelru-perl libtry-tiny-perl \
      libarchive-zip-perl libtext-csv-xs-perl liblingua-en-inflect-number-perl \
      libcatalyst-modules-perl libmoose-perl libdata-compare-perl \
      libmoosex-role-parameterized-perl libfile-copy-recursive-perl \
      libxml-simple-perl libtext-csv-perl libtest-deep-perl \
      libtext-markdown-perl libchi-driver-memcached-perl libchi-perl \
      libcache-memcached-perl libcache-perl libfile-touch-perl \
      libhtml-html5-builder-perl libplack-middleware-expires-perl \
      libstring-similarity-perl libcatalyst-engine-psgi-perl \
      liblwp-protocol-psgi-perl libweb-scraper-perl \
      libdbd-pg-perl libdata-javascript-anon-perl \
      libdata-rmap-perl

If these packages aren't installed these Perl modules will be installed using
CPAN, which is slower.

The [CLucene](http://clucene.sourceforge.net/) is required by Canto.  For
Debian version 7 ("wheezy") and earlier and Ubuntu version 13.04 ("Raring")
and earlier it can be installed with:

    sudo apt-get install libclucene-dev libclucene0ldbl

For Ubuntu version 13.10 the correct CLucene library version must be
installed manually.  The Perl CLucene modules is currently only compatible
with CLucene version 0.9.* but Ubuntu v13.10 ships with CLucene v2.3.3.4.

On Ubuntu v13.10 the old CLucene library can be installed with:

    wget http://www.mirrorservice.org/sites/archive.ubuntu.com/ubuntu//pool/main/c/clucene-core/libclucene0ldbl_0.9.21b-2build1_amd64.deb
    wget http://www.mirrorservice.org/sites/archive.ubuntu.com/ubuntu//pool/main/c/clucene-core/libclucene-dev_0.9.21b-2build1_amd64.deb
    sudo dpkg -i libclucene0ldbl_0.9.21b-2build1_amd64.deb libclucene-dev_0.9.21b-2build1_amd64.deb

## Installing prerequisites on Centos/Red Hat
If you have added
[RPMforge](http://wiki.centos.org/AdditionalResources/Repositories/RPMForge)
as an extra [Centos](http://www.centos.org/) package repository many of the
required Perl libraries can be installed with `yum`.

These are suggested packages to install:

    sudo yum groupinstall "Development Tools"
    sudo yum install perl cpan git perl-Module-Install

## Getting the Canto source code
Currently the easiest way to get the code is via GitHub.  Run this command
to get a copy:

    git clone https://github.com/pombase/canto.git

This creates a directory called "`canto`".  The directory can be updated
later with the command:

    git pull

## Downloading an archive file

Alternatively, GitHub provides archive files for the current version:

- https://github.com/pombase/canto/archive/master.zip
- https://github.com/pombase/canto/archive/master.tar.gz

Note after unpacking, you'll have a directory called `canto-master`.  The text
below assumes `canto` so:

    mv canto-master canto

## CPAN tips
It's best to configure the CPAN client before starting the Canto
installation.  Start it with:

    cpan

When started, cpan will attempt to configure itself.  Usually the default
answer at each prompt will work.

Use these commands at the `cpan` prompt avoid lots of questions while
installing modules later.

    o conf prerequisites_policy follow
    o conf build_requires_install_policy no
    o conf commit

Confirm that `Module::Install` and co are installed with (at the `cpan`
prompt):

    install Module::Install
    install Module::Install::Catalyst

Quit cpan and return to the shell prompt with:

    exit

## Install dependencies
In the `canto` directory:

    perl Makefile.PL
    make installdeps
    make

Answer "yes" to the "Auto-install the X mandatory module(s) from CPAN?"
prompt.

## Run the tests
To check that all prerequisites are installed and that the code Canto tests
pass:

    make test

# Quick start - making a test server
To try the Canto server:

## Initialise the data directory
Make a data directory somewhere:

    mkdir /tmp/canto-test

From the `canto` directory:

    ./script/canto_start --init /tmp/canto-test

This will initialise the `canto-test` directory and will create a
configuration file (`canto_deploy.yaml`) that can be customised.

## Run the server
Again, from the `canto` directory.

    ./script/canto_start

## Visit the application start page
The application should now be running at: http://localhost:5000

# Configuration
## canto.yaml
The default configuration is stored in `canto.yaml` in the top level
directory.  Any installation specific settings can be added to
`canto_deploy.yaml`, and will override the defaults.

The configuration files are [YAML format](http://en.wikipedia.org/wiki/YAML).

### name
A one word name for the site.  default: Canto
### long_name
A longer description of the site.  eg. The SlugBase community annotation tool
### database_name
Database name for prefixing identifiers when exporting.  eg. PomBase
### database_url
The URL of the database that this instance is installed for.  eg.
`http://curation.pombase.org/pombe/`
### header_image
A the path relative to `root/static` of the logo to put in the header.
### instance_organism
Canto has two modes: single or multi organism.  In multi organism mode, genes
from any number of organisms can be annotated in each session.  In this mode
after uploading a list of gene identifiers, the user will be shown the
organism name as well as the names, synonyms and products.  The organism is
shown so the user can confirm that the identifier they gave matched the gene
from the right organism.  In single organism mode the organism is not
displayed.

Example:

    instance_organism:
      taxonid: 4896

### canto_url
The link for the main Canto web site.
### app_version
The software version, automatically updated each release.
### schema_version
The version of the schema.  This is incremented when the schema changes in an
incompatible way.

### authentication
Configuration for the Catalyst authentication code.  This shouldn't need changing.
### view_options
Configuration for the admin view pages.
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
Used to look up gene identifier, name, synonyms and products.  The default
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
The path to the extra configuration file needed while testing.
### help_text
The keys under `help_text` identify a page in Canto and under the key is one
or both of `inline` or `url`.  The help text and link is rendered by the
`inline_help.mhtml` template.  If a `url` is given, the text under `inline`
will be `title` attribute of a link with that URL.  Without a `url` a help link
(a "?" icon) will be shown and the `inline` text will be displayed in a pop-up
DIV.
### contact_email
This email address is shown anytime a contact address is needed.  See the
`contact.mhtml` template.
### external_links
Each external link configuration has three possible parameters:

- `name` - The text to use as the title of the link.
- `icon` - An image from the `root/static/images/logos` to use as the `<img>`
  in the link.
- `url` - The URL to the appropriate page on an external site.  This string
  can contain text to substitute in the form `@@key@@`.  On the gene page, the
  key can be `primary_identifier` (the gene systematic ID) or `primary_name`
  (the gene name).  On the publication page the key should be `uniquename`
  which will substitute the PubMed ID into the URL.
- `sysid_link` - This external link will be used to hyperlink the primary
  identifier on the gene page as well as being shown in the external links
  section on the right of the page.

There are two possible types of external link on the gene pages:

- `generic` - These links will be shown on all gene pages.
- `organism` - These links are specific to the given organism.  The keys under
  the `organism` section will be the full organism name (ie "Genus species").

The external links are implemented in the `linkouts.html` template.

### webservices
### ontology_external_links
### chado

## Loading data
### Organisms

    ./script/canto_load.pl --organism "<genus> <species> <taxon_id>"

### Gene data

    ./script/canto_load.pl --genes genes_file.tsv --for-taxon 4896

#### gene data format
Four tab separated columns with no header line:

- systematic identifier
- gene primary name
- synonyms (comma separated)
- product

### Ontology terms

    ./script/canto_load.pl --ontology ontology_file.obo

The ontology must be configured in the [annotation_type_list](#annotation_type_list) section of the
`canto.yaml` file.

# Import and Export
## Exporting to JSON
The curation data can be exported in [JSON](http://en.wikipedia.org/wiki/JSON)
format with the `canto_export.pl` script from the `script` directory.  This
JSON file can then be loaded into a Chado database (see below).

To export the data from sessions that have been "approved" by the
administrators using the admin interface use:

    script/canto_export.pl canto-json --dump-approved > canto_approved.json

(From the canto top level directory).

If you use the flag `--export-approved` instead of `--dump-approved` then the
exported sessions with be marked as "EXPORTED" in the Canto database.  These
sessions won't be exported next time.  This option is provided so that
annotation will be exported only once from Canto.

To export the data from all the sessions, regardless of its state use:

    script/canto_export.pl canto-json --all  > canto_all.json

## Reading Canto data into Chado
The code for loading Canto JSON format files into a Chado database is
available from the [pombase-chado](https://github.com/pombase/pombase-chado)
code repository.  Follow the
[installation instructions](https://github.com/pombase/pombase-chado/blob/master/README.md)
then use this command:

   ./script/pombase-import.pl load-config-example.yaml canto --organism-taxonid=4896 --db-prefix=PomBase $HOST DB_NAME $USER $PASSWORD < canto_approved.json

where `HOST`, `DB_NAME`, `USER` and `PASSWORD` are the details of your local
Chado database.

The `pombase-import.pl` command will never delete or alter existing data it
only adds annotation.

# Canto implementation details
## Structure
There are two parts to the system.

"Track" run is the part that the administrator uses to add people,
publications and curation sessions to the database.  In the web interface this
is access using the Admin link in the top right of the page.

"Curs" handles the user curation sessions.

### Track - user, publication and session tracking
#### Database storage
##### SQLite for main database
### Curs - curation sessions
Each curation session has a corresponding SQLite database.

## Databases
## Database structure
## Code
Canto is written in Perl, implemented using the Catalyst framework and
running on a Plack server.
## Autocomplete searching
- implemented using CLucene
- short names are weighted more highly so they appear at the top of the search list
- the term names and synonyms are passed to CLucene for indexing
- all words appearing in the name or synonyms are joined into one string
  for separate indexing by CLucene

# Developing Canto
## Running tests
In general the tests can be run with: `make test` in the main canto
directory.  If the schema or test genes or ontologies are is changed the
test data will need to be re-initialised.

## Helper scripts
Scripts to help developers:

- `etc/db_initialise.pl` - create empty template database from the schemas
  and recreate the database classes in lib/Canto/TrackDB and
  lib/Canto/CursDB
- `etc/test_data_initialise.pl` - re-create test data files that don't change
  very often.  eg. the test PubMed XML file.  Currently this script only
  needs to be run if the list of publications for the test database
  changes
- `etc/test_initialise.pl` - initialise the test databases in t/data with
  a small number of genes and a mini version of the Gene Ontology
  database
- `etc/local_initialise.pl` - create a test instance of Canto in ./local

## Initialising test data
Run the following commands in the canto directory to create the test
database and to populate it with test data:

    ./etc/db_initialise.pl
    ./etc/test_initialise.pl

That will need to be done each time the schemas or test data change.

To create a local test instance of Canto, run `local_initialise.pl`

## Running the test instance
The server can be run from the top level directory with this command:

    CANTO_CONFIG_LOCAL_SUFFIX=local PERL5LIB=lib ./script/canto_server.pl -p 5000 -r -d

"5000" is the local port to connect on.  The server should then be
available at http://localhost:5000/

# Contact
For questions or help please contact helpdesk@pombase.org or kim@pombase.org.

Requests of new features can be made by email or by adding an issue on the
[GitHub Canto issue tracker](https://github.com/pombase/canto/issues)
