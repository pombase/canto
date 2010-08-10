PRAGMA foreign_keys=ON;

CREATE TABLE organism (
       organism_id integer PRIMARY KEY,
       name TEXT NOT NULL UNIQUE,
       ncbi_taxonomy_identifier integer NOT NULL
);

CREATE TABLE gene (
       primary_id text PRIMARY KEY,
       systematic_identifier test NOT NULL UNIQUE,
       primary_name TEXT,
       gene_product TEXT,
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
       key text NOT NULL,
       value text
);


