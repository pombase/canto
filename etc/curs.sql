PRAGMA foreign_keys=ON;

CREATE TABLE organism (
       organism_id integer PRIMARY KEY,
       full_name TEXT NOT NULL UNIQUE
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
       type text NOT NULL, -- "go function", "ortholog", "phenotype"
       data text NOT NULL,
       -- include type as the there may be a go term and ortholog with the same
       -- chado id
       UNIQUE (annotation_id, status, type)
);

CREATE TABLE pub (
       pub_id integer primary key,
       data text NOT NULL
);

CREATE TABLE metadata (
       metadata_id integer PRIMARY KEY,
       key text NOT NULL UNIQUE,
       value text
);


