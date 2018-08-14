# Canto implementation details
## Structure
There are two parts to the system.

"Track" run is the part that the administrator uses to add people,
publications and curation sessions to the database. In the web interface this
is access using the Admin link in the top right of the page.

"Curs" handles the user curation sessions.

### Track - user, publication and session tracking
#### Database storage
#### SQLite for main database
### Curs - curation sessions
Each curation session has a corresponding SQLite database.

## Code
Canto is written in Perl, implemented using the Catalyst framework and
running on a Plack server.
## Autocomplete searching
- implemented using CLucene
- short names are weighted more highly so they appear at the top of the search list
- the term names and synonyms are passed to CLucene for indexing
- all words appearing in the name or synonyms are joined into one string
  for separate indexing by CLucene

## Developing Canto
### Running tests
The environment needs to be initialised with `perl Makefile.PL`.  This
command creates the Makefile and only needs to be run once.

In general the tests can be run with: `make test` in the main canto
directory. If the schema or test genes or ontologies are is changed the
test data will need to be re-initialised.

### Helper scripts
Scripts to help developers:

- `etc/db_initialise.pl` - create empty template database from the schemas
  and recreate the database classes in lib/Canto/TrackDB and
  lib/Canto/CursDB
- `etc/test_data_initialise.pl` - re-create test data files that don't change
  very often. e.g. the test PubMed XML file. Currently this script only
  needs to be run if the list of publications for the test database
  changes
- `etc/test_initialise.pl` - initialise the test databases in t/data with
  a small number of genes and a mini version of the Gene Ontology
  database
- `etc/local_initialise.pl` - create a test instance of Canto in ./local

### Initialising test data
Run the following commands in the canto directory to create the test
database and to populate it with test data:

    ./etc/db_initialise.pl
    ./etc/test_initialise.pl

That will need to be done each time the schemas or test data change.

To create a local test instance of Canto, run `local_initialise.pl`

### Running the test instance
The server can be run from the top level directory with this command:

    CANTO_CONFIG_LOCAL_SUFFIX=local PERL5LIB=lib ./script/canto_server.pl -p 5000 -r -d
