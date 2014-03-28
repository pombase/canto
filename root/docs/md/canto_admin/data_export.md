# Exporting data from Canto
## Exporting to JSON
The curation data can be exported in [JSON](http://en.wikipedia.org/wiki/JSON)
format with the `canto_export.pl` script from the `script` directory. This
JSON file can then be loaded into a Chado database (see below).

To export the data from sessions that have been "approved" by the
administrators using the admin interface use:

    script/canto_export.pl canto-json --dump-approved > canto_approved.json

(From the canto top level directory).

If you use the flag `--export-approved` instead of `--dump-approved`, the
exported sessions with be marked as "EXPORTED" in the Canto database. These
sessions won't be exported next time. This option is provided so that
annotation will be exported only once from Canto.

To export the data from all the sessions, regardless of its state use:

    script/canto_export.pl canto-json --all  > canto_all.json

## Reading Canto data into Chado
The code for loading Canto JSON format files into a Chado database is
available from the [pombase-chado](https://github.com/pombase/pombase-chado)
code repository. Follow the
[installation instructions](https://github.com/pombase/pombase-chado/blob/master/README.md)
then use this command:

    ./script/pombase-import.pl load-config-example.yaml canto --organism-taxonid=4896 \
       --db-prefix=PomBase $HOST DB_NAME $USER $PASSWORD < canto_approved.json

where `HOST`, `DB_NAME`, `USER` and `PASSWORD` are the details of your local
Chado database.

The `pombase-import.pl` command will never delete or alter existing data it
only adds annotation.

To test loading without modifying the Chado database, add the `-d` or
`--dry-run` option to the command line.

