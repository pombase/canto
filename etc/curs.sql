PRAGMA foreign_keys=ON;

CREATE TABLE organism (
       organism_id integer PRIMARY KEY,
       full_name TEXT NOT NULL UNIQUE,
       taxonid integer NOT NULL
);

CREATE TABLE gene (
       gene_id integer PRIMARY KEY,
       primary_identifier text NOT NULL UNIQUE,
       primary_name TEXT,
       product TEXT,
       organism integer NOT NULL REFERENCES organism(organism_id)
);

CREATE TABLE annotation (
       annotation_id integer PRIMARY KEY,
       status text NOT NULL,  -- "new", "deleted", "unchanged"
       pub integer REFERENCES pub(pub_id),
       type text NOT NULL, -- "go_function", "ortholog", "phenotype"
       creation_date text NOT NULL,
       data text NOT NULL,
       -- include type as the there may be a go term and ortholog with the same
       -- chado id
       UNIQUE (annotation_id, status, type)
);

CREATE TABLE gene_annotation (
       gene_annotation_id integer PRIMARY KEY,
       gene integer REFERENCES gene(gene_id),
       annotation integer REFERENCES annotation(annotation_id)
);

CREATE TABLE pub (
       pub_id integer primary key,
       uniquename integer NOT NULL UNIQUE,
       title text NOT NULL,
       abstract text
);

CREATE TABLE metadata (
       metadata_id integer PRIMARY KEY,
       key text NOT NULL UNIQUE,
       value text
);
