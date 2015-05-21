PRAGMA foreign_keys=ON;

CREATE TABLE organism (
       organism_id integer PRIMARY KEY,
       full_name TEXT NOT NULL UNIQUE,
       taxonid integer NOT NULL
);

CREATE TABLE gene (
       gene_id integer PRIMARY KEY,
       primary_identifier text NOT NULL UNIQUE,
       organism integer NOT NULL REFERENCES organism(organism_id)
);

CREATE TABLE allele (
       allele_id integer PRIMARY KEY,
       primary_identifier text NOT NULL UNIQUE,
       type text NOT NULL,  -- 'deletion', 'partial deletion, nucleotide' etc.
       description text,
       expression text,
       name text,
       gene integer NOT NULL REFERENCES gene(gene_id)
);

CREATE TABLE annotation (
       annotation_id integer PRIMARY KEY,
       status text NOT NULL,  -- "new", "deleted"
       pub integer REFERENCES pub(pub_id),
       type text NOT NULL, -- "biological_process", "phenotype"
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

CREATE TABLE genotype_annotation (
       genotype_annotation_id integer PRIMARY KEY,
       genotype integer REFERENCES genotype(genotype_id),
       annotation integer REFERENCES annotation(annotation_id)
);

CREATE TABLE genotype (
       genotype_id integer PRIMARY KEY AUTOINCREMENT,
       identifier text UNIQUE NOT NULL,
       background text,
       name text UNIQUE
);

CREATE TABLE allele_genotype (
       allele_genotype_id integer PRIMARY KEY,
       allele integer REFERENCES allele(allele_id),
       genotype integer REFERENCES genotype(genotype_id)
);

CREATE TABLE pub (
       pub_id integer primary key,
       uniquename text NOT NULL UNIQUE,
       title text NOT NULL,
       authors text NOT NULL,
       abstract text NOT NULL
);

CREATE TABLE metadata (
       metadata_id integer PRIMARY KEY,
       key text NOT NULL UNIQUE,
       value text
);
