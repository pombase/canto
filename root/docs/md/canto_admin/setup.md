# Configuring Canto and loading data

After the software is [installed](installation) some configuration is needed.

If you chose the recommended Docker installation precedure then the
commands below will need to be run inside the Canto container.  The
suggested way to do that to use the `canto_docker` script as a prefix
to the commands below.

So for example to load a genes file when Canto is running via a Docker
container, instead of:

    ./script/canto_load.pl --genes genes_file.tsv --for-taxon 4896

from instead your `canto` git check out, add your `genes_file.tsv` to
the `import_export` directory and the run this command in the
`canto-space` directory created in the [installed](installation)
section:

    ./canto/script/canto_docker ./script/canto_load.pl --genes \
        /import_export/genes_file.tsv --for-taxon 4896

Only four host directories (`canto`, `data`, `logs` and `import_export`) are
visible inside the container so reading and writing of files should be
via those directories.  In particular, as in the example above,
datasets for loading should be added to your `import_export` directory
as created in the [installation](installation) step.

## Creating users

To manage sessions and users from the web interface there needs to be at least
one "admin" user.  Users can be added with the `canto_add.pl` script.  For
example:

    ./script/canto_add.pl --person "Kim Rutherford" kim@pombase.org admin

## Configuring ORCID for logins

Canto uses ORCID for authentication.

Follow the steps in the
[ORCID documentation](http://members.orcid.org/api/accessing-public-api) to
get a client ID and secret for your installation of Canto.

Add these lines to your `canto_deploy.yaml` and add your client ID and client
secret:

    authentication:
      orcid:
        client_id: ...
        client_secret: ...

## Loading data

Canto can operate in two modes: "single organism" and "multi organism".
Single organism mode is activated by setting the `instance_organism`
configuration option.  Multi-organism mode is assumed otherwise.  See the
[`instance_organism`](configuration_file#instance_organism) section in the
[configuration file documentation](configuration_file) for a full description
of the two modes.

The default implementation stores the details of the organism and genes for
annotation in Canto's own database.  The `canto_load.pl` in the sections below
loads data from flat files into Canto's database.

But it's also possible to configure
["adaptors"](configuration_file#implementation_classes) to retreive these
details as needed from an external database or webserver.  At PomBase for
example, gene information is read from the Chado curation database.  See the
[configuration_file documentation](configuration_file#implementation_classes)
for details of how to configure the adaptors.

In the following sections "single organism" mode is assumed.  To run Canto in
that mode you will need to load at least one organism, a list of genes and one
or more ontologies before using Canto.

### Organisms

Add an organism using this command in the `canto` directory:

    ./script/canto_add.pl --organism "<genus> <species>" <taxon_id>

At least one organism is needed in the Canto database before genes can be
loaded.

### Gene data

Load genes with:

    ./script/canto_load.pl --genes genes_file.tsv --for-taxon 4896

All genes in an input file must be from one organism.  Use the `--for-taxon`
argument with an NCBI taxon ID to specify the organism, which needs to have
been loaded with the --organism option (see above).

#### gene data format

A gene data file consists of four tab separated columns with no header line.
The columns are:

- systematic identifier
- gene primary name
- synonyms (comma separated)
- gene product or description

There is a small example file in the [test directory](https://raw.githubusercontent.com/pombase/canto/master/t/data/pombe_genes.txt).

### Ontology terms

OBO format ontology data can be imported or updated with:

    ./script/canto_load.pl --ontology file_1.obo [--ontology file_2.obo ...]

Or if you have a dockerised Canto:

    ./canto/script/canto_docker ./script/canto_load.pl \
       --ontology file_1.obo [--ontology file_2.obo ...]

If you need to import multiple ontology files, they all must be included in
the same command line:

    ./script/canto_load.pl --ontology ontology_file.obo \
       --ontology another_ontology_file.obo

When updating existing ontologies in Canto, all ontologies must be updated
with the same `canto_load.pl` command.

The OBO file can also be given by URL.  eg.

    ./script/canto_load.pl --ontology \
       http://purl.obolibrary.org/obo/go/go-basic.obo

Each ontology must be configured in the
[available_annotation_type_list](configuration_file#available_annotation_type_list)
section of the `canto.yaml` file before it can be used in the interface.
